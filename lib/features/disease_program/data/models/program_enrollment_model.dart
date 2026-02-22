// lib/features/disease_program/data/models/program_enrollment_model.dart

import 'dart:convert';
import '../../domain/entities/disease_program.dart';

class ProgramEnrollmentModel extends ProgramEnrollment {
  const ProgramEnrollmentModel({
    required super.id,
    required super.patientNupi,
    required super.patientName,
    required super.facilityId,
    required super.program,
    required super.status,
    required super.enrollmentDate,
    super.completionDate,
    super.outcomeNotes,
    super.programSpecificData,
    required super.createdAt,
    super.updatedAt,
  });

  factory ProgramEnrollmentModel.fromEntity(ProgramEnrollment enrollment) {
    return ProgramEnrollmentModel(
      id: enrollment.id,
      patientNupi: enrollment.patientNupi,
      patientName: enrollment.patientName,
      facilityId: enrollment.facilityId,
      program: enrollment.program,
      status: enrollment.status,
      enrollmentDate: enrollment.enrollmentDate,
      completionDate: enrollment.completionDate,
      outcomeNotes: enrollment.outcomeNotes,
      programSpecificData: enrollment.programSpecificData,
      createdAt: enrollment.createdAt,
      updatedAt: enrollment.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_nupi': patientNupi,
      'patient_name': patientName,
      'facility_id': facilityId,
      'program': program.name,
      'status': status.name,
      'enrollment_date': enrollmentDate.toIso8601String(),
      'completion_date': completionDate?.toIso8601String(),
      'outcome_notes': outcomeNotes,
      'program_specific_data': programSpecificData != null ? jsonEncode(programSpecificData) : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': 'pending',
    };
  }

  factory ProgramEnrollmentModel.fromMap(Map<String, dynamic> map) {
    return ProgramEnrollmentModel(
      id: map['id'],
      patientNupi: map['patient_nupi'],
      patientName: map['patient_name'],
      facilityId: map['facility_id'],
      program: DiseaseProgram.values.firstWhere((p) => p.name == map['program']),
      status: ProgramEnrollmentStatus.values.firstWhere((s) => s.name == map['status']),
      enrollmentDate: DateTime.parse(map['enrollment_date']),
      completionDate: map['completion_date'] != null ? DateTime.parse(map['completion_date']) : null,
      outcomeNotes: map['outcome_notes'],
      programSpecificData: map['program_specific_data'] != null ? jsonDecode(map['program_specific_data']) : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'patientNupi': patientNupi,
      'patientName': patientName,
      'facilityId': facilityId,
      'program': program.name,
      'status': status.name,
      'enrollmentDate': enrollmentDate,
      'completionDate': completionDate,
      'outcomeNotes': outcomeNotes,
      'programSpecificData': programSpecificData,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }

  factory ProgramEnrollmentModel.fromFirestore(Map<String, dynamic> doc) {
    return ProgramEnrollmentModel(
      id: doc['id'],
      patientNupi: doc['patientNupi'],
      patientName: doc['patientName'],
      facilityId: doc['facilityId'],
      program: DiseaseProgram.values.firstWhere((p) => p.name == doc['program']),
      status: ProgramEnrollmentStatus.values.firstWhere((s) => s.name == doc['status']),
      enrollmentDate: (doc['enrollmentDate'] as dynamic).toDate(),
      completionDate: doc['completionDate'] != null ? (doc['completionDate'] as dynamic).toDate() : null,
      outcomeNotes: doc['outcomeNotes'],
      programSpecificData: doc['programSpecificData'] != null ? Map<String, dynamic>.from(doc['programSpecificData']) : null,
      createdAt: (doc['createdAt'] as dynamic).toDate(),
      updatedAt: doc['updatedAt'] != null ? (doc['updatedAt'] as dynamic).toDate() : null,
    );
  }
}