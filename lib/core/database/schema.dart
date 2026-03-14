// lib/core/database/schema.dart
//
// Single source of truth for every SQLite table, column name, and migration.
// DatabaseHelper imports this — nothing else in the app should hardcode column
// names or version numbers.

/// Current database version. Bump this whenever you add a migration in
/// [DbMigrations.all] and add the corresponding [DbSchema] DDL change.
const int kDbVersion = 5;

/// Column name constants — use these everywhere instead of raw strings so a
/// rename is a one-line change and typos become compile errors.
class Col {
  Col._();

  // ── shared ────────────────────────────────────────────────────────────────
  static const id          = 'id';
  static const createdAt   = 'created_at';
  static const updatedAt   = 'updated_at';
  static const syncStatus  = 'sync_status';
  static const facilityId  = 'facility_id';

  // ── patients ──────────────────────────────────────────────────────────────
  static const nupi                  = 'nupi';
  static const firstName             = 'first_name';
  static const middleName            = 'middle_name';
  static const lastName              = 'last_name';
  static const gender                = 'gender';
  static const dateOfBirth           = 'date_of_birth';
  static const phoneNumber           = 'phone_number';
  static const email                 = 'email';
  static const county                = 'county';
  static const subCounty             = 'sub_county';
  static const ward                  = 'ward';
  static const village               = 'village';
  static const bloodGroup            = 'blood_group';
  static const allergies             = 'allergies';
  static const chronicConditions     = 'chronic_conditions';
  static const nextOfKinName         = 'next_of_kin_name';
  static const nextOfKinPhone        = 'next_of_kin_phone';
  static const nextOfKinRelationship = 'next_of_kin_relationship';

  // ── encounters ────────────────────────────────────────────────────────────
  static const patientId      = 'patient_id';
  static const patientName    = 'patient_name';
  static const patientNupi    = 'patient_nupi';
  static const facilityName   = 'facility_name';
  static const clinicianId    = 'clinician_id';
  static const clinicianName  = 'clinician_name';
  static const type           = 'type';
  static const status         = 'status';
  static const vitals         = 'vitals';
  static const chiefComplaint = 'chief_complaint';
  static const history        = 'history';        // historyOfPresentingIllness
  static const examination    = 'examination';    // examinationFindings
  static const diagnoses      = 'diagnoses';
  static const treatmentPlan  = 'treatment_plan';
  static const clinicalNotes  = 'clinical_notes';
  static const disposition    = 'disposition';
  static const referralId     = 'referral_id';
  static const encounterDate  = 'encounter_date';

  // ── referrals ─────────────────────────────────────────────────────────────
  static const fromFacilityId   = 'from_facility_id';
  static const fromFacilityName = 'from_facility_name';
  static const toFacilityId     = 'to_facility_id';
  static const toFacilityName   = 'to_facility_name';
  static const reason           = 'reason';
  static const priority         = 'priority';
  static const createdBy        = 'created_by';
  static const createdByName    = 'created_by_name';

  // ── sync_queue ────────────────────────────────────────────────────────────
  static const entityType = 'entity_type';
  static const entityId   = 'entity_id';
  static const operation  = 'operation';
  static const payload    = 'payload';
  static const attempts   = 'attempts';
  static const lastError  = 'last_error';

  // ── program_enrollments ───────────────────────────────────────────────────
  static const program             = 'program';
  static const enrollmentDate      = 'enrollment_date';
  static const completionDate      = 'completion_date';
  static const outcomeNotes        = 'outcome_notes';
  static const programSpecificData = 'program_specific_data';

  // ── program_encounters ────────────────────────────────────────────────────
  static const encounterId  = 'encounter_id';
  static const enrollmentId = 'enrollment_id';
}

/// Table name constants.
class Tbl {
  Tbl._();

  static const patients            = 'patients';
  static const encounters          = 'encounters';
  static const referrals           = 'referrals';
  static const syncQueue           = 'sync_queue';
  static const programEnrollments  = 'program_enrollments';
  static const programEncounters   = 'program_encounters';
}

/// DDL strings for every table. Used both in [_onCreate] (fresh install) and
/// in [DbMigrations] (upgrade path).
class DbSchema {
  DbSchema._();

  static const patients = '''
    CREATE TABLE ${Tbl.patients} (
      ${Col.id}                     TEXT PRIMARY KEY,
      ${Col.nupi}                   TEXT NOT NULL,
      ${Col.firstName}              TEXT NOT NULL,
      ${Col.middleName}             TEXT,
      ${Col.lastName}               TEXT NOT NULL,
      ${Col.gender}                 TEXT NOT NULL,
      ${Col.dateOfBirth}            TEXT NOT NULL,
      ${Col.phoneNumber}            TEXT NOT NULL,
      ${Col.email}                  TEXT,
      ${Col.county}                 TEXT NOT NULL,
      ${Col.subCounty}              TEXT NOT NULL,
      ${Col.ward}                   TEXT NOT NULL,
      ${Col.village}                TEXT NOT NULL,
      ${Col.bloodGroup}             TEXT,
      ${Col.allergies}              TEXT,
      ${Col.chronicConditions}      TEXT,
      ${Col.nextOfKinName}          TEXT,
      ${Col.nextOfKinPhone}         TEXT,
      ${Col.nextOfKinRelationship}  TEXT,
      ${Col.facilityId}             TEXT,
      ${Col.syncStatus}             TEXT DEFAULT 'pending',
      ${Col.createdAt}              TEXT NOT NULL,
      ${Col.updatedAt}              TEXT NOT NULL
    )
  ''';

  static const encounters = '''
    CREATE TABLE ${Tbl.encounters} (
      ${Col.id}             TEXT PRIMARY KEY,
      ${Col.patientId}      TEXT NOT NULL,
      ${Col.patientName}    TEXT NOT NULL,
      ${Col.patientNupi}    TEXT NOT NULL,
      ${Col.facilityId}     TEXT NOT NULL,
      ${Col.facilityName}   TEXT NOT NULL,
      ${Col.clinicianId}    TEXT NOT NULL,
      ${Col.clinicianName}  TEXT NOT NULL,
      ${Col.type}           TEXT NOT NULL,
      ${Col.status}         TEXT NOT NULL,
      ${Col.vitals}         TEXT,
      ${Col.chiefComplaint} TEXT,
      ${Col.history}        TEXT,
      ${Col.examination}    TEXT,
      ${Col.diagnoses}      TEXT,
      ${Col.treatmentPlan}  TEXT,
      ${Col.clinicalNotes}  TEXT,
      ${Col.disposition}    TEXT,
      ${Col.referralId}     TEXT,
      ${Col.encounterDate}  TEXT NOT NULL,
      ${Col.syncStatus}     TEXT DEFAULT 'pending',
      ${Col.createdAt}      TEXT NOT NULL,
      ${Col.updatedAt}      TEXT NOT NULL
    )
  ''';

  static const referrals = '''
    CREATE TABLE ${Tbl.referrals} (
      ${Col.id}               TEXT PRIMARY KEY,
      ${Col.patientNupi}      TEXT NOT NULL,
      ${Col.patientName}      TEXT NOT NULL,
      ${Col.fromFacilityId}   TEXT NOT NULL,
      ${Col.fromFacilityName} TEXT NOT NULL,
      ${Col.toFacilityId}     TEXT NOT NULL,
      ${Col.toFacilityName}   TEXT NOT NULL,
      ${Col.reason}           TEXT NOT NULL,
      ${Col.priority}         TEXT NOT NULL,
      ${Col.status}           TEXT NOT NULL,
      ${Col.clinicalNotes}    TEXT,
      ${Col.createdBy}        TEXT NOT NULL,
      ${Col.createdByName}    TEXT NOT NULL,
      ${Col.syncStatus}       TEXT DEFAULT 'pending',
      ${Col.createdAt}        TEXT NOT NULL,
      ${Col.updatedAt}        TEXT NOT NULL
    )
  ''';

  static const syncQueue = '''
    CREATE TABLE ${Tbl.syncQueue} (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Col.entityType} TEXT NOT NULL,
      ${Col.entityId}   TEXT NOT NULL,
      ${Col.operation}  TEXT NOT NULL,
      ${Col.payload}    TEXT NOT NULL,
      ${Col.attempts}   INTEGER DEFAULT 0,
      ${Col.lastError}  TEXT,
      ${Col.createdAt}  TEXT NOT NULL
    )
  ''';

  static const programEnrollments = '''
    CREATE TABLE ${Tbl.programEnrollments} (
      ${Col.id}                   TEXT PRIMARY KEY,
      ${Col.patientNupi}          TEXT NOT NULL,
      ${Col.patientName}          TEXT NOT NULL,
      ${Col.facilityId}           TEXT NOT NULL,
      ${Col.program}              TEXT NOT NULL,
      ${Col.status}               TEXT NOT NULL DEFAULT 'active',
      ${Col.enrollmentDate}       TEXT NOT NULL,
      ${Col.completionDate}       TEXT,
      ${Col.outcomeNotes}         TEXT,
      ${Col.programSpecificData}  TEXT,
      ${Col.createdAt}            TEXT NOT NULL,
      ${Col.updatedAt}            TEXT,
      ${Col.syncStatus}           TEXT DEFAULT 'pending'
    )
  ''';

  static const programEncounters = '''
    CREATE TABLE ${Tbl.programEncounters} (
      ${Col.id}                   TEXT PRIMARY KEY,
      ${Col.encounterId}          TEXT NOT NULL,
      ${Col.enrollmentId}         TEXT NOT NULL,
      ${Col.program}              TEXT NOT NULL,
      ${Col.programSpecificData}  TEXT,
      ${Col.createdAt}            TEXT NOT NULL,
      ${Col.updatedAt}            TEXT
    )
  ''';
}

/// Every migration step in order. Add a new entry here (and bump [kDbVersion])
/// whenever the schema changes. Each entry runs only once — when oldVersion is
/// below the step's [version].
class DbMigrations {
  DbMigrations._();

  static final all = <_Migration>[
    _Migration(
      version: 2,
      description: 'Add facility_id to patients',
      run: (db) async {
        await db.execute(
            'ALTER TABLE ${Tbl.patients} ADD COLUMN ${Col.facilityId} TEXT');
      },
    ),
    _Migration(
      version: 3,
      description: 'Add sync_status; create sync_queue, encounters, referrals',
      run: (db) async {
        try {
          await db.execute(
              "ALTER TABLE ${Tbl.patients} ADD COLUMN ${Col.syncStatus} TEXT DEFAULT 'pending'");
        } catch (_) {} // already exists on fresh installs

        await db.execute(
            'CREATE TABLE IF NOT EXISTS ${Tbl.syncQueue} AS SELECT * FROM ${Tbl.syncQueue} WHERE 0');
        // Full create — IF NOT EXISTS guards against fresh installs
        for (final ddl in [
          DbSchema.syncQueue.replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'),
          DbSchema.encounters.replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'),
          DbSchema.referrals.replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'),
        ]) {
          try { await db.execute(ddl); } catch (_) {}
        }
      },
    ),
    _Migration(
      version: 4,
      description: 'Add program_enrollments and program_encounters',
      run: (db) async {
        for (final ddl in [
          DbSchema.programEnrollments.replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'),
          DbSchema.programEncounters.replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'),
        ]) {
          await db.execute(ddl);
        }
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_program_enrollments_patient ON ${Tbl.programEnrollments} (${Col.patientNupi})');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_program_enrollments_facility ON ${Tbl.programEnrollments} (${Col.facilityId})');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_program_enrollments_program ON ${Tbl.programEnrollments} (${Col.program})');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_program_enrollments_status ON ${Tbl.programEnrollments} (${Col.status})');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_program_encounters_encounter ON ${Tbl.programEncounters} (${Col.encounterId})');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_program_encounters_enrollment ON ${Tbl.programEncounters} (${Col.enrollmentId})');
      },
    ),
    _Migration(
      version: 5,
      description: 'Add sync_status to encounters if missing (retrofit)',
      run: (db) async {
        // Devices that installed before sync_status was in the encounters DDL
        // won't have the column. Safe to ignore if it already exists.
        try {
          await db.execute(
              "ALTER TABLE ${Tbl.encounters} ADD COLUMN ${Col.syncStatus} TEXT DEFAULT 'pending'");
        } catch (_) {}
      },
    ),
  ];
}

class _Migration {
  final int version;
  final String description;
  final Future<void> Function(dynamic db) run;
  const _Migration({
    required this.version,
    required this.description,
    required this.run,
  });
}