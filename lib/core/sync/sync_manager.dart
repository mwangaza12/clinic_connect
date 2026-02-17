import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/firebase_config.dart';
import 'connectivity_manager.dart';
import 'sync_queue_item.dart';
import '../database/database_helper.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final _db = DatabaseHelper();
  final _connectivity = ConnectivityManager();

  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;
  bool _initialized = false; 

  // Stream to broadcast sync status to UI
  final _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  SyncStatus _currentStatus = const SyncStatus(
    pendingCount: 0,
    isSyncing: false,
    lastSyncAt: null,
    lastError: null,
  );

  SyncStatus get currentStatus => _currentStatus;

  Future<void> init() async {
    if (_initialized) return; // ✅ prevent double init
    _initialized = true;

    await _connectivity.init();

    // Listen for connectivity changes
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        _triggerSync();
      }
    });

    // Check pending items on startup
    await _updatePendingCount();

    // Try sync if online
    if (_connectivity.isOnline) {
      _triggerSync();
    }
  }

  // ─────────────────────────────────────────
  // Enqueue an item for sync
  // ─────────────────────────────────────────
  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db.database;

    // Remove any existing queue item for this entity
    await db.delete(
      'sync_queue',
      where: 'entity_id = ? AND entity_type = ?',
      whereArgs: [entityId, entityType.name],
    );

    final item = SyncQueueItem(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: DateTime.now(),
    );

    await db.insert('sync_queue', item.toMap());
    await _updatePendingCount();

    // If online, sync immediately
    if (_connectivity.isOnline) {
      _triggerSync();
    }
  }

  // ─────────────────────────────────────────
  // Trigger sync (debounced)
  // ─────────────────────────────────────────
  Timer? _syncDebounceTimer;
  DateTime? _lastSyncTime; // ✅ ADD

  void _triggerSync() {
    // ✅ Don't sync more than once every 30 seconds
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!).inSeconds < 30) {
      return;
    }

    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        _lastSyncTime = DateTime.now(); // ✅ record time
        _processQueue();
      },
    );
  }

  // ─────────────────────────────────────────
  // Process the sync queue
  // ─────────────────────────────────────────
  Future<void> _processQueue() async {
    if (_isSyncing) return;
    if (!await _connectivity.checkConnectivity()) return;

    _isSyncing = true;
    _emitStatus(isSyncing: true);

    final db = await _db.database;

    try {
      // Get all pending items ordered by creation time
      final rows = await db.query(
        'sync_queue',
        orderBy: 'created_at ASC',
        where: 'attempts < 3', // max 3 retry attempts
      );

      if (rows.isEmpty) {
        _isSyncing = false;
        _emitStatus(isSyncing: false);
        return;
      }

      // ignore: unused_local_variable
      int successCount = 0;
      int failCount = 0;

      for (final row in rows) {
        final item = SyncQueueItem.fromMap(row);
        final success = await _syncItem(item);

        if (success) {
          // Remove from queue
          await db.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [item.id],
          );

          // Mark entity as synced
          await _markSynced(item);
          successCount++;
        } else {
          // Increment attempt count
          await db.update(
            'sync_queue',
            {'attempts': item.attempts + 1},
            where: 'id = ?',
            whereArgs: [item.id],
          );
          failCount++;
        }
      }

      _emitStatus(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        lastError: failCount > 0
            ? '$failCount item(s) failed to sync'
            : null,
      );
    } catch (e) {
      _emitStatus(
        isSyncing: false,
        lastError: 'Sync error: $e',
      );
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
    }
  }

  // ─────────────────────────────────────────
  // Sync a single item to Firestore
  // ─────────────────────────────────────────
  Future<bool> _syncItem(SyncQueueItem item) async {
    try {
      final firestore = FirebaseConfig.facilityDb;
      final collection = _getCollection(item.entityType);

      switch (item.operation) {
        case SyncOperation.create:
        case SyncOperation.update:
          // Convert ISO strings back to Timestamps for Firestore
          final payload =
              _convertToFirestorePayload(item.payload);
          await firestore
              .collection(collection)
              .doc(item.entityId)
              .set(payload, SetOptions(merge: true));
          break;

        case SyncOperation.delete:
          await firestore
              .collection(collection)
              .doc(item.entityId)
              .delete();
          break;
      }

      return true;
    } catch (e) {
      // Update last_error in queue
      final db = await _db.database;
      await db.update(
        'sync_queue',
        {'last_error': e.toString()},
        where: 'id = ?',
        whereArgs: [item.id],
      );
      return false;
    }
  }

  // ─────────────────────────────────────────
  // Mark local record as synced
  // ─────────────────────────────────────────
  Future<void> _markSynced(SyncQueueItem item) async {
    final db = await _db.database;
    final table = _getCollection(item.entityType);
    await db.update(
      table,
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [item.entityId],
    );
  }

  // ─────────────────────────────────────────
  // Convert SQLite payload → Firestore format
  // ─────────────────────────────────────────
  Map<String, dynamic> _convertToFirestorePayload(
      Map<String, dynamic> payload) {
    final converted = Map<String, dynamic>.from(payload);

    // Convert ISO date strings to Timestamps
    final dateFields = [
      'created_at', 'updated_at', 'encounter_date',
      'date_of_birth', 'accepted_at', 'completed_at',
    ];

    for (final field in dateFields) {
      if (converted[field] is String) {
        try {
          converted[field] = Timestamp.fromDate(
            DateTime.parse(converted[field]),
          );
        } catch (_) {}
      }
    }

    // Convert JSON strings back to lists/maps
    final jsonFields = [
      'allergies', 'chronic_conditions',
      'diagnoses', 'vitals',
    ];

    for (final field in jsonFields) {
      if (converted[field] is String) {
        try {
          converted[field] = jsonDecode(converted[field]);
        } catch (_) {}
      }
    }

    // Remove SQLite-only fields
    converted.remove('sync_status');

    return converted;
  }

  String _getCollection(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.patient:
        return 'patients';
      case SyncEntityType.encounter:
        return 'encounters';
      case SyncEntityType.referral:
        return 'referrals';
    }
  }

  Future<void> _updatePendingCount() async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE attempts < 3',
      );
      final count = result.first['count'] as int;
      _emitStatus(pendingCount: count);
    } catch (_) {}
  }

  void _emitStatus({
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncAt,
    String? lastError,
  }) {
    _currentStatus = SyncStatus(
      isSyncing: isSyncing ?? _currentStatus.isSyncing,
      pendingCount:
          pendingCount ?? _currentStatus.pendingCount,
      lastSyncAt: lastSyncAt ?? _currentStatus.lastSyncAt,
      lastError: lastError,
    );
    _syncStatusController.add(_currentStatus);
  }

  // Manual sync trigger (pull-to-refresh etc)
  Future<void> syncNow() async {
    await _processQueue();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncDebounceTimer?.cancel();
    _syncStatusController.close();
  }
}

class SyncStatus {
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncStatus({
    required this.isSyncing,
    required this.pendingCount,
    this.lastSyncAt,
    this.lastError,
  });
}