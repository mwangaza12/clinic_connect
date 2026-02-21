import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'clinicconnect.db');

    return await openDatabase(
      path,
      version: 4, // ✅ Increment version for new tables                  
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Patients table
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        nupi TEXT NOT NULL,
        first_name TEXT NOT NULL,
        middle_name TEXT,
        last_name TEXT NOT NULL,
        gender TEXT NOT NULL,
        date_of_birth TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        email TEXT,
        county TEXT NOT NULL,
        sub_county TEXT NOT NULL,
        ward TEXT NOT NULL,
        village TEXT NOT NULL,
        blood_group TEXT,
        allergies TEXT,
        chronic_conditions TEXT,
        next_of_kin_name TEXT,
        next_of_kin_phone TEXT,
        next_of_kin_relationship TEXT,
        facility_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Encounters table
    await db.execute('''
      CREATE TABLE encounters (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        patient_nupi TEXT NOT NULL,
        facility_id TEXT NOT NULL,
        facility_name TEXT NOT NULL,
        clinician_id TEXT NOT NULL,
        clinician_name TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        vitals TEXT,
        chief_complaint TEXT,
        history TEXT,
        examination TEXT,
        diagnoses TEXT,
        treatment_plan TEXT,
        clinical_notes TEXT,
        disposition TEXT,
        referral_id TEXT,
        encounter_date TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Referrals table
    await db.execute('''
      CREATE TABLE referrals (
        id TEXT PRIMARY KEY,
        patient_nupi TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        from_facility_id TEXT NOT NULL,
        from_facility_name TEXT NOT NULL,
        to_facility_id TEXT NOT NULL,
        to_facility_name TEXT NOT NULL,
        reason TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        clinical_notes TEXT,
        created_by TEXT NOT NULL,
        created_by_name TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sync queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        attempts INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // ✅ NEW: Program Enrollments table
    await db.execute('''
      CREATE TABLE program_enrollments (
        id TEXT PRIMARY KEY,
        patient_nupi TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        facility_id TEXT NOT NULL,
        program TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        enrollment_date TEXT NOT NULL,
        completion_date TEXT,
        outcome_notes TEXT,
        program_specific_data TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    // ✅ NEW: Program Encounters table
    await db.execute('''
      CREATE TABLE program_encounters (
        id TEXT PRIMARY KEY,
        encounter_id TEXT NOT NULL,
        enrollment_id TEXT NOT NULL,
        program TEXT NOT NULL,
        program_specific_data TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_patients_nupi ON patients (nupi)');
    await db.execute('CREATE INDEX idx_patients_facility ON patients (facility_id)');
    await db.execute('CREATE INDEX idx_encounters_patient ON encounters (patient_id)');
    await db.execute('CREATE INDEX idx_encounters_facility ON encounters (facility_id)');
    await db.execute('CREATE INDEX idx_referrals_from ON referrals (from_facility_id)');
    await db.execute('CREATE INDEX idx_referrals_to ON referrals (to_facility_id)');
    await db.execute('CREATE INDEX idx_sync_queue_entity ON sync_queue (entity_type, entity_id)');
    
    // ✅ NEW: Program indexes
    await db.execute('CREATE INDEX idx_program_enrollments_patient ON program_enrollments (patient_nupi)');
    await db.execute('CREATE INDEX idx_program_enrollments_facility ON program_enrollments (facility_id)');
    await db.execute('CREATE INDEX idx_program_enrollments_program ON program_enrollments (program)');
    await db.execute('CREATE INDEX idx_program_enrollments_status ON program_enrollments (status)');
    await db.execute('CREATE INDEX idx_program_encounters_encounter ON program_encounters (encounter_id)');
    await db.execute('CREATE INDEX idx_program_encounters_enrollment ON program_encounters (enrollment_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE patients ADD COLUMN facility_id TEXT');
    }
    
    if (oldVersion < 3) {
      // Add sync_status to existing tables if missing
      try {
        await db.execute('ALTER TABLE patients ADD COLUMN sync_status TEXT DEFAULT pending');
      } catch (_) {}

      // Create sync_queue if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          attempts INTEGER DEFAULT 0,
          last_error TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // Create encounters table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS encounters (
          id TEXT PRIMARY KEY,
          patient_id TEXT NOT NULL,
          patient_name TEXT NOT NULL,
          patient_nupi TEXT NOT NULL,
          facility_id TEXT NOT NULL,
          facility_name TEXT NOT NULL,
          clinician_id TEXT NOT NULL,
          clinician_name TEXT NOT NULL,
          type TEXT NOT NULL,
          status TEXT NOT NULL,
          vitals TEXT,
          chief_complaint TEXT,
          history TEXT,
          examination TEXT,
          diagnoses TEXT,
          treatment_plan TEXT,
          clinical_notes TEXT,
          disposition TEXT,
          referral_id TEXT,
          encounter_date TEXT NOT NULL,
          sync_status TEXT DEFAULT 'pending',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Create referrals table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS referrals (
          id TEXT PRIMARY KEY,
          patient_nupi TEXT NOT NULL,
          patient_name TEXT NOT NULL,
          from_facility_id TEXT NOT NULL,
          from_facility_name TEXT NOT NULL,
          to_facility_id TEXT NOT NULL,
          to_facility_name TEXT NOT NULL,
          reason TEXT NOT NULL,
          priority TEXT NOT NULL,
          status TEXT NOT NULL,
          clinical_notes TEXT,
          created_by TEXT NOT NULL,
          created_by_name TEXT NOT NULL,
          sync_status TEXT DEFAULT 'pending',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    // ✅ NEW: Version 4 - Add disease program tables
    if (oldVersion < 4) {
      // Create program_enrollments table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS program_enrollments (
          id TEXT PRIMARY KEY,
          patient_nupi TEXT NOT NULL,
          patient_name TEXT NOT NULL,
          facility_id TEXT NOT NULL,
          program TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          enrollment_date TEXT NOT NULL,
          completion_date TEXT,
          outcome_notes TEXT,
          program_specific_data TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          sync_status TEXT DEFAULT 'pending'
        )
      ''');

      // Create program_encounters table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS program_encounters (
          id TEXT PRIMARY KEY,
          encounter_id TEXT NOT NULL,
          enrollment_id TEXT NOT NULL,
          program TEXT NOT NULL,
          program_specific_data TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');

      // Create program indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_enrollments_patient ON program_enrollments (patient_nupi)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_enrollments_facility ON program_enrollments (facility_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_enrollments_program ON program_enrollments (program)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_enrollments_status ON program_enrollments (status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_encounters_encounter ON program_encounters (encounter_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_program_encounters_enrollment ON program_encounters (enrollment_id)');
    }
  }

  // ✅ NEW: Helper methods for program enrollments
  
  Future<List<Map<String, dynamic>>> getActiveEnrollmentsByFacility(String facilityId) async {
    final db = await database;
    return await db.query(
      'program_enrollments',
      where: 'facility_id = ? AND status = ?',
      whereArgs: [facilityId, 'active'],
      orderBy: 'enrollment_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPatientEnrollments(String patientNupi) async {
    final db = await database;
    return await db.query(
      'program_enrollments',
      where: 'patient_nupi = ?',
      whereArgs: [patientNupi],
      orderBy: 'enrollment_date DESC',
    );
  }

  Future<Map<String, int>> getProgramStatsByFacility(String facilityId) async {
    final db = await database;
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

  Future<int> insertProgramEnrollment(Map<String, dynamic> enrollment) async {
    final db = await database;
    await db.insert('program_enrollments', enrollment);
    
    // Add to sync queue
    await db.insert('sync_queue', {
      'entity_type': 'program_enrollment',
      'entity_id': enrollment['id'],
      'operation': 'create',
      'payload': enrollment.toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return 1;
  }

  Future<int> updateProgramEnrollment(String id, Map<String, dynamic> updates) async {
    final db = await database;
    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['sync_status'] = 'pending';
    
    final result = await db.update(
      'program_enrollments',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // Add to sync queue
    await db.insert('sync_queue', {
      'entity_type': 'program_enrollment',
      'entity_id': id,
      'operation': 'update',
      'payload': updates.toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return result;
  }
}