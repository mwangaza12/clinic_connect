import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/patient_repository_impl.dart';
import '../../domain/usecases/get_all_patients_by_facility.dart';
import '../../domain/usecases/register_patient.dart';
import '../../domain/usecases/update_patient.dart';
import '../../domain/usecases/search_patient.dart';
import '../../domain/usecases/get_all_patients.dart';
import '../../domain/entities/patient.dart';
import 'patient_event.dart';
import 'patient_state.dart';

class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final RegisterPatient registerPatientUsecase;
  final UpdatePatient updatePatientUsecase;
  final SearchPatient searchPatientUsecase;
  final GetAllPatients getAllPatientsUsecase;
  final GetAllPatientsByFacility getAllPatientsByFacilityUsecase;

  final PatientRepositoryImpl? repository;

  PatientBloc({
    required this.registerPatientUsecase,
    required this.updatePatientUsecase,
    required this.searchPatientUsecase,
    required this.getAllPatientsUsecase,
    required this.getAllPatientsByFacilityUsecase,
    this.repository,
  }) : super(PatientInitial()) {
    on<LoadPatientsEvent>(_onLoadPatients);
    on<RegisterPatientEvent>(_onRegisterPatient);
    on<UpdatePatientEvent>(_onUpdatePatient);
    on<SearchPatientEvent>(_onSearchPatient);
    on<LoadPatientsByFacilityEvent>(_onLoadPatientsByFacility);
    on<_RefreshPatientsEvent>(_onRefreshPatients);

    // Wire background refresh callback so Firestore updates
    // automatically re-emit without user having to pull-to-refresh
    repository?.onPatientsRefreshed = (patients) {
      if (!isClosed) add(_RefreshPatientsEvent(patients.cast<Patient>()));
    };
  }

  Future<void> _onLoadPatients(
    LoadPatientsEvent event,
    Emitter<PatientState> emit,
  ) async {
    emit(PatientLoading());
    final result = await getAllPatientsUsecase();
    result.fold(
      (failure) => emit(PatientError(failure.message)),
      (patients) => emit(PatientsLoaded(patients)),
    );
  }

  Future<void> _onRefreshPatients(
    _RefreshPatientsEvent event,
    Emitter<PatientState> emit,
  ) async {
    // Only emit if we are currently showing patients (not loading/error)
    if (state is PatientsLoaded || state is PatientInitial) {
      emit(PatientsLoaded(event.patients));
    }
  }

  Future<void> _onLoadPatientsByFacility(
    LoadPatientsByFacilityEvent event,
    Emitter<PatientState> emit,
  ) async {
    emit(PatientLoading());
    final result = await getAllPatientsByFacilityUsecase();
    result.fold(
      (failure) => emit(PatientError(failure.message)),
      (patients) => emit(PatientsLoaded(patients)),
    );
  }

  Future<void> _onRegisterPatient(
    RegisterPatientEvent event,
    Emitter<PatientState> emit,
  ) async {
    emit(PatientLoading());
    final result = await registerPatientUsecase(event.patient);
    result.fold(
      (failure) => emit(PatientError(failure.message)),
      (patient) => emit(PatientRegistered(patient)),
    );
  }

  Future<void> _onUpdatePatient(
    UpdatePatientEvent event,
    Emitter<PatientState> emit,
  ) async {
    emit(PatientLoading());
    final result = await updatePatientUsecase(event.patient);
    result.fold(
      (failure) => emit(PatientError(failure.message)),
      (patient) => emit(PatientUpdated(patient)),
    );
  }

  Future<void> _onSearchPatient(
    SearchPatientEvent event,
    Emitter<PatientState> emit,
  ) async {
    if (event.query.trim().isEmpty) {
      // Empty search — reload the full facility list instead of hitting
      // the use case which would reject an empty query.
      final result = await getAllPatientsByFacilityUsecase();
      result.fold(
        (failure) => emit(PatientError(failure.message)),
        (patients) => emit(PatientsLoaded(patients)),
      );
      return;
    }

    emit(PatientLoading());
    final result = await searchPatientUsecase(
      SearchParams(
        query:      event.query.trim(),
        searchType: SearchType.all,
      ),
    );
    result.fold(
      (failure) => emit(PatientError(failure.message)),
      (patients) => emit(PatientsLoaded(patients)),
    );
  }
}

/// Internal event — emitted by the repository's background refresh callback.
/// Not part of the public API.
class _RefreshPatientsEvent extends PatientEvent {
  final List<Patient> patients;
  const _RefreshPatientsEvent(this.patients);
}