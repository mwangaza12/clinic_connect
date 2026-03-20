import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/encounter.dart';

class VitalsModel extends Vitals {
  const VitalsModel({
    super.systolicBP,
    super.diastolicBP,
    super.temperature,
    super.weight,
    super.height,
    super.oxygenSaturation,
    super.pulseRate,
    super.respiratoryRate,
    super.bloodGlucose,
    super.muac,
  });

  factory VitalsModel.fromMap(Map<String, dynamic> map) {
    return VitalsModel(
      systolicBP:       (map['systolic_bp'] as num?)?.toDouble(),
      diastolicBP:      (map['diastolic_bp'] as num?)?.toDouble(),
      temperature:      (map['temperature'] as num?)?.toDouble(),
      weight:           (map['weight'] as num?)?.toDouble(),
      height:           (map['height'] as num?)?.toDouble(),
      oxygenSaturation: (map['oxygen_saturation'] as num?)?.toDouble(),
      pulseRate:        map['pulse_rate'] as int?,
      respiratoryRate:  map['respiratory_rate'] as int?,
      bloodGlucose:     (map['blood_glucose'] as num?)?.toDouble(),
      muac:             map['muac'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'systolic_bp':       systolicBP,
      'diastolic_bp':      diastolicBP,
      'temperature':       temperature,
      'weight':            weight,
      'height':            height,
      'oxygen_saturation': oxygenSaturation,
      'pulse_rate':        pulseRate,
      'respiratory_rate':  respiratoryRate,
      'blood_glucose':     bloodGlucose,
      'muac':              muac,
    };
  }
}

class DiagnosisModel extends Diagnosis {
  const DiagnosisModel({
    required super.code,
    required super.description,
    required super.isPrimary,
  });

  factory DiagnosisModel.fromMap(Map<String, dynamic> map) {
    return DiagnosisModel(
      code:        map['code'] ?? '',
      description: map['description'] ?? '',
      isPrimary:   map['is_primary'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code':        code,
      'description': description,
      'is_primary':  isPrimary,
    };
  }
}

class EncounterModel extends Encounter {
  const EncounterModel({
    required super.id,
    required super.patientId,
    required super.patientName,
    required super.patientNupi,
    required super.facilityId,
    required super.facilityName,
    required super.clinicianId,
    required super.clinicianName,
    required super.type,
    required super.status,
    super.vitals,
    super.chiefComplaint,
    super.historyOfPresentingIllness,
    super.examinationFindings,
    required super.diagnoses,
    super.treatmentPlan,
    super.clinicalNotes,
    super.disposition,
    super.referralId,
    required super.encounterDate,
    required super.createdAt,
    required super.updatedAt,
  });

  // ── FIRESTORE ────────────────────────────────────────────────────────────────

  factory EncounterModel.fromFirestore(Map<String, dynamic> json) {
    // Helper: reads snake_case first, falls back to camelCase.
    // Supports both the Flutter app format and the Node.js backend format.
    T? r<T>(String snake, String camel) =>
        (json[snake] ?? json[camel]) as T?;

    // Date: may be Timestamp (app), ISO string (backend), or null
    DateTime parseDate(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v == null)        return DateTime.now();
      if (v is Timestamp)   return v.toDate();
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    // Vitals: stored as 'vitals' (app) or 'vital_signs' (backend)
    VitalsModel? parseVitals() {
      final v = json['vitals'] ?? json['vital_signs'];
      if (v == null) return null;
      if (v is Map) return VitalsModel.fromMap(Map<String, dynamic>.from(v));
      return null;
    }

    // Diagnoses: app stores List<Map>, backend stores List<Map> with different keys
    List<DiagnosisModel> parseDiagnoses() {
      final raw = json['diagnoses'];
      if (raw == null) return [];
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw) as List;
          return decoded
              .map((d) => DiagnosisModel.fromMap(Map<String, dynamic>.from(d)))
              .toList();
        } catch (_) { return []; }
      }
      if (raw is List) {
        return raw
            .map((d) => DiagnosisModel.fromMap(Map<String, dynamic>.from(d as Map)))
            .toList();
      }
      return [];
    }

    // EncounterType: app uses 'type', backend uses 'encounter_type'
    final typeStr = r<String>('type', 'encounterType') ??
                    r<String>('encounter_type', 'encounterType') ?? 'outpatient';
    final type = EncounterType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => EncounterType.outpatient,
    );

    // patientName: app stores it, backend does NOT — derive from nupi as fallback
    final patientName = r<String>('patient_name', 'patientName') ?? '';

    return EncounterModel(
      id:           json['id'] as String? ?? '',
      patientId:    r<String>('patient_id',    'patientId')    ?? '',
      patientName:  patientName,
      patientNupi:  r<String>('patient_nupi',  'patientNupi')  ?? '',
      facilityId:   r<String>('facility_id',   'facilityId')   ?? '',
      facilityName: r<String>('facility_name', 'facilityName') ??
                    json['source'] as String? ?? '',
      clinicianId:   r<String>('clinician_id',   'clinicianId')   ?? '',
      clinicianName: r<String>('clinician_name', 'clinicianName') ??
                     r<String>('practitioner_name', 'practitionerName') ?? '',
      type:   type,
      status: EncounterStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? ''),
        orElse: () => EncounterStatus.finished,
      ),
      vitals:                     parseVitals(),
      chiefComplaint:             r<String>('chief_complaint',              'chiefComplaint'),
      historyOfPresentingIllness: r<String>('history_of_presenting_illness','historyOfPresentingIllness') ??
                                  r<String>('history',                      'history'),
      examinationFindings:        r<String>('examination_findings',         'examinationFindings') ??
                                  r<String>('examination',                  'examination'),
      diagnoses:     parseDiagnoses(),
      treatmentPlan: r<String>('treatment_plan', 'treatmentPlan'),
      clinicalNotes: r<String>('clinical_notes', 'clinicalNotes') ??
                     r<String>('notes',          'notes'),
      disposition: json['disposition'] != null
          ? Disposition.values.firstWhere(
              (e) => e.name == json['disposition'],
              orElse: () => Disposition.discharged,
            )
          : null,
      referralId:    r<String>('referral_id', 'referralId'),
      encounterDate: parseDate('encounter_date', 'encounterDate'),
      createdAt:     parseDate('created_at',     'createdAt'),
      updatedAt:     parseDate('updated_at',     'updatedAt'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id':            id,
      'patient_id':    patientId,
      'patient_name':  patientName,
      'patient_nupi':  patientNupi,
      'facility_id':   facilityId,
      'facility_name': facilityName,
      'clinician_id':  clinicianId,
      'clinician_name': clinicianName,
      'type':   type.name,
      'status': status.name,

      // ✅ Safe conversion — no cast needed
      'vitals': vitals == null
          ? null
          : VitalsModel(
              systolicBP:       vitals!.systolicBP,
              diastolicBP:      vitals!.diastolicBP,
              temperature:      vitals!.temperature,
              weight:           vitals!.weight,
              height:           vitals!.height,
              oxygenSaturation: vitals!.oxygenSaturation,
              pulseRate:        vitals!.pulseRate,
              respiratoryRate:  vitals!.respiratoryRate,
              bloodGlucose:     vitals!.bloodGlucose,
              muac:             vitals!.muac,
            ).toMap(),

      'chief_complaint':               chiefComplaint,
      'history':     historyOfPresentingIllness,
      'examination': examinationFindings,

      // ✅ Safe conversion — no cast needed
      'diagnoses': diagnoses
          .map((d) => DiagnosisModel(
                code:        d.code,
                description: d.description,
                isPrimary:   d.isPrimary,
              ).toMap())
          .toList(),

      'treatment_plan': treatmentPlan,
      'clinical_notes': clinicalNotes,
      'disposition':    disposition?.name,
      'referral_id':    referralId,
      'encounter_date': Timestamp.fromDate(encounterDate),
      'created_at':     Timestamp.fromDate(createdAt),
      'updated_at':     Timestamp.fromDate(updatedAt),
    };
  }

  // ── SQLITE ───────────────────────────────────────────────────────────────────
  //
  // SQLite cannot store nested maps/lists natively, so `vitals` and `diagnoses`
  // are JSON-encoded TEXT columns.  Schema must declare them as TEXT.

  factory EncounterModel.fromSqlite(Map<String, dynamic> row) {
    // Decode vitals JSON blob (may arrive as String or already-decoded Map)
    Map<String, dynamic>? vitalsMap;
    if (row['vitals'] != null) {
      final raw = row['vitals'];
      vitalsMap = raw is String
          ? Map<String, dynamic>.from(json.decode(raw) as Map)
          : Map<String, dynamic>.from(raw as Map);
    }

    // Decode diagnoses JSON blob
    final diagnosesRaw = row['diagnoses'];
    List<dynamic> diagnosesList = [];
    if (diagnosesRaw != null) {
      diagnosesList = diagnosesRaw is String
          ? List<dynamic>.from(json.decode(diagnosesRaw) as List)
          : List<dynamic>.from(diagnosesRaw as List);
    }

    return EncounterModel(
      id:            row['id'] as String,
      patientId:     row['patient_id'] as String,
      patientName:   row['patient_name'] as String,
      patientNupi:   row['patient_nupi'] as String,
      facilityId:    row['facility_id'] as String,
      facilityName:  row['facility_name'] as String,
      clinicianId:   row['clinician_id'] as String,
      clinicianName: row['clinician_name'] as String,
      type: EncounterType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => EncounterType.outpatient,
      ),
      status: EncounterStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => EncounterStatus.finished,
      ),
      vitals: vitalsMap != null ? VitalsModel.fromMap(vitalsMap) : null,
      chiefComplaint:             row['chief_complaint'] as String?,
      historyOfPresentingIllness: row['history'] as String?,
      examinationFindings:        row['examination'] as String?,
      diagnoses: diagnosesList
          .map((d) => DiagnosisModel.fromMap(
                Map<String, dynamic>.from(d as Map),
              ))
          .toList(),
      treatmentPlan: row['treatment_plan'] as String?,
      clinicalNotes: row['clinical_notes'] as String?,
      disposition: row['disposition'] != null
          ? Disposition.values.firstWhere(
              (e) => e.name == row['disposition'],
              orElse: () => Disposition.discharged,
            )
          : null,
      referralId:    row['referral_id'] as String?,
      encounterDate: DateTime.parse(row['encounter_date'] as String),
      createdAt:     DateTime.parse(row['created_at'] as String),
      updatedAt:     DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id':            id,
      'patient_id':    patientId,
      'patient_name':  patientName,
      'patient_nupi':  patientNupi,
      'facility_id':   facilityId,
      'facility_name': facilityName,
      'clinician_id':  clinicianId,
      'clinician_name': clinicianName,
      'type':   type.name,
      'status': status.name,

      // JSON-encode nested objects for TEXT storage
      'vitals': vitals == null
          ? null
          : json.encode(VitalsModel(
              systolicBP:       vitals!.systolicBP,
              diastolicBP:      vitals!.diastolicBP,
              temperature:      vitals!.temperature,
              weight:           vitals!.weight,
              height:           vitals!.height,
              oxygenSaturation: vitals!.oxygenSaturation,
              pulseRate:        vitals!.pulseRate,
              respiratoryRate:  vitals!.respiratoryRate,
              bloodGlucose:     vitals!.bloodGlucose,
              muac:             vitals!.muac,
            ).toMap()),

      'chief_complaint':               chiefComplaint,
      'history':     historyOfPresentingIllness,
      'examination': examinationFindings,

      'diagnoses': json.encode(diagnoses
          .map((d) => DiagnosisModel(
                code:        d.code,
                description: d.description,
                isPrimary:   d.isPrimary,
              ).toMap())
          .toList()),

      'treatment_plan': treatmentPlan,
      'clinical_notes': clinicalNotes,
      'disposition':    disposition?.name,
      'referral_id':    referralId,

      // ISO-8601 strings — no Firestore Timestamp dependency
      'encounter_date': encounterDate.toIso8601String(),
      'created_at':     createdAt.toIso8601String(),
      'updated_at':     updatedAt.toIso8601String(),
    };
  }

  // ── ENTITY ───────────────────────────────────────────────────────────────────

  factory EncounterModel.fromEntity(Encounter e) {
    return EncounterModel(
      id:            e.id,
      patientId:     e.patientId,
      patientName:   e.patientName,
      patientNupi:   e.patientNupi,
      facilityId:    e.facilityId,
      facilityName:  e.facilityName,
      clinicianId:   e.clinicianId,
      clinicianName: e.clinicianName,
      type:   e.type,
      status: e.status,

      // ✅ Always convert Vitals → VitalsModel
      vitals: e.vitals == null
          ? null
          : VitalsModel(
              systolicBP:       e.vitals!.systolicBP,
              diastolicBP:      e.vitals!.diastolicBP,
              temperature:      e.vitals!.temperature,
              weight:           e.vitals!.weight,
              height:           e.vitals!.height,
              oxygenSaturation: e.vitals!.oxygenSaturation,
              pulseRate:        e.vitals!.pulseRate,
              respiratoryRate:  e.vitals!.respiratoryRate,
              bloodGlucose:     e.vitals!.bloodGlucose,
              muac:             e.vitals!.muac,
            ),

      chiefComplaint:             e.chiefComplaint,
      historyOfPresentingIllness: e.historyOfPresentingIllness,
      examinationFindings:        e.examinationFindings,

      // ✅ Always convert Diagnosis → DiagnosisModel
      diagnoses: e.diagnoses
          .map((d) => DiagnosisModel(
                code:        d.code,
                description: d.description,
                isPrimary:   d.isPrimary,
              ))
          .toList(),

      treatmentPlan: e.treatmentPlan,
      clinicalNotes: e.clinicalNotes,
      disposition:   e.disposition,
      referralId:    e.referralId,
      encounterDate: e.encounterDate,
      createdAt:     e.createdAt,
      updatedAt:     e.updatedAt,
    );
  }
}