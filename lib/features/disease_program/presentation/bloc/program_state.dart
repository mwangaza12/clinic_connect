// lib/features/disease_program/presentation/bloc/program_state.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/disease_program.dart';

abstract class ProgramState extends Equatable {
  const ProgramState();

  @override
  List<Object?> get props => [];
}

class ProgramInitial extends ProgramState {}

class ProgramLoading extends ProgramState {}

class EnrollmentSuccess extends ProgramState {
  final String message;

  const EnrollmentSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class EnrollmentsLoaded extends ProgramState {
  final List<ProgramEnrollment> enrollments;

  const EnrollmentsLoaded(this.enrollments);

  @override
  List<Object?> get props => [enrollments];
}

class ProgramStatsLoaded extends ProgramState {
  final Map<String, int> stats;

  const ProgramStatsLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

class StatusUpdateSuccess extends ProgramState {
  final String message;

  const StatusUpdateSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ProgramError extends ProgramState {
  final String message;

  const ProgramError(this.message);

  @override
  List<Object?> get props => [message];
}