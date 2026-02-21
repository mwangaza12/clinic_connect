// lib/features/disease_program/presentation/bloc/program_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/enroll_patient.dart';
import '../../domain/usecases/get_facility_enrollments.dart';
import '../../domain/repositories/program_repository.dart';
import 'program_event.dart';
import 'program_state.dart';

class ProgramBloc extends Bloc<ProgramEvent, ProgramState> {
  final EnrollPatient enrollPatient;
  final GetFacilityEnrollments getFacilityEnrollments;
  final ProgramRepository repository;

  ProgramBloc({
    required this.enrollPatient,
    required this.getFacilityEnrollments,
    required this.repository,
  }) : super(ProgramInitial()) {
    on<EnrollPatientInProgram>(_onEnrollPatient);
    on<LoadFacilityEnrollments>(_onLoadFacilityEnrollments);
    on<LoadPatientEnrollments>(_onLoadPatientEnrollments);
    on<LoadProgramStats>(_onLoadProgramStats);
    on<UpdateEnrollmentStatus>(_onUpdateStatus);
  }

  Future<void> _onEnrollPatient(
    EnrollPatientInProgram event,
    Emitter<ProgramState> emit,
  ) async {
    emit(ProgramLoading());

    final result = await enrollPatient(event.enrollment as EnrollPatientParams);

    result.fold(
      (failure) => emit(const ProgramError('Failed to enroll patient')),
      (_) => emit(const EnrollmentSuccess('Patient enrolled successfully')),
    );
  }

  Future<void> _onLoadFacilityEnrollments(
    LoadFacilityEnrollments event,
    Emitter<ProgramState> emit,
  ) async {
    emit(ProgramLoading());

    final result = await getFacilityEnrollments(event.facilityId as GetFacilityEnrollmentsParams);

    result.fold(
      (failure) => emit(const ProgramError('Failed to load enrollments')),
      (enrollments) => emit(EnrollmentsLoaded(enrollments)),
    );
  }

  Future<void> _onLoadPatientEnrollments(
    LoadPatientEnrollments event,
    Emitter<ProgramState> emit,
  ) async {
    emit(ProgramLoading());

    final result = await repository.getPatientEnrollments(event.patientNupi);

    result.fold(
      (failure) => emit(const ProgramError('Failed to load patient enrollments')),
      (enrollments) => emit(EnrollmentsLoaded(enrollments)),
    );
  }

  Future<void> _onLoadProgramStats(
    LoadProgramStats event,
    Emitter<ProgramState> emit,
  ) async {
    emit(ProgramLoading());

    final result = await repository.getProgramStats(event.facilityId);

    result.fold(
      (failure) => emit(const ProgramError('Failed to load statistics')),
      (stats) => emit(ProgramStatsLoaded(stats as Map<String, int>)),
    );
  }

  Future<void> _onUpdateStatus(
    UpdateEnrollmentStatus event,
    Emitter<ProgramState> emit,
  ) async {
    emit(ProgramLoading());

    final result = await repository.updateEnrollmentStatus(
      event.enrollmentId,
      event.status,
      event.notes,
    );

    result.fold(
      (failure) => emit(const ProgramError('Failed to update status')),
      (_) => emit(const StatusUpdateSuccess('Status updated successfully')),
    );
  }
}