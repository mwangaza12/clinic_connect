// lib/features/disease_program/data/datasources/program_local_datasource.dart

import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../models/program_enrollment_model.dart';

abstract class ProgramLocalDatasource {
  Future<void> cacheEnrollment(ProgramEnrollmentModel enrollment);
  Future<List<ProgramEnrollmentModel>> getPatientEnrollments(String patientNupi);
  Future<List<ProgramEnrollmentModel>> getFacilityEnrollments(String facilityId);
  Future<Map<String, int>> getProgramStats(String facilityId);
  Future<void> updateEnrollmentStatus(
      String enrollmentId, String status, String? notes);
}

class ProgramLocalDatasourceImpl implements ProgramLocalDatasource {
  final DatabaseHelper databaseHelper;
  final _syncManager = SyncManager();

  ProgramLocalDatasourceImpl({required this.databaseHelper});

  @override
  Future<void> cacheEnrollment(ProgramEnrollmentModel enrollment) async {
    final db = await databaseHelper.database;

    await db.insert(
      'program_enrollments',
      enrollment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // BUG FIX 1: old code inserted directly into sync_queue using
    //   'payload': enrollment.toMap().toString()
    // .toString() on a Map produces "{key: value}" — not valid JSON.
    // SyncQueueItem.fromMap calls jsonDecode(payload) → FormatException crash.
    //
    // BUG FIX 2: old code bypassed SyncManager.enqueue() entirely, so the
    // 'attempts' column was absent and SyncManager never processed the row.
    await _syncManager.enqueue(
      entityType: SyncEntityType.programEnrollment,
      entityId:   enrollment.id,
      operation:  SyncOperation.create,
      payload:    _jsonSafeMap(enrollment.toMap()),
    );
  }

  @override
  Future<List<ProgramEnrollmentModel>> getPatientEnrollments(
      String patientNupi) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      'program_enrollments',
      where:     'patient_nupi = ?',
      whereArgs: [patientNupi],
      orderBy:   'enrollment_date DESC',
    );
    return rows.map(ProgramEnrollmentModel.fromMap).toList();
  }

  @override
  Future<List<ProgramEnrollmentModel>> getFacilityEnrollments(
      String facilityId) async {
    final db = await databaseHelper.database;

    // BUG FIX 3: old code always added "AND status = 'active'" — this hid
    // every completed/defaulted/transferred enrollment from the dashboard and
    // broke getEnrollmentById (which passes '' as facilityId) entirely.
    // The dashboard calculates stats client-side, so return ALL enrollments.
    final rows = await db.query(
      'program_enrollments',
      where:     facilityId.isNotEmpty ? 'facility_id = ?' : null,
      whereArgs: facilityId.isNotEmpty ? [facilityId] : null,
      orderBy:   'enrollment_date DESC',
    );
    return rows.map(ProgramEnrollmentModel.fromMap).toList();
  }

  @override
  Future<Map<String, int>> getProgramStats(String facilityId) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery('''
      SELECT program, COUNT(*) as count
      FROM program_enrollments
      WHERE facility_id = ? AND status = 'active'
      GROUP BY program
    ''', [facilityId]);

    return Map.fromEntries(
      rows.map((r) => MapEntry(r['program'] as String, r['count'] as int)),
    );
  }

  @override
  Future<void> updateEnrollmentStatus(
    String enrollmentId,
    String status,
    String? notes,
  ) async {
    final db = await databaseHelper.database;

    final updates = <String, dynamic>{
      'status':        status,
      'outcome_notes': notes,
      'updated_at':    DateTime.now().toIso8601String(),
      'sync_status':   'pending',
    };

    if (status == 'completed' || status == 'died') {
      updates['completion_date'] = DateTime.now().toIso8601String();
    }

    await db.update(
      'program_enrollments',
      updates,
      where:     'id = ?',
      whereArgs: [enrollmentId],
    );

    // BUG FIX: same payload bug as cacheEnrollment.
    await _syncManager.enqueue(
      entityType: SyncEntityType.programEnrollment,
      entityId:   enrollmentId,
      operation:  SyncOperation.update,
      payload:    _jsonSafeMap(updates),
    );
  }

  /// Strips any non-JSON-serialisable values from a map before passing
  /// it to SyncManager (which calls jsonEncode on the payload internally).
  /// Strings, numbers, booleans and nulls pass through unchanged.
  Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v == null || v is String || v is num || v is bool) {
        return MapEntry(k, v);
      }
      return MapEntry(k, v.toString());
    });
  }
}