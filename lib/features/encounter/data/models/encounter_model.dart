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
    return EncounterModel(
      id:            json['id'] ?? '',
      patientId:     json['patient_id'] ?? '',
      patientName:   json['patient_name'] ?? '',
      patientNupi:   json['patient_nupi'] ?? '',
      facilityId:    json['facility_id'] ?? '',
      facilityName:  json['facility_name'] ?? '',
      clinicianId:   json['clinician_id'] ?? '',
      clinicianName: json['clinician_name'] ?? '',
      type: EncounterType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EncounterType.outpatient,
      ),
      status: EncounterStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EncounterStatus.finished,
      ),
      vitals: json['vitals'] != null
          ? VitalsModel.fromMap(Map<String, dynamic>.from(json['vitals']))
          : null,
      chiefComplaint:             json['chief_complaint'],
      historyOfPresentingIllness: json['history_of_presenting_illness'],
      examinationFindings:        json['examination_findings'],
      diagnoses: (json['diagnoses'] as List<dynamic>? ?? [])
          .map((d) => DiagnosisModel.fromMap(Map<String, dynamic>.from(d)))
          .toList(),
      treatmentPlan: json['treatment_plan'],
      clinicalNotes: json['clinical_notes'],
      disposition: json['disposition'] != null
          ? Disposition.values.firstWhere(
              (e) => e.name == json['disposition'],
              orElse: () => Disposition.discharged,
            )
          : null,
      referralId:    json['referral_id'],
      encounterDate: (json['encounter_date'] as Timestamp).toDate(),
      createdAt:     (json['created_at'] as Timestamp).toDate(),
      updatedAt:     (json['updated_at'] as Timestamp).toDate(),
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