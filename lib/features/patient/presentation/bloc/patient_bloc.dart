import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_all_patients_by_facility.dart';
import '../../domain/usecases/register_patient.dart';
import '../../domain/usecases/search_patient.dart';
import '../../domain/usecases/get_all_patients.dart';
import 'patient_event.dart';
import 'patient_state.dart';

class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final RegisterPatient registerPatientUsecase;
  final SearchPatient searchPatientUsecase;
  final GetAllPatients getAllPatientsUsecase;
  final GetAllPatientsByFacility getAllPatientsByFacilityUsecase;

  PatientBloc({
    required this.registerPatientUsecase,
    required this.searchPatientUsecase,
    required this.getAllPatientsUsecase,
    required this.getAllPatientsByFacilityUsecase,
  }) : super(PatientInitial()) {
    on<LoadPatientsEvent>(_onLoadPatients);
    on<RegisterPatientEvent>(_onRegisterPatient);
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

  Future<void> _onSearchPatient(
    SearchPatientEvent event,
    Emitter<PatientState> emit,
  ) async {
    emit(PatientLoading());
    final result = await searchPatientUsecase(event.query as SearchParams);
    result.fold(
      (failure) => emit(PatientError(failure.message)),
      (patients) => emit(PatientsLoaded(patients)),
    );
  }
}
