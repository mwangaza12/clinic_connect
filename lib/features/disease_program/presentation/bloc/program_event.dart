// lib/features/disease_program/presentation/bloc/program_event.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/disease_program.dart';

abstract class ProgramEvent extends Equatable {
  const ProgramEvent();

  @override
  List<Object?> get props => [];
}

class EnrollPatientInProgram extends ProgramEvent {
  final ProgramEnrollment enrollment;

  const EnrollPatientInProgram(this.enrollment);

  @override
  List<Object?> get props => [enrollment];
}

class LoadFacilityEnrollments extends ProgramEvent {
  final String facilityId;

  const LoadFacilityEnrollments(this.facilityId);

  @override
  List<Object?> get props => [facilityId];
}

class LoadPatientEnrollments extends ProgramEvent {
  final String patientNupi;

  const LoadPatientEnrollments(this.patientNupi);

  @override
  List<Object?> get props => [patientNupi];
}

class LoadProgramStats extends ProgramEvent {
  final String facilityId;

  const LoadProgramStats(this.facilityId);

  @override
  List<Object?> get props => [facilityId];
}

class UpdateEnrollmentStatus extends ProgramEvent {
  final String enrollmentId;
  final ProgramEnrollmentStatus status;
  final String? notes;

  const UpdateEnrollmentStatus({
    required this.enrollmentId,
    required this.status,
    this.notes,
  });

  @override
  List<Object?> get props => [enrollmentId, status, notes];
}