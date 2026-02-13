// lib/features/referral/data/models/referral_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/referral.dart';

class ReferralModel extends Referral {
  const ReferralModel({
    required super.id,
    required super.patientNupi,
    required super.patientName,
    required super.fromFacilityId,
    required super.fromFacilityName,
    required super.toFacilityId,
    required super.toFacilityName,
    required super.reason,
    required super.priority,
    required super.status,
    super.clinicalNotes,
    super.feedbackNotes,
    required super.createdAt,
    super.updatedAt,
    super.acceptedAt,
    super.completedAt,
    super.rejectedAt,
    required super.createdBy,
    required super.createdByName,
  });

  // ─────────────────────────────────────────
  // FROM FIRESTORE
  // ─────────────────────────────────────────
  factory ReferralModel.fromFirestore(Map<String, dynamic> map) {
    return ReferralModel(
      id: map['id'] ?? map['referral_id'] ?? '',
      patientNupi: map['patient_nupi'] ?? '',
      patientName: map['patient_name'] ?? '',
      fromFacilityId: map['from_facility_id'] ?? '',
      fromFacilityName: map['from_facility_name'] ?? '',
      toFacilityId: map['to_facility_id'] ?? '',
      toFacilityName: map['to_facility_name'] ?? '',
      reason: map['reason'] ?? '',
      priority: _priorityFromString(map['priority']),
      status: _statusFromString(map['status']),
      clinicalNotes: map['clinical_notes'],
      feedbackNotes: map['feedback_notes'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate(),
      acceptedAt: (map['accepted_at'] as Timestamp?)?.toDate(),
      completedAt: (map['completed_at'] as Timestamp?)?.toDate(),
      rejectedAt: (map['rejected_at'] as Timestamp?)?.toDate(),
      createdBy: map['created_by'] ?? '',
      createdByName: map['created_by_name'] ?? '',
    );
  }

  // ─────────────────────────────────────────
  // FROM NOTIFICATION (minimal data)
  // ─────────────────────────────────────────
  factory ReferralModel.fromNotification(Map<String, dynamic> map) {
    return ReferralModel(
      id: map['referral_id'] ?? '',
      patientNupi: map['patient_nupi'] ?? '',
      patientName: map['patient_name'] ?? '',
      fromFacilityId: map['from_facility_id'] ?? '',
      fromFacilityName: map['from_facility_name'] ?? '',
      toFacilityId: map['to_facility_id'] ?? '',
      toFacilityName: map['to_facility_name'] ?? '',
      reason: map['reason'] ?? '',
      priority: _priorityFromString(map['priority']),
      status: _statusFromString(map['status']),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate(),
      createdBy: map['created_by'] ?? '',
      createdByName: map['created_by_name'] ?? '',
    );
  }

  // ─────────────────────────────────────────
  // FROM JSON (for API)
  // ─────────────────────────────────────────
  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: json['id'] ?? '',
      patientNupi: json['patient_nupi'] ?? '',
      patientName: json['patient_name'] ?? '',
      fromFacilityId: json['from_facility_id'] ?? '',
      fromFacilityName: json['from_facility_name'] ?? '',
      toFacilityId: json['to_facility_id'] ?? '',
      toFacilityName: json['to_facility_name'] ?? '',
      reason: json['reason'] ?? '',
      priority: _priorityFromString(json['priority']),
      status: _statusFromString(json['status']),
      clinicalNotes: json['clinical_notes'],
      feedbackNotes: json['feedback_notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      rejectedAt: json['rejected_at'] != null ? DateTime.parse(json['rejected_at']) : null,
      createdBy: json['created_by'] ?? '',
      createdByName: json['created_by_name'] ?? '',
    );
  }

  // ─────────────────────────────────────────
  // TO FIRESTORE
  // ─────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'referral_id': id,
      'patient_nupi': patientNupi,
      'patient_name': patientName,
      'from_facility_id': fromFacilityId,
      'from_facility_name': fromFacilityName,
      'to_facility_id': toFacilityId,
      'to_facility_name': toFacilityName,
      'reason': reason,
      'priority': priority.name,
      'status': status.name,
      'clinical_notes': clinicalNotes,
      'feedback_notes': feedbackNotes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'accepted_at': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'rejected_at': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'created_by': createdBy,
      'created_by_name': createdByName,
    };
  }

  // ─────────────────────────────────────────
  // TO JSON
  // ─────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_nupi': patientNupi,
      'patient_name': patientName,
      'from_facility_id': fromFacilityId,
      'from_facility_name': fromFacilityName,
      'to_facility_id': toFacilityId,
      'to_facility_name': toFacilityName,
      'reason': reason,
      'priority': priority.name,
      'status': status.name,
      'clinical_notes': clinicalNotes,
      'feedback_notes': feedbackNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_by_name': createdByName,
    };
  }

  // ─────────────────────────────────────────
  // FROM ENTITY
  // ─────────────────────────────────────────
  factory ReferralModel.fromEntity(Referral entity) {
    return ReferralModel(
      id: entity.id,
      patientNupi: entity.patientNupi,
      patientName: entity.patientName,
      fromFacilityId: entity.fromFacilityId,
      fromFacilityName: entity.fromFacilityName,
      toFacilityId: entity.toFacilityId,
      toFacilityName: entity.toFacilityName,
      reason: entity.reason,
      priority: entity.priority,
      status: entity.status,
      clinicalNotes: entity.clinicalNotes,
      feedbackNotes: entity.feedbackNotes,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      acceptedAt: entity.acceptedAt,
      completedAt: entity.completedAt,
      rejectedAt: entity.rejectedAt,
      createdBy: entity.createdBy,
      createdByName: entity.createdByName,
    );
  }

  // ─────────────────────────────────────────
  // TO ENTITY
  // ─────────────────────────────────────────
  Referral toEntity() {
    return Referral(
      id: id,
      patientNupi: patientNupi,
      patientName: patientName,
      fromFacilityId: fromFacilityId,
      fromFacilityName: fromFacilityName,
      toFacilityId: toFacilityId,
      toFacilityName: toFacilityName,
      reason: reason,
      priority: priority,
      status: status,
      clinicalNotes: clinicalNotes,
      feedbackNotes: feedbackNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      acceptedAt: acceptedAt,
      completedAt: completedAt,
      rejectedAt: rejectedAt,
      createdBy: createdBy,
      createdByName: createdByName,
    );
  }

  // ─────────────────────────────────────────
  // COPY WITH
  // ─────────────────────────────────────────
  @override
  ReferralModel copyWith({
    String? id,
    String? patientNupi,
    String? patientName,
    String? fromFacilityId,
    String? fromFacilityName,
    String? toFacilityId,
    String? toFacilityName,
    String? reason,
    ReferralPriority? priority,
    ReferralStatus? status,
    String? clinicalNotes,
    String? feedbackNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? rejectedAt,
    String? createdBy,
    String? createdByName,
  }) {
    return ReferralModel(
      id: id ?? this.id,
      patientNupi: patientNupi ?? this.patientNupi,
      patientName: patientName ?? this.patientName,
      fromFacilityId: fromFacilityId ?? this.fromFacilityId,
      fromFacilityName: fromFacilityName ?? this.fromFacilityName,
      toFacilityId: toFacilityId ?? this.toFacilityId,
      toFacilityName: toFacilityName ?? this.toFacilityName,
      reason: reason ?? this.reason,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      feedbackNotes: feedbackNotes ?? this.feedbackNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
    );
  }

  // ─────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────
  static ReferralPriority _priorityFromString(String? priority) {
    switch (priority) {
      case 'emergency':
        return ReferralPriority.emergency;
      case 'urgent':
        return ReferralPriority.urgent;
      case 'normal':
        return ReferralPriority.normal;
      default:
        return ReferralPriority.normal;
    }
  }

  static ReferralStatus _statusFromString(String? status) {
    switch (status) {
      case 'pending':
        return ReferralStatus.pending;
      case 'accepted':
        return ReferralStatus.accepted;
      case 'rejected':
        return ReferralStatus.rejected;
      case 'completed':
        return ReferralStatus.completed;
      default:
        return ReferralStatus.pending;
    }
  }
}