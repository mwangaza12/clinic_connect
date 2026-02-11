import 'package:equatable/equatable.dart';
import '../../domain/entities/patient.dart';

abstract class PatientState extends Equatable {
  const PatientState();

  @override
  List<Object?> get props => [];
}

class PatientInitial extends PatientState {}

class PatientLoading extends PatientState {}

class PatientRegistered extends PatientState {
  final Patient patient;

  const PatientRegistered(this.patient);

  @override
  List<Object> get props => [patient];
}

class PatientLoaded extends PatientState {
  final Patient patient;

  const PatientLoaded(this.patient);

  @override
  List<Object> get props => [patient];
}

class PatientsLoaded extends PatientState {
  final List<Patient> patients;

  const PatientsLoaded(this.patients);

  @override
  List<Object> get props => [patients];
}

class PatientError extends PatientState {
  final String message;

  const PatientError(this.message);

  @override
  List<Object> get props => [message];
}