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

    // BUG FIX: was casting event.enrollment directly as EnrollPatientParams
    // (ProgramEnrollment is not EnrollPatientParams — this threw a cast error).
    // Correct: wrap the entity in the params object the use-case expects.
    final result = await enrollPatient(
      EnrollPatientParams(enrollment: event.enrollment),
    );

    result.fold(
      (failure) => emit(ProgramError(failure.message)),
      (_) => emit(const EnrollmentSuccess('Patient enrolled successfully')),
    );
  }

  Future<void> _onLoadFacilityEnrollments(
    LoadFacilityEnrollments event,
    Emitter<ProgramState> emit,
  ) async {
    emit(ProgramLoading());

    // BUG FIX: was casting event.facilityId (a String) as GetFacilityEnrollmentsParams
    // — runtime cast error. Correct: wrap in params object.
    final result = await getFacilityEnrollments(
      GetFacilityEnrollmentsParams(facilityId: event.facilityId),
    );

    result.fold(
      (failure) => emit(ProgramError(failure.message)),
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
      (failure) => emit(ProgramError(failure.message)),
      (enrollments) => emit(EnrollmentsLoaded(enrollments)),
    );
  }

  Future<void> _onLoadProgramStats(
    LoadProgramStats event,
    Emitter<ProgramState> emit,
  ) async {
    emit(ProgramLoading());

    // BUG FIX: getProgramStats returns Either<Failure, ProgramStatistics>.
    // The old code tried to cast ProgramStatistics as Map<String, int> — crash.
    // Correct: emit ProgramStatsLoaded with the actual ProgramStatistics object,
    // and update ProgramStatsLoaded state to hold ProgramStatistics (see state file).
    final result = await repository.getProgramStats(event.facilityId);

    result.fold(
      (failure) => emit(ProgramError(failure.message)),
      (stats) => emit(ProgramStatsLoaded(stats)),
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
      (failure) => emit(ProgramError(failure.message)),
      (_) => emit(const StatusUpdateSuccess('Status updated successfully')),
    );
  }
}