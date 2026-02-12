import 'package:equatable/equatable.dart';
import '../../domain/entities/patient.dart';

abstract class PatientEvent extends Equatable {
  const PatientEvent();

  @override
  List<Object> get props => [];
}

class LoadPatientsEvent extends PatientEvent {
  const LoadPatientsEvent();
}

class RegisterPatientEvent extends PatientEvent {
  final Patient patient;
  const RegisterPatientEvent(this.patient);

  @override
  List<Object> get props => [patient];
}

class SearchPatientEvent extends PatientEvent {
  final String query;
  const SearchPatientEvent(this.query);

  @override
  List<Object> get props => [query];
}

class GetPatientEvent extends PatientEvent {
  final String patientId;
  const GetPatientEvent(this.patientId);

  @override
  List<Object> get props => [patientId];
}