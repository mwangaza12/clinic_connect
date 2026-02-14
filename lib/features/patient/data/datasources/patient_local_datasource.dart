import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../models/patient_model.dart';

abstract class PatientLocalDatasource {
  Future<PatientModel> savePatient(PatientModel patient);
  Future<List<PatientModel>> getAllPatients();
  Future<PatientModel?> getPatientByNupi(String nupi);
  Future<void> updateSyncStatus(String patientId, String status);
}

class PatientLocalDatasourceImpl implements PatientLocalDatasource {
  final DatabaseHelper dbHelper;
  final SyncManager syncManager;

  PatientLocalDatasourceImpl({
    required this.dbHelper,
    required this.syncManager,
  });

  @override
  Future<PatientModel> savePatient(PatientModel patient) async {
    try {
      final db = await dbHelper.database;

      // Save to SQLite immediately
      await db.insert(
        'patients',
        patient.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Enqueue for Firestore sync
      await syncManager.enqueue(
        entityType: SyncEntityType.patient,
        entityId: patient.id,
        operation: SyncOperation.create,
        payload: patient.toSqlite(),
      );

      return patient;
    } catch (e) {
      throw LocalException('Failed to save patient: $e');
    }
  }

  @override
  Future<List<PatientModel>> getAllPatients() async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'patients',
        orderBy: 'created_at DESC',
      );
      return rows
          .map((row) => PatientModel.fromSqlite(row))
          .toList();
    } catch (e) {
      throw LocalException('Failed to get patients: $e');
    }
  }

  @override
  Future<PatientModel?> getPatientByNupi(String nupi) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'patients',
        where: 'nupi = ?',
        whereArgs: [nupi],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return PatientModel.fromSqlite(rows.first);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateSyncStatus(
      String patientId, String status) async {
    final db = await dbHelper.database;
    await db.update(
      'patients',
      {'sync_status': status},
      where: 'id = ?',
      whereArgs: [patientId],
    );
  }
}