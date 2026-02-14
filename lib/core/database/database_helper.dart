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
      version: 1,                    
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

    // ✅ Sync queue — tracks everything pending upload
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

    // Indexes
    await db.execute(
        'CREATE INDEX idx_patients_nupi ON patients (nupi)');
    await db.execute(
        'CREATE INDEX idx_encounters_patient ON encounters (patient_id)');
    await db.execute(
        'CREATE INDEX idx_referrals_from ON referrals (from_facility_id)');
    await db.execute(
        'CREATE INDEX idx_sync_queue_entity ON sync_queue (entity_type, entity_id)');
  }

  Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE patients ADD COLUMN facility_id TEXT');
    }
    if (oldVersion < 3) {
      // Add sync_status to existing tables if missing
      try {
        await db.execute(
            'ALTER TABLE patients ADD COLUMN sync_status TEXT DEFAULT pending');
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
  }
}