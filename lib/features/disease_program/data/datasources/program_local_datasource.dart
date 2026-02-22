import '../../../../core/database/database_helper.dart';
import '../models/program_enrollment_model.dart';

abstract class ProgramLocalDatasource {
  Future<void> cacheEnrollment(ProgramEnrollmentModel enrollment);
  Future<List<ProgramEnrollmentModel>> getPatientEnrollments(String patientNupi);
  Future<List<ProgramEnrollmentModel>> getFacilityEnrollments(String facilityId);
  Future<Map<String, int>> getProgramStats(String facilityId);
  Future<void> updateEnrollmentStatus(String enrollmentId, String status, String? notes);
}

class ProgramLocalDatasourceImpl implements ProgramLocalDatasource {
  final DatabaseHelper databaseHelper;

  ProgramLocalDatasourceImpl({required this.databaseHelper});

  @override
  Future<void> cacheEnrollment(ProgramEnrollmentModel enrollment) async {
    final db = await databaseHelper.database;
    await db.insert('program_enrollments', enrollment.toMap());
    
    // Add to sync queue
    await db.insert('sync_queue', {
      'entity_type': 'program_enrollment',
      'entity_id': enrollment.id,
      'operation': 'create',
      'payload': enrollment.toMap().toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<ProgramEnrollmentModel>> getPatientEnrollments(String patientNupi) async {
    final db = await databaseHelper.database;
    final results = await db.query(
      'program_enrollments',
      where: 'patient_nupi = ?',
      whereArgs: [patientNupi],
      orderBy: 'enrollment_date DESC',
    );
    
    return results.map((map) => ProgramEnrollmentModel.fromMap(map)).toList();
  }

  @override
  Future<List<ProgramEnrollmentModel>> getFacilityEnrollments(String facilityId) async {
    final db = await databaseHelper.database;
    final results = await db.query(
      'program_enrollments',
      where: 'facility_id = ? AND status = ?',
      whereArgs: [facilityId, 'active'],
      orderBy: 'enrollment_date DESC',
    );
    
    return results.map((map) => ProgramEnrollmentModel.fromMap(map)).toList();
  }

  @override
  Future<Map<String, int>> getProgramStats(String facilityId) async {
    final db = await databaseHelper.database;
    final results = await db.rawQuery('''
      SELECT program, COUNT(*) as count
      FROM program_enrollments
      WHERE facility_id = ? AND status = 'active'
      GROUP BY program
    ''', [facilityId]);

    return Map.fromEntries(
      results.map((row) => MapEntry(
        row['program'] as String,
        row['count'] as int,
      )),
    );
  }

  @override
  Future<void> updateEnrollmentStatus(String enrollmentId, String status, String? notes) async {
    final db = await databaseHelper.database;
    final updates = {
      'status': status,
      'outcome_notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    };
    
    if (status == 'completed' || status == 'died') {
      updates['completion_date'] = DateTime.now().toIso8601String();
    }
    
    await db.update(
      'program_enrollments',
      updates,
      where: 'id = ?',
      whereArgs: [enrollmentId],
    );
    
    // Add to sync queue
    await db.insert('sync_queue', {
      'entity_type': 'program_enrollment',
      'entity_id': enrollmentId,
      'operation': 'update',
      'payload': updates.toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}