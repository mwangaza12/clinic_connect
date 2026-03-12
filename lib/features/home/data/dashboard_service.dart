// lib/features/home/data/dashboard_service.dart
//
// Offline-aware dashboard stats.
//
// Online  → queries Firestore (existing behaviour, unchanged)
// Offline → queries local SQLite directly — never returns all-zeros

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/firebase_config.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/sync/connectivity_manager.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class DashboardStats {
  final int totalPatients;
  final int todayVisits;
  final int pendingReferrals;
  final int totalReferrals;
  final int syncedRecords;
  final int pendingSync;

  const DashboardStats({
    required this.totalPatients,
    required this.todayVisits,
    required this.pendingReferrals,
    required this.totalReferrals,
    required this.syncedRecords,
    required this.pendingSync,
  });

  factory DashboardStats.empty() => const DashboardStats(
        totalPatients: 0,
        todayVisits: 0,
        pendingReferrals: 0,
        totalReferrals: 0,
        syncedRecords: 0,
        pendingSync: 0,
      );
}

// ─── Service ─────────────────────────────────────────────────────────────────

class DashboardService {
  final _db       = DatabaseHelper();
  final _conn     = ConnectivityManager();

  FirebaseFirestore get _firestore => FirebaseConfig.facilityDb;

  // ── Public API ─────────────────────────────────────────────────

  Future<DashboardStats> getStats(String facilityId) async {
    final online = await _conn.checkConnectivity();
    return online
        ? _getStatsFirestore(facilityId)
        : _getStatsSQLite(facilityId);
  }

  /// Returns today's encounters for the dashboard list.
  /// Offline → reads from SQLite.  Online → Firestore stream, first emission.
  Future<List<Map<String, dynamic>>> getTodayEncountersList(
      String facilityId) async {
    final online = await _conn.checkConnectivity();
    return online
        ? _getTodayEncountersFirestore(facilityId)
        : _getTodayEncountersSQLite(facilityId);
  }

  /// Stream variant kept for any widgets that still use it.
  /// Offline → emits a single snapshot from SQLite then nothing more.
  Stream<List<Map<String, dynamic>>> getTodayEncounters(String facilityId) {
    if (!_conn.isOnline) {
      return Stream.fromFuture(_getTodayEncountersSQLite(facilityId));
    }
    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('encounters')
        .where('encounter_date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('encounter_date', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  // ── Firestore stats (online path — unchanged logic) ────────────

  Future<DashboardStats> _getStatsFirestore(String facilityId) async {
    try {
      final results = await Future.wait([
        _getTotalPatientsFirestore(facilityId),
        _getTodayVisitsFirestore(facilityId),
        _getPendingReferralsFirestore(facilityId),
        _getTotalReferralsFirestore(facilityId),
      ]);
      return DashboardStats(
        totalPatients:   results[0],
        todayVisits:     results[1],
        pendingReferrals: results[2],
        totalReferrals:  results[3],
        syncedRecords:   results[0] + results[3],
        pendingSync:     0,
      );
    } catch (_) {
      // Firestore failed mid-flight (e.g. connectivity dropped after check)
      // — fall back to SQLite so the UI never stays at zero.
      return _getStatsSQLite(facilityId);
    }
  }

  Future<int> _getTotalPatientsFirestore(String facilityId) async {
    try {
      final snap = await _firestore
          .collection('patients')
          .where('facility_id', isEqualTo: facilityId)
          .count()
          .get();
      final count = snap.count ?? 0;
      if (count == 0) {
        final all = await _firestore.collection('patients').count().get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) { return 0; }
  }

  Future<int> _getTodayVisitsFirestore(String facilityId) async {
    try {
      final now        = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay   = startOfDay.add(const Duration(days: 1));
      final snap = await _firestore
          .collection('encounters')
          .where('facility_id', isEqualTo: facilityId)
          .where('encounter_date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('encounter_date', isLessThan: Timestamp.fromDate(endOfDay))
          .count()
          .get();
      final count = snap.count ?? 0;
      if (count == 0) {
        final all = await _firestore
            .collection('encounters')
            .where('encounter_date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('encounter_date',
                isLessThan: Timestamp.fromDate(endOfDay))
            .count()
            .get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) { return 0; }
  }

  Future<int> _getPendingReferralsFirestore(String facilityId) async {
    try {
      final snap = await _firestore
          .collection('referrals')
          .where('from_facility_id', isEqualTo: facilityId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      final count = snap.count ?? 0;
      if (count == 0) {
        final all = await _firestore
            .collection('referrals')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) { return 0; }
  }

  Future<int> _getTotalReferralsFirestore(String facilityId) async {
    try {
      final snap = await _firestore
          .collection('referrals')
          .where('from_facility_id', isEqualTo: facilityId)
          .count()
          .get();
      final count = snap.count ?? 0;
      if (count == 0) {
        final all = await _firestore.collection('referrals').count().get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) { return 0; }
  }

  Future<List<Map<String, dynamic>>> _getTodayEncountersFirestore(
      String facilityId) async {
    try {
      final now        = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final snap = await _firestore
          .collection('encounters')
          .where('encounter_date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('encounter_date', descending: true)
          .limit(10)
          .get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (_) {
      return _getTodayEncountersSQLite(facilityId);
    }
  }

  // ── SQLite stats (offline path) ────────────────────────────────

  Future<DashboardStats> _getStatsSQLite(String facilityId) async {
    try {
      final db = await _db.database;

      // Total patients for this facility
      final patRows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM patients WHERE facility_id = ?',
        [facilityId],
      );
      final totalPatients = (patRows.first['c'] as int?) ?? 0;

      // Today's encounters — encounter_date stored as ISO-8601 string
      // e.g. "2025-03-12T08:30:00.000"
      final todayPrefix = _todayPrefix(); // "2025-03-12"
      final encRows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM encounters "
        "WHERE facility_id = ? AND encounter_date LIKE ?",
        [facilityId, '$todayPrefix%'],
      );
      final todayVisits = (encRows.first['c'] as int?) ?? 0;

      // Pending referrals from this facility
      final pendingRows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM referrals "
        "WHERE from_facility_id = ? AND status = 'pending'",
        [facilityId],
      );
      final pendingReferrals = (pendingRows.first['c'] as int?) ?? 0;

      // Total referrals from this facility
      final totalRefRows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM referrals WHERE from_facility_id = ?',
        [facilityId],
      );
      final totalReferrals = (totalRefRows.first['c'] as int?) ?? 0;

      // Pending sync items (anything in queue not yet synced)
      final syncRows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM sync_queue WHERE attempts < 3",
      );
      final pendingSync = (syncRows.first['c'] as int?) ?? 0;

      // Synced = records that have sync_status = 'synced'
      final syncedPatRows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM patients "
        "WHERE facility_id = ? AND sync_status = 'synced'",
        [facilityId],
      );
      final syncedEncRows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM encounters "
        "WHERE facility_id = ? AND sync_status = 'synced'",
        [facilityId],
      );
      final syncedRecords =
          ((syncedPatRows.first['c'] as int?) ?? 0) +
          ((syncedEncRows.first['c'] as int?) ?? 0);

      return DashboardStats(
        totalPatients:    totalPatients,
        todayVisits:      todayVisits,
        pendingReferrals: pendingReferrals,
        totalReferrals:   totalReferrals,
        syncedRecords:    syncedRecords,
        pendingSync:      pendingSync,
      );
    } catch (_) {
      return DashboardStats.empty();
    }
  }

  Future<List<Map<String, dynamic>>> _getTodayEncountersSQLite(
      String facilityId) async {
    try {
      final db          = await _db.database;
      final todayPrefix = _todayPrefix();
      final rows = await db.rawQuery(
        "SELECT * FROM encounters "
        "WHERE facility_id = ? AND encounter_date LIKE ? "
        "ORDER BY encounter_date DESC "
        "LIMIT 10",
        [facilityId, '$todayPrefix%'],
      );
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns "YYYY-MM-DD" for today — used in SQLite LIKE queries because
  /// encounter_date is stored as ISO-8601 strings ("2025-03-12T08:30:00.000").
  String _todayPrefix() {
    final now = DateTime.now();
    final m   = now.month.toString().padLeft(2, '0');
    final d   = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}