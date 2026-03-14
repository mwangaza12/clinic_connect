// lib/core/database/database_helper.dart
//
// Owns the SQLite connection lifecycle only.
// All table DDL and migration logic lives in schema.dart.

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'schema.dart';

class DatabaseHelper {
  // Singleton
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'clinicconnect.db');

    return openDatabase(
      path,
      version:   kDbVersion,
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Fresh install — create every table and index from [DbSchema].
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(DbSchema.patients);
    await db.execute(DbSchema.encounters);
    await db.execute(DbSchema.referrals);
    await db.execute(DbSchema.syncQueue);
    await db.execute(DbSchema.programEnrollments);
    await db.execute(DbSchema.programEncounters);

    // Core indexes
    await db.execute('CREATE INDEX idx_patients_nupi       ON ${Tbl.patients}   (${Col.nupi})');
    await db.execute('CREATE INDEX idx_patients_facility   ON ${Tbl.patients}   (${Col.facilityId})');
    await db.execute('CREATE INDEX idx_encounters_patient  ON ${Tbl.encounters} (${Col.patientId})');
    await db.execute('CREATE INDEX idx_encounters_facility ON ${Tbl.encounters} (${Col.facilityId})');
    await db.execute('CREATE INDEX idx_referrals_from      ON ${Tbl.referrals}  (${Col.fromFacilityId})');
    await db.execute('CREATE INDEX idx_referrals_to        ON ${Tbl.referrals}  (${Col.toFacilityId})');
    await db.execute('CREATE INDEX idx_sync_queue_entity   ON ${Tbl.syncQueue}  (${Col.entityType}, ${Col.entityId})');

    // Program indexes
    await db.execute('CREATE INDEX idx_program_enrollments_patient  ON ${Tbl.programEnrollments} (${Col.patientNupi})');
    await db.execute('CREATE INDEX idx_program_enrollments_facility ON ${Tbl.programEnrollments} (${Col.facilityId})');
    await db.execute('CREATE INDEX idx_program_enrollments_program  ON ${Tbl.programEnrollments} (${Col.program})');
    await db.execute('CREATE INDEX idx_program_enrollments_status   ON ${Tbl.programEnrollments} (${Col.status})');
    await db.execute('CREATE INDEX idx_program_encounters_encounter  ON ${Tbl.programEncounters} (${Col.encounterId})');
    await db.execute('CREATE INDEX idx_program_encounters_enrollment ON ${Tbl.programEncounters} (${Col.enrollmentId})');
  }

  /// Incremental upgrade — run every pending migration in [DbMigrations.all].
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (final migration in DbMigrations.all) {
      if (oldVersion < migration.version) {
        await migration.run(db);
      }
    }
  }

  // ── Program Enrollments helpers ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getActiveEnrollmentsByFacility(
      String facilityId) async {
    final db = await database;
    return db.query(
      Tbl.programEnrollments,
      where:     '${Col.facilityId} = ? AND ${Col.status} = ?',
      whereArgs: [facilityId, 'active'],
      orderBy:   '${Col.enrollmentDate} DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPatientEnrollments(
      String patientNupi) async {
    final db = await database;
    return db.query(
      Tbl.programEnrollments,
      where:     '${Col.patientNupi} = ?',
      whereArgs: [patientNupi],
      orderBy:   '${Col.enrollmentDate} DESC',
    );
  }

  Future<Map<String, int>> getProgramStatsByFacility(
      String facilityId) async {
    final db      = await database;
    final results = await db.rawQuery('''
      SELECT ${Col.program}, COUNT(*) AS count
      FROM   ${Tbl.programEnrollments}
      WHERE  ${Col.facilityId} = ? AND ${Col.status} = 'active'
      GROUP  BY ${Col.program}
    ''', [facilityId]);

    return Map.fromEntries(
      results.map((row) => MapEntry(
            row[Col.program] as String,
            row['count'] as int,
          )),
    );
  }

  Future<void> insertProgramEnrollment(
      Map<String, dynamic> enrollment) async {
    final db = await database;
    await db.insert(Tbl.programEnrollments, enrollment);
    await _enqueue(
      db:         db,
      entityType: Tbl.programEnrollments,
      entityId:   enrollment[Col.id] as String,
      operation:  'create',
      payload:    enrollment,
    );
  }

  Future<void> updateProgramEnrollment(
      String id, Map<String, dynamic> updates) async {
    final db = await database;
    updates[Col.updatedAt]  = DateTime.now().toIso8601String();
    updates[Col.syncStatus] = 'pending';

    await db.update(
      Tbl.programEnrollments,
      updates,
      where:     '${Col.id} = ?',
      whereArgs: [id],
    );
    await _enqueue(
      db:         db,
      entityType: Tbl.programEnrollments,
      entityId:   id,
      operation:  'update',
      payload:    updates,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _enqueue({
    required Database db,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await db.insert(Tbl.syncQueue, {
      Col.entityType: entityType,
      Col.entityId:   entityId,
      Col.operation:  operation,
      Col.payload:    jsonEncode(payload),
      Col.attempts:   0,
      Col.createdAt:  DateTime.now().toIso8601String(),
    });
  }
}