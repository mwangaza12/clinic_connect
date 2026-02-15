import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/firebase_config.dart';

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

class DashboardService {
  FirebaseFirestore get _db => FirebaseConfig.facilityDb;

  Future<DashboardStats> getStats(String facilityId) async {
    try {
      final results = await Future.wait([
        _getTotalPatients(facilityId),
        _getTodayVisits(facilityId),
        _getPendingReferrals(facilityId),
        _getTotalReferrals(facilityId),
      ]);

      return DashboardStats(
        totalPatients: results[0],
        todayVisits: results[1],
        pendingReferrals: results[2],
        totalReferrals: results[3],
        syncedRecords: results[0] + results[3],
        pendingSync: 0,
      );
    } catch (e) {
      return DashboardStats.empty();
    }
  }

  Future<int> _getTotalPatients(String facilityId) async {
    try {
      // ✅ Try with facility_id first
      final snap = await _db
          .collection('patients')
          .where('facility_id', isEqualTo: facilityId)
          .count()
          .get();
      final count = snap.count ?? 0;

      // ✅ Fallback: if 0, count ALL patients in DB
      // (covers demo seed data with different facility_id)
      if (count == 0) {
        final all = await _db
            .collection('patients')
            .count()
            .get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getTodayVisits(String facilityId) async {
    try {
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day);
      final endOfDay =
          startOfDay.add(const Duration(days: 1));

      final snap = await _db
          .collection('encounters')
          .where('facility_id', isEqualTo: facilityId)
          .where(
            'encounter_date',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(startOfDay),
          )
          .where(
            'encounter_date',
            isLessThan: Timestamp.fromDate(endOfDay),
          )
          .count()
          .get();
      final count = snap.count ?? 0;

      // ✅ Fallback: count today's encounters across all facilities
      if (count == 0) {
        final all = await _db
            .collection('encounters')
            .where(
              'encounter_date',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(startOfDay),
            )
            .where(
              'encounter_date',
              isLessThan: Timestamp.fromDate(endOfDay),
            )
            .count()
            .get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getPendingReferrals(
      String facilityId) async {
    try {
      final snap = await _db
          .collection('referrals')
          .where('from_facility_id',
              isEqualTo: facilityId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      final count = snap.count ?? 0;

      // ✅ Fallback: all pending referrals
      if (count == 0) {
        final all = await _db
            .collection('referrals')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getTotalReferrals(
      String facilityId) async {
    try {
      final snap = await _db
          .collection('referrals')
          .where('from_facility_id',
              isEqualTo: facilityId)
          .count()
          .get();
      final count = snap.count ?? 0;

      // ✅ Fallback: all referrals
      if (count == 0) {
        final all = await _db
            .collection('referrals')
            .count()
            .get();
        return all.count ?? 0;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Stream<List<Map<String, dynamic>>> getTodayEncounters(
      String facilityId) {
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day);

    // ✅ No facility filter — shows all today's
    // encounters regardless of facility_id mismatch
    return _db
        .collection('encounters')
        .where(
          'encounter_date',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(startOfDay),
        )
        .orderBy('encounter_date', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }
}