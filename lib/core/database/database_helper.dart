import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'clinicconnect.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Patients table
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        nupi TEXT UNIQUE NOT NULL,
        first_name TEXT NOT NULL,
        middle_name TEXT NOT NULL,
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_nupi ON patients(nupi)');
    await db.execute('CREATE INDEX idx_phone ON patients(phone_number)');
    await db.execute('CREATE INDEX idx_name ON patients(last_name, first_name)');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}