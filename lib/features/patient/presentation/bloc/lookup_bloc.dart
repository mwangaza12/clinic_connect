import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/patient_lookup_datasource.dart';
import 'lookup_event.dart';
import 'lookup_state.dart';

class LookupBloc extends Bloc<LookupEvent, LookupState> {
  final PatientLookupDatasource datasource;

  LookupBloc({required this.datasource})
      : super(LookupInitial()) {
    on<LookupPatientEvent>(_onLookup);
    on<FetchPatientSummaryEvent>(_onFetchSummary);
    on<ClearLookupEvent>(
        (_, emit) => emit(LookupInitial()));
  }

  Future<void> _onLookup(
      LookupPatientEvent event,
      Emitter<LookupState> emit) async {
    emit(LookupLoading());
    try {
      final result = await datasource.lookupByNupi(
        event.nupi,
        event.currentFacilityId,
      );

      if (result == null) {
        emit(LookupNotFound());
        return;
      }

      // Auto-fetch summary
      final summary =
          await datasource.getPatientSummary(
        event.nupi,
        result.facilityId,
      );

      emit(LookupFound(
          result: result, summary: summary));
    } catch (e) {
      emit(LookupError(e.toString()));
    }
  }

  Future<void> _onFetchSummary(
      FetchPatientSummaryEvent event,
      Emitter<LookupState> emit) async {
    try {
      final summary =
          await datasource.getPatientSummary(
        event.nupi,
        event.facilityId,
      );

      if (state is LookupFound) {
        final current = state as LookupFound;
        emit(LookupFound(
          result: current.result,
          summary: summary,
        ));
      }
    } catch (e) {
      emit(LookupError(e.toString()));
    }
  }
}