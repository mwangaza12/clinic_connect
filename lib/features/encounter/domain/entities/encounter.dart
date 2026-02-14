import 'package:equatable/equatable.dart';

enum EncounterType { outpatient, inpatient, emergency, referral }

enum EncounterStatus { planned, inProgress, finished, cancelled }

enum Disposition { discharged, admitted, referred, deceased, absconded }

class Vitals extends Equatable {
  final double? systolicBP;
  final double? diastolicBP;
  final double? temperature;
  final double? weight;
  final double? height;
  final double? oxygenSaturation;
  final int? pulseRate;
  final int? respiratoryRate;
  final double? bloodGlucose;
  final int? muac; // Mid-Upper Arm Circumference for children

  const Vitals({
    this.systolicBP,
    this.diastolicBP,
    this.temperature,
    this.weight,
    this.height,
    this.oxygenSaturation,
    this.pulseRate,
    this.respiratoryRate,
    this.bloodGlucose,
    this.muac,
  });

  double? get bmi {
    if (weight == null || height == null || height == 0) return null;
    final heightM = height! / 100;
    return weight! / (heightM * heightM);
  }

  String? get bpDisplay {
    if (systolicBP == null || diastolicBP == null) return null;
    return '${systolicBP!.toInt()}/${diastolicBP!.toInt()} mmHg';
  }

  @override
  List<Object?> get props => [
        systolicBP, diastolicBP, temperature, weight,
        height, oxygenSaturation, pulseRate, respiratoryRate,
        bloodGlucose, muac,
      ];
}

class Diagnosis extends Equatable {
  final String code;        // ICD-10 code e.g. "A01.0"
  final String description; // e.g. "Typhoid fever"
  final bool isPrimary;

  const Diagnosis({
    required this.code,
    required this.description,
    required this.isPrimary,
  });

  @override
  List<Object> get props => [code, description, isPrimary];
}

class Encounter extends Equatable {
  final String id;
  final String patientId;
  final String patientName;
  final String patientNupi;
  final String facilityId;
  final String facilityName;
  final String clinicianId;
  final String clinicianName;
  final EncounterType type;
  final EncounterStatus status;

  // Triage (Nurse)
  final Vitals? vitals;
  final String? chiefComplaint;

  // Consultation (Clinician)
  final String? historyOfPresentingIllness;
  final String? examinationFindings;
  final List<Diagnosis> diagnoses;
  final String? treatmentPlan;
  final String? clinicalNotes;

  // Disposition
  final Disposition? disposition;
  final String? referralId; // if referred

  final DateTime encounterDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Encounter({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientNupi,
    required this.facilityId,
    required this.facilityName,
    required this.clinicianId,
    required this.clinicianName,
    required this.type,
    required this.status,
    this.vitals,
    this.chiefComplaint,
    this.historyOfPresentingIllness,
    this.examinationFindings,
    required this.diagnoses,
    this.treatmentPlan,
    this.clinicalNotes,
    this.disposition,
    this.referralId,
    required this.encounterDate,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id, patientId, patientName, patientNupi, facilityId,
        facilityName, clinicianId, clinicianName, type, status,
        vitals, chiefComplaint, historyOfPresentingIllness,
        examinationFindings, diagnoses, treatmentPlan, clinicalNotes,
        disposition, referralId, encounterDate, createdAt, updatedAt,
      ];
}