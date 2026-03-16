import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/usecases/get_all_patients_by_facility.dart';
import '../../domain/usecases/register_patient.dart';
import '../../domain/usecases/update_patient.dart';
import '../../domain/usecases/search_patient.dart';
import '../../domain/usecases/get_all_patients.dart';
import 'patient_event.dart';
import 'patient_state.dart';

class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final RegisterPatient registerPatientUsecase;
  final UpdatePatient updatePatientUsecase;
  final SearchPatient searchPatientUsecase;
  final GetAllPatients getAllPatientsUsecase;
  final GetAllPatientsByFacility getAllPatientsByFacilityUsecase;
  final AuthBloc? authBloc; // Make it nullable

  PatientBloc({
    required this.registerPatientUsecase,
    required this.updatePatientUsecase,
    required this.searchPatientUsecase,
    required this.getAllPatientsUsecase,
    required this.getAllPatientsByFacilityUsecase,
    this.authBloc, // Make it optional
  }) : super(PatientInitial()) {
    on<LoadPatientsEvent>(_onLoadPatients);
    on<RegisterPatientEvent>(_onRegisterPatient);
    on<UpdatePatientEvent>(_onUpdatePatient);
    on<SearchPatientEvent>(_onSearchPatient);
    on<LoadPatientsByFacilityEvent>(_onLoadPatientsByFacility);
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
    String? facilityId;
    
    // Safely access authBloc
    if (authBloc != null) {
      final authState = authBloc!.state;
      if (authState is Authenticated) {
        facilityId = authState.user.facilityId;
      }
    }

    // Create proper search params
    final params = SearchParams(
      query: event.query,
      searchType: _determineSearchType(event.query),
      facilityId: facilityId,
      page: 1,
      limit: 50,
    );

    final result = await searchPatientUsecase(params);
    
    result.fold(
      (failure) => emit(PatientError(failure.message)),
      (patients) => emit(PatientsLoaded(patients)),
    );
  }

  SearchType _determineSearchType(String query) {
    // If query looks like a NUPI (alphanumeric with possible hyphens)
    if (RegExp(r'^[A-Z0-9-]{5,}$').hasMatch(query.toUpperCase())) {
      return SearchType.byNupi;
    }
    // If query looks like a phone number
    else if (RegExp(r'^[0-9]{10,}$').hasMatch(query)) {
      return SearchType.byPhone;
    }
    // Default to all fields search
    return SearchType.all;
  }
}