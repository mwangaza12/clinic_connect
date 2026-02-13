// lib/features/referral/domain/entities/referral.dart

enum ReferralPriority { normal, urgent, emergency }
enum ReferralStatus { pending, accepted, rejected, completed }

class Referral {
  final String id;
  final String patientNupi;
  final String patientName;
  final String fromFacilityId;
  final String fromFacilityName;
  final String toFacilityId;
  final String toFacilityName;
  final String reason;
  final ReferralPriority priority;
  final ReferralStatus status;
  final String? clinicalNotes;
  final String? feedbackNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? rejectedAt;
  final String createdBy;
  final String createdByName;

  const Referral({
    required this.id,
    required this.patientNupi,
    required this.patientName,
    required this.fromFacilityId,
    required this.fromFacilityName,
    required this.toFacilityId,
    required this.toFacilityName,
    required this.reason,
    required this.priority,
    required this.status,
    this.clinicalNotes,
    this.feedbackNotes,
    required this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.completedAt,
    this.rejectedAt,
    required this.createdBy,
    required this.createdByName,
  });

  Referral copyWith({
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
    return Referral(
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
}