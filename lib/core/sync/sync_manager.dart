// lib/core/sync/sync_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import '../services/backend_api_service.dart';
import 'connectivity_manager.dart';
import 'sync_queue_item.dart';
import '../database/database_helper.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final _db           = DatabaseHelper();
  final _connectivity = ConnectivityManager();

  StreamSubscription? _connectivitySub;
  bool _isSyncing   = false;
  bool _initialized = false;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  SyncStatus _currentStatus = const SyncStatus(
    pendingCount: 0,
    isSyncing:    false,
    lastSyncAt:   null,
    lastError:    null,
  );
  SyncStatus get currentStatus => _currentStatus;

  // ── Init ───────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _connectivity.init();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) _triggerSync();
    });

    await _updatePendingCount();
    if (_connectivity.isOnline) _triggerSync();
  }

  // ── Enqueue ────────────────────────────────────────────────────

  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db.database;

    await db.delete('sync_queue',
        where: 'entity_id = ? AND entity_type = ?',
        whereArgs: [entityId, entityType.name]);

    await db.insert('sync_queue', SyncQueueItem(
      entityType: entityType,
      entityId:   entityId,
      operation:  operation,
      payload:    payload,
      createdAt:  DateTime.now(),
    ).toMap());

    await _updatePendingCount();
    if (_connectivity.isOnline) _triggerSync();
  }

  // ── Trigger (debounced, max once per 30 s) ─────────────────────

  Timer?    _syncDebounceTimer;
  DateTime? _lastSyncTime;

  void _triggerSync() {
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!).inSeconds < 30) return;

    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _lastSyncTime = DateTime.now();
      _processQueue();
    });
  }

  // ── Process queue ──────────────────────────────────────────────

  Future<void> _processQueue() async {
    if (_isSyncing) return;
    if (!await _connectivity.checkConnectivity()) return;

    _isSyncing = true;
    final freshCountAtStart = await _pendingCountFromDb();
    _emitStatus(isSyncing: true, pendingCount: freshCountAtStart);

    final db = await _db.database;

    try {
      final rows = await db.query('sync_queue',
          orderBy: 'created_at ASC', where: 'attempts < 3');

      if (rows.isEmpty) {
        _isSyncing = false;
        final count = await _pendingCountFromDb();
        _emitStatus(isSyncing: false, pendingCount: count);
        return;
      }

      // Phase 1: HIE items first — patient gets real NUPI before
      // Firestore sync writes the patient document.
      final hieItems = rows
          .map(SyncQueueItem.fromMap)
          .where((i) =>
              i.entityType == SyncEntityType.hiePatient ||
              i.entityType == SyncEntityType.hieEncounter ||
              i.entityType == SyncEntityType.hieReferral)
          .toList();

      // Phase 2: Firestore items
      final firestoreItems = rows
          .map(SyncQueueItem.fromMap)
          .where((i) =>
              i.entityType != SyncEntityType.hiePatient &&
              i.entityType != SyncEntityType.hieEncounter &&
              i.entityType != SyncEntityType.hieReferral)
          .toList();

      int failCount = 0;

      for (final item in [...hieItems, ...firestoreItems]) {
        final success = await _syncItem(item);

        if (success) {
          await db.delete('sync_queue',
              where: 'id = ?', whereArgs: [item.id]);
          await _markSynced(item);
        } else {
          await db.update('sync_queue', {'attempts': item.attempts + 1},
              where: 'id = ?', whereArgs: [item.id]);
          failCount++;
        }

        // Live count update after every item
        final liveCount = await _pendingCountFromDb();
        _emitStatus(pendingCount: liveCount, isSyncing: true);
      }

      final finalCount = await _pendingCountFromDb();
      _emitStatus(
        isSyncing:    false,
        pendingCount: finalCount,
        lastSyncAt:   DateTime.now(),
        lastError:    failCount > 0
            ? '$failCount item(s) failed to sync'
            : null,
      );
    } catch (e) {
      final countOnError = await _pendingCountFromDb();
      _emitStatus(
        isSyncing:    false,
        pendingCount: countOnError,
        lastError:    'Sync error: $e',
      );
    } finally {
      _isSyncing = false;
    }
  }

  // ── Route a single item ────────────────────────────────────────

  Future<bool> _syncItem(SyncQueueItem item) {
    switch (item.entityType) {
      case SyncEntityType.hiePatient:
        return _syncHiePatient(item);
      case SyncEntityType.hieEncounter:
        return _syncHieEncounter(item);
      case SyncEntityType.hieReferral:
        return _syncHieReferral(item);
      default:
        return _syncFirestore(item);
    }
  }

  // ── Firestore path ─────────────────────────────────────────────

  Future<bool> _syncFirestore(SyncQueueItem item) async {
    try {
      // KEY FIX: ensure anonymous auth is active before every Firestore write.
      // On cold start, signInAnonymously() may have failed because the device
      // hadn't established network yet. This call retries it so by the time
      // the sync queue processes Firestore items, auth.currentUser != null
      // and Firestore rules pass.
      await FirebaseConfig.ensureAnonymousAuth();

      final fs  = FirebaseConfig.facilityDb;
      final col = _firestoreCollection(item.entityType);

      switch (item.operation) {
        case SyncOperation.create:
        case SyncOperation.update:
          await fs.collection(col).doc(item.entityId)
              .set(_toFirestorePayload(item.payload), SetOptions(merge: true));
          debugPrint('[Sync] ✔ Firestore write: $col/${item.entityId}');
          break;
        case SyncOperation.delete:
          await fs.collection(col).doc(item.entityId).delete();
          debugPrint('[Sync] ✔ Firestore delete: $col/${item.entityId}');
          break;
      }
      return true;
    } catch (e) {
      debugPrint('[Sync] ✘ Firestore failed (${item.entityType.name}): $e');
      await _recordError(item, e);
      return false;
    }
  }

  String _firestoreCollection(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.patient:           return 'patients';
      case SyncEntityType.encounter:         return 'encounters';
      case SyncEntityType.referral:          return 'referrals';
      case SyncEntityType.programEnrollment: return 'program_enrollments';
      default: return 'patients';
    }
  }

  // ── HIE Gateway paths ──────────────────────────────────────────

  Future<bool> _syncHiePatient(SyncQueueItem item) async {
    try {
      final p       = item.payload;
      final backend = await BackendApiService.instanceAsync;
      final result  = await backend.registerPatient(
        nationalId:       p['nationalId']       as String,
        firstName:        p['firstName']        as String,
        lastName:         p['lastName']         as String,
        middleName:       p['middleName']       as String?,
        dateOfBirth:      p['dateOfBirth']      as String,
        gender:           p['gender']           as String,
        phoneNumber:      p['phoneNumber']      as String?,
        email:            p['email']            as String?,
        address:          p['address'] != null
            ? Map<String, String?>.from(p['address'] as Map)
            : null,
        securityQuestion: p['securityQuestion'] as String,
        securityAnswer:   p['securityAnswer']   as String,
        pin:              p['pin']              as String,
      );

      final alreadyExists = result.data?['alreadyExists'] == true;

      if (result.success || alreadyExists) {
        final realNupi  = result.nupi ?? result.data?['nupi'] as String? ?? '';
        final localNupi = p['localNupi'] as String? ?? '';

        if (realNupi.isNotEmpty && localNupi != realNupi) {
          await _replaceLocalNupi(localNupi, realNupi);
          await _fixNupiInSyncQueue(localNupi, realNupi);
          await _fixNupiInFirestore(localNupi, realNupi);
        }

        debugPrint('[Sync] ✔ HIE patient synced — NUPI: $realNupi');
        return true;
      }

      debugPrint('[Sync] HIE patient failed: ${result.error}');
      return false;
    } catch (e) {
      await _recordError(item, e);
      return false;
    }
  }

  Future<void> _fixNupiInSyncQueue(
      String localNupi, String realNupi) async {
    try {
      final db   = await _db.database;
      final rows = await db.query('sync_queue', where: 'attempts < 3');

      for (final row in rows) {
        final payloadStr = row['payload'] as String? ?? '';
        if (!payloadStr.contains(localNupi)) continue;

        final updated = payloadStr.replaceAll(localNupi, realNupi);
        await db.update(
          'sync_queue',
          {'payload': updated},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        debugPrint('[Sync] ✔ Sync queue payload updated '
            '$localNupi → $realNupi (id=${row['id']})');
      }
    } catch (e) {
      debugPrint('[Sync] ⚠ Failed to update sync queue NUPIs: $e');
    }
  }

  Future<void> _fixNupiInFirestore(
      String localNupi, String realNupi) async {
    try {
      await FirebaseConfig.ensureAnonymousAuth();
      final fs = FirebaseConfig.facilityDb;

      final snap = await fs
          .collection('patients')
          .where('nupi', isEqualTo: localNupi)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      await snap.docs.first.reference.update({'nupi': realNupi});
      debugPrint('[Sync] ✔ Firestore patient NUPI patched '
          '$localNupi → $realNupi');
    } catch (e) {
      debugPrint('[Sync] ⚠ Firestore NUPI patch failed (non-critical): $e');
    }
  }

  Future<bool> _syncHieEncounter(SyncQueueItem item) async {
    try {
      final p       = item.payload;
      final backend = await BackendApiService.instanceAsync;
      final result  = await backend.recordEncounter(
        nupi:             p['nupi']             as String,
        encounterType:    p['encounterType']    as String,
        chiefComplaint:   p['chiefComplaint']   as String? ?? '',
        practitionerName: p['practitionerName'] as String?,
        vitalSigns:       p['vitalSigns'] != null
            ? Map<String, dynamic>.from(p['vitalSigns'] as Map)
            : null,
        diagnoses:        p['diagnoses'] != null
            ? List<Map<String, dynamic>>.from(
                (p['diagnoses'] as List)
                    .map((d) => Map<String, dynamic>.from(d as Map)))
            : null,
        notes:            p['notes']         as String?,
        encounterDate:    p['encounterDate'] as String,
      );

      if (result.success) {
        debugPrint('[Sync] ⛓ HIE encounter block #${result.data?['blockIndex']} minted');
        return true;
      }
      debugPrint('[Sync] ⚠ HIE encounter failed: ${result.error}');
      return false;
    } catch (e) {
      await _recordError(item, e);
      return false;
    }
  }

  Future<bool> _syncHieReferral(SyncQueueItem item) async {
    try {
      final p       = item.payload;
      final backend = await BackendApiService.instanceAsync;
      final result  = await backend.createReferral(
        patientNupi:      p['patientNupi']      as String,
        toFacilityId:     p['toFacilityId']     as String,
        reason:           p['reason']           as String,
        priority:         p['priority']         as String,
        issuedBy:         p['createdByName']    as String?,
        patientName:      p['patientName']      as String?,
        fromFacilityName: p['fromFacilityName'] as String?,
        toFacilityName:   p['toFacilityName']   as String?,
        clinicalNotes:    p['clinicalNotes']    as String?,
      );

      if (result.success) {
        debugPrint('[Sync] ⛓ HIE referral block #${result.data?['blockIndex']} minted');
        return true;
      }
      debugPrint('[Sync] ⚠ HIE referral failed: ${result.error}');
      return false;
    } catch (e) {
      await _recordError(item, e);
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  Future<void> _replaceLocalNupi(String localNupi, String realNupi) async {
    try {
      final db = await _db.database;
      await db.update('patients',   {'nupi': realNupi},
          where: 'nupi = ?',          whereArgs: [localNupi]);
      await db.update('encounters', {'patient_nupi': realNupi},
          where: 'patient_nupi = ?',  whereArgs: [localNupi]);
      await db.update('referrals',  {'patient_nupi': realNupi},
          where: 'patient_nupi = ?',  whereArgs: [localNupi]);
      debugPrint('[Sync] ✔ NUPI updated $localNupi → $realNupi');
    } catch (e) {
      debugPrint('[Sync] ⚠ NUPI replace error: $e');
    }
  }

  Future<void> _markSynced(SyncQueueItem item) async {
    const firestoreTypes = {
      SyncEntityType.patient,
      SyncEntityType.encounter,
      SyncEntityType.referral,
      SyncEntityType.programEnrollment,
    };
    if (!firestoreTypes.contains(item.entityType)) return;

    final db    = await _db.database;
    final table = _firestoreCollection(item.entityType);
    await db.update(table, {'sync_status': 'synced'},
        where: 'id = ?', whereArgs: [item.entityId]);
  }

  Future<void> _recordError(SyncQueueItem item, Object e) async {
    try {
      final db = await _db.database;
      await db.update('sync_queue', {'last_error': e.toString()},
          where: 'id = ?', whereArgs: [item.id]);
    } catch (_) {}
  }

  Map<String, dynamic> _toFirestorePayload(Map<String, dynamic> payload) {
    final out = Map<String, dynamic>.from(payload);
    for (final f in const [
      'created_at', 'updated_at', 'encounter_date',
      'date_of_birth', 'accepted_at', 'completed_at',
    ]) {
      if (out[f] is String) {
        try { out[f] = Timestamp.fromDate(DateTime.parse(out[f] as String)); }
        catch (_) {}
      }
    }
    for (final f in const [
      'allergies', 'chronic_conditions', 'diagnoses', 'vitals',
    ]) {
      if (out[f] is String) {
        try { out[f] = jsonDecode(out[f] as String); } catch (_) {}
      }
    }
    out.remove('sync_status');
    return out;
  }

  Future<int> _pendingCountFromDb() async {
    try {
      final db     = await _db.database;
      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM sync_queue WHERE attempts < 3');
      return result.first['count'] as int;
    } catch (_) {
      return _currentStatus.pendingCount;
    }
  }

  Future<void> _updatePendingCount() async {
    final count = await _pendingCountFromDb();
    _emitStatus(pendingCount: count);
  }

  void _emitStatus({
    bool?     isSyncing,
    int?      pendingCount,
    DateTime? lastSyncAt,
    String?   lastError,
  }) {
    _currentStatus = SyncStatus(
      isSyncing:    isSyncing    ?? _currentStatus.isSyncing,
      pendingCount: pendingCount ?? _currentStatus.pendingCount,
      lastSyncAt:   lastSyncAt   ?? _currentStatus.lastSyncAt,
      lastError:    lastError,
    );
    if (!_syncStatusController.isClosed) {
      _syncStatusController.add(_currentStatus);
    }
  }

  Future<void> syncNow() => _processQueue();

  void dispose() {
    _connectivitySub?.cancel();
    _syncDebounceTimer?.cancel();
    _syncStatusController.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class SyncStatus {
  final bool      isSyncing;
  final int       pendingCount;
  final DateTime? lastSyncAt;
  final String?   lastError;

  const SyncStatus({
    required this.isSyncing,
    required this.pendingCount,
    this.lastSyncAt,
    this.lastError,
  });
}