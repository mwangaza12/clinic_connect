import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/create_encounter.dart';
import '../../domain/usecases/get_patient_encounters.dart';
import 'encounter_event.dart';
import 'encounter_state.dart';
import '../../domain/repositories/encounter_repository.dart';

class EncounterBloc extends Bloc<EncounterEvent, EncounterState> {
  final CreateEncounter createEncounterUsecase;
  final GetPatientEncounters getPatientEncountersUsecase;
  final EncounterRepository repository;

  EncounterBloc({
    required this.createEncounterUsecase,
    required this.getPatientEncountersUsecase,
    required this.repository,
  }) : super(EncounterInitial()) {
    on<LoadPatientEncountersEvent>(_onLoad);
    on<CreateEncounterEvent>(_onCreate);
    on<UpdateEncounterEvent>(_onUpdate);
  }

  Future<void> _onLoad(
      LoadPatientEncountersEvent event, Emitter<EncounterState> emit) async {
    emit(EncounterLoading());
    final result =
        await getPatientEncountersUsecase(event.patientId);
    result.fold(
      (f) => emit(EncounterError(f.message)),
      (encounters) => emit(EncountersLoaded(encounters)),
    );
  }

  Future<void> _onCreate(
      CreateEncounterEvent event, Emitter<EncounterState> emit) async {
    emit(EncounterLoading());
    final result = await createEncounterUsecase(event.encounter);
    result.fold(
      (f) => emit(EncounterError(f.message)),
      (encounter) => emit(EncounterCreated(encounter)),
    );
  }

  Future<void> _onUpdate(
      UpdateEncounterEvent event, Emitter<EncounterState> emit) async {
    emit(EncounterLoading());
    final result = await repository.updateEncounter(event.encounter);
    result.fold(
      (f) => emit(EncounterError(f.message)),
      (encounter) => emit(EncounterUpdated(encounter)),
    );
  }
}