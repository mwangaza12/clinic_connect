import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/patient_model.dart';

abstract class PatientLocalDatasource {
  Future<void> cachePatient(PatientModel patient);
  Future<PatientModel> getPatient(String patientId);
  Future<List<PatientModel>> getAllPatients();
  Future<List<PatientModel>> searchPatients(String query);
}

class PatientLocalDatasourceImpl implements PatientLocalDatasource {
  final DatabaseHelper databaseHelper;

  PatientLocalDatasourceImpl({required this.databaseHelper});

  @override
  Future<void> cachePatient(PatientModel patient) async {
    try {
      final db = await databaseHelper.database;
      // Use toSqlite() - correct String format
      await db.insert(
        'patients',
        patient.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheException('Failed to cache patient: ${e.toString()}');
    }
  }

  @override
  Future<PatientModel> getPatient(String patientId) async {
    try {
      final db = await databaseHelper.database;
      final results = await db.query(
        'patients',
        where: 'id = ?',
        whereArgs: [patientId],
      );

      if (results.isEmpty) throw CacheException('Patient not found in cache');

      return PatientModel.fromSqlite(results.first);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Failed to get patient: ${e.toString()}');
    }
  }

  @override
  Future<List<PatientModel>> getAllPatients() async {
    try {
      final db = await databaseHelper.database;
      final results = await db.query('patients', orderBy: 'created_at DESC');
      return results.map((json) => PatientModel.fromSqlite(json)).toList();
    } catch (e) {
      throw CacheException('Failed to get patients: ${e.toString()}');
    }
  }

  @override
  Future<List<PatientModel>> searchPatients(String query) async {
    try {
      final db = await databaseHelper.database;
      final queryLower = query.toLowerCase();

      final results = await db.query(
        'patients',
        where:
            'nupi = ? OR phone_number = ? OR LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ?',
        whereArgs: [query, query, '%$queryLower%', '%$queryLower%'],
      );

      return results.map((json) => PatientModel.fromSqlite(json)).toList();
    } catch (e) {
      throw CacheException('Failed to search patients: ${e.toString()}');
    }
  }
}