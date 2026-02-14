import 'package:equatable/equatable.dart';
import '../../domain/entities/encounter.dart';

abstract class EncounterState extends Equatable {
  const EncounterState();
  @override
  List<Object?> get props => [];
}

class EncounterInitial extends EncounterState {}

class EncounterLoading extends EncounterState {}

class EncountersLoaded extends EncounterState {
  final List<Encounter> encounters;
  const EncountersLoaded(this.encounters);
  @override
  List<Object> get props => [encounters];
}

class EncounterCreated extends EncounterState {
  final Encounter encounter;
  const EncounterCreated(this.encounter);
  @override
  List<Object> get props => [encounter];
}

class EncounterUpdated extends EncounterState {
  final Encounter encounter;
  const EncounterUpdated(this.encounter);
  @override
  List<Object> get props => [encounter];
}

class EncounterError extends EncounterState {
  final String message;
  const EncounterError(this.message);
  @override
  List<Object> get props => [message];
}