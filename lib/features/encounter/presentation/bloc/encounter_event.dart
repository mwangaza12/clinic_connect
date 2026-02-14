import 'package:equatable/equatable.dart';
import '../../domain/entities/encounter.dart';

abstract class EncounterEvent extends Equatable {
  const EncounterEvent();
  @override
  List<Object?> get props => [];
}

class LoadPatientEncountersEvent extends EncounterEvent {
  final String patientId;
  const LoadPatientEncountersEvent(this.patientId);
  @override
  List<Object> get props => [patientId];
}

class CreateEncounterEvent extends EncounterEvent {
  final Encounter encounter;
  const CreateEncounterEvent(this.encounter);
  @override
  List<Object> get props => [encounter];
}

class UpdateEncounterEvent extends EncounterEvent {
  final Encounter encounter;
  const UpdateEncounterEvent(this.encounter);
  @override
  List<Object> get props => [encounter];
}