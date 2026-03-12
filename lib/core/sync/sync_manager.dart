// lib/core/sync/sync_manager.dart
//
// Two categories of queued items are processed on reconnect:
//
//   Firestore  (patient, encounter, referral, programEnrollment)
//     → written to FirebaseConfig.facilityDb
//
//   HIE Gateway  (hiePatient, hieEncounter, hieReferral)
//     → POSTed to the Node.js backend via HieApiService
//       so AfyaChain blocks are minted even if the device was
//       offline at the time of creation.
//
// A patient created offline therefore gets:
//   1. SQLite record — immediately, always
//   2. Firestore sync — on reconnect  (SyncEntityType.patient)
//   3. NUPI minted on AfyaChain       (SyncEntityType.hiePatient)

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import '../services/hie_api_service.dart';
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

    // Replace any existing item for the same entity so Firestore
    // writes are never doubled. HIE items use a unique entityId
    // (hie_<uuid>) and never collide with Firestore items.
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
    _emitStatus(isSyncing: true);

    final db = await _db.database;

    try {
      final rows = await db.query('sync_queue',
          orderBy: 'created_at ASC', where: 'attempts < 3');

      if (rows.isEmpty) {
        _isSyncing = false;
        _emitStatus(isSyncing: false);
        return;
      }

      int failCount = 0;

      for (final row in rows) {
        final item    = SyncQueueItem.fromMap(row);
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
      }

      _emitStatus(
        isSyncing:  false,
        lastSyncAt: DateTime.now(),
        lastError:  failCount > 0 ? '$failCount item(s) failed to sync' : null,
      );
    } catch (e) {
      _emitStatus(isSyncing: false, lastError: 'Sync error: $e');
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
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
      final fs  = FirebaseConfig.facilityDb;
      final col = _firestoreCollection(item.entityType);

      switch (item.operation) {
        case SyncOperation.create:
        case SyncOperation.update:
          await fs.collection(col).doc(item.entityId)
              .set(_toFirestorePayload(item.payload), SetOptions(merge: true));
          break;
        case SyncOperation.delete:
          await fs.collection(col).doc(item.entityId).delete();
          break;
      }
      return true;
    } catch (e) {
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

  /// Registers the patient on AfyaChain and gets the real NUPI back.
  /// If the offline-generated local NUPI differs from the real one,
  /// all matching rows in SQLite are updated.
  Future<bool> _syncHiePatient(SyncQueueItem item) async {
    try {
      final p = item.payload;
      final result = await HieApiService.instance.registerPatient(
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

      if (result.success || result.data?['alreadyExists'] == true) {
        final realNupi  = result.nupi ?? '';
        final localNupi = p['localNupi'] as String? ?? '';
        if (realNupi.isNotEmpty && localNupi != realNupi) {
          await _replaceLocalNupi(localNupi, realNupi);
        }
        debugPrint('[Sync] ⛓ HIE patient synced — NUPI: $realNupi');
        return true;
      }

      debugPrint('[Sync] ⚠ HIE patient failed: ${result.error}');
      return false;
    } catch (e) {
      await _recordError(item, e);
      return false;
    }
  }

  Future<bool> _syncHieEncounter(SyncQueueItem item) async {
    try {
      final p      = item.payload;
      final result = await HieApiService.instance.recordEncounter(
        nupi:             p['nupi']             as String,
        accessToken:      p['accessToken']      as String? ?? '',
        encounterType:    p['encounterType']    as String,
        chiefComplaint:   p['chiefComplaint']   as String? ?? '',
        practitionerName: p['practitionerName'] as String,
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
        debugPrint('[Sync] ⛓ HIE encounter block #${result.blockIndex} minted');
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
      final p      = item.payload;
      final result = await HieApiService.instance.createReferral(
        referralId:       p['referralId']       as String,
        patientNupi:      p['patientNupi']      as String,
        patientName:      p['patientName']      as String,
        fromFacilityId:   p['fromFacilityId']   as String,
        fromFacilityName: p['fromFacilityName'] as String,
        toFacilityId:     p['toFacilityId']     as String,
        toFacilityName:   p['toFacilityName']   as String,
        reason:           p['reason']           as String,
        priority:         p['priority']         as String,
        clinicalNotes:    p['clinicalNotes']    as String?,
        createdBy:        p['createdBy']        as String,
        createdByName:    p['createdByName']    as String,
        accessToken:      p['accessToken']      as String? ?? '',
      );

      if (result.success) {
        debugPrint('[Sync] ⛓ HIE referral block #${result.blockIndex} minted');
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

  /// Replaces an offline-generated NUPI with the real one from the gateway
  /// across all local tables that reference it.
  Future<void> _replaceLocalNupi(String localNupi, String realNupi) async {
    try {
      final db = await _db.database;
      await db.update('patients',  {'nupi': realNupi},
          where: 'nupi = ?',         whereArgs: [localNupi]);
      await db.update('encounters', {'patient_nupi': realNupi},
          where: 'patient_nupi = ?', whereArgs: [localNupi]);
      await db.update('referrals',  {'patient_nupi': realNupi},
          where: 'patient_nupi = ?', whereArgs: [localNupi]);
      debugPrint('[Sync] ✔ NUPI updated $localNupi → $realNupi');
    } catch (e) {
      debugPrint('[Sync] ⚠ NUPI replace error: $e');
    }
  }

  /// Only Firestore entities have a SQLite row whose sync_status
  /// should be stamped 'synced'. HIE entities have no such row.
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

  Future<void> _updatePendingCount() async {
    try {
      final db     = await _db.database;
      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM sync_queue WHERE attempts < 3');
      _emitStatus(pendingCount: result.first['count'] as int);
    } catch (_) {}
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
    _syncStatusController.add(_currentStatus);
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