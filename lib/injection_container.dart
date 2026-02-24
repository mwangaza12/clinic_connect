import 'package:clinic_connect/features/facility/data/datasources/facility_remote_datasource.dart';
import 'package:clinic_connect/features/facility/data/repositories/facility_repository_impl.dart';
import 'package:clinic_connect/features/facility/domain/repositories/facility_repository.dart';
import 'package:clinic_connect/features/patient/data/datasources/patient_lookup_datasource.dart';
import 'package:clinic_connect/features/patient/domain/usecases/get_all_patients.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'core/database/database_helper.dart';
import 'core/network/network_info.dart';
import 'core/sync/sync_manager.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login.dart';
import 'features/auth/domain/usecases/logout.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/home/data/dashboard_service.dart';
import 'features/home/presentation/bloc/dashboard_bloc.dart';
import 'features/patient/data/datasources/patient_local_datasource.dart';
import 'features/patient/data/datasources/patient_remote_datasource.dart';
import 'features/patient/data/repositories/patient_repository_impl.dart';
import 'features/patient/domain/repositories/patient_repository.dart';
import 'features/patient/domain/usecases/get_all_patients_by_facility.dart';
import 'features/patient/domain/usecases/register_patient.dart';
import 'features/patient/domain/usecases/search_patient.dart';
import 'features/patient/presentation/bloc/lookup_bloc.dart';
import 'features/patient/presentation/bloc/patient_bloc.dart';
import 'features/referral/data/datasources/referral_remote_datasource.dart';
import 'features/referral/data/datasources/referral_remote_datasource_impl.dart';
import 'features/referral/data/repositories/referral_repository_impl.dart';
import 'features/referral/domain/repositories/referral_repository.dart';
import 'features/referral/domain/usecases/create_referral.dart';
import 'features/referral/domain/usecases/get_referrals.dart';
import 'features/referral/domain/usecases/update_referral_status.dart';
import 'features/referral/presentation/bloc/referral_bloc.dart';

// Facility imports
import 'features/facility/domain/usecases/get_all_facilities.dart';
import 'features/facility/domain/usecases/get_facilities_by_county.dart';
import 'features/facility/domain/usecases/get_facility.dart';
import 'features/facility/domain/usecases/search_facilities.dart';
import 'features/facility/presentation/bloc/facility_bloc.dart';

// Encounter imports
import 'features/encounter/data/datasources/encounter_remote_datasource.dart';
import 'features/encounter/data/repositories/encounter_repository_impl.dart';
import 'features/encounter/domain/repositories/encounter_repository.dart';
import 'features/encounter/domain/usecases/create_encounter.dart';
import 'features/encounter/domain/usecases/get_patient_encounters.dart';
import 'features/encounter/presentation/bloc/encounter_bloc.dart';

// ✅ Disease Program imports
import 'features/disease_program/data/datasources/program_local_datasource.dart';
import 'features/disease_program/data/datasources/program_remote_datasource.dart';
import 'features/disease_program/data/repositories/program_repository_impl.dart';
import 'features/disease_program/domain/repositories/program_repository.dart';
import 'features/disease_program/domain/usecases/enroll_patient.dart';
import 'features/disease_program/domain/usecases/get_facility_enrollments.dart';
import 'features/disease_program/presentation/bloc/program_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ==================
  // EXTERNAL DEPENDENCIES
  // ==================
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => DatabaseHelper());
  sl.registerLazySingleton(() => InternetConnectionChecker());

  // ==================
  // CORE
  // ==================
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(connectionChecker: sl()),
  );

  sl.registerLazySingleton<SyncManager>(
    () => SyncManager(),
  );

  // ==================
  // DATA SOURCES
  // ==================

  // Auth
  sl.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasourceImpl(
      firebaseAuth: sl(),
      firestore: sl(),
    ),
  );

  sl.registerLazySingleton<AuthLocalDatasource>(
    () => AuthLocalDatasourceImpl(
      secureStorage: sl(),
    ),
  );

  // ✅ FIXED: Patient remote datasource - now uses getters for facility info
  sl.registerLazySingleton<PatientRemoteDatasource>(
    () => PatientRemoteDatasourceImpl(), // No parameters needed
  );

  sl.registerLazySingleton<PatientLocalDatasource>(
    () => PatientLocalDatasourceImpl(
      dbHelper: sl(),
      syncManager: sl(),
    ),
  );

  // Referral
  sl.registerLazySingleton<ReferralRemoteDatasource>(
    () => ReferralRemoteDatasourceImpl(),
  );

  // Facility
  sl.registerLazySingleton<FacilityRemoteDatasource>(
    () => FacilityRemoteDatasourceImpl(),
  );

  // Encounter
  sl.registerLazySingleton<EncounterRemoteDatasource>(
    () => EncounterRemoteDatasourceImpl(),
  );

  // Lookup
  sl.registerLazySingleton<PatientLookupDatasource>(
    () => PatientLookupDatasourceImpl(),
  );

  // ✅ Disease Program Data Sources
  sl.registerLazySingleton<ProgramLocalDatasource>(
    () => ProgramLocalDatasourceImpl(databaseHelper: sl()),
  );

  sl.registerLazySingleton<ProgramRemoteDatasource>(
    () => ProgramRemoteDatasourceImpl(firestore: sl()),
  );

  // ==================
  // REPOSITORIES
  // ==================
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDatasource: sl(),
      localDatasource: sl(),
    ),
  );

  sl.registerLazySingleton<PatientRepository>(
    () => PatientRepositoryImpl(
      remoteDatasource: sl(),
      localDatasource: sl(),
    ),
  );

  sl.registerLazySingleton<ReferralRepository>(
    () => ReferralRepositoryImpl(
      remoteDatasource: sl(),
    ),
  );

  sl.registerLazySingleton<FacilityRepository>(
    () => FacilityRepositoryImpl(
      remoteDatasource: sl(),
    ),
  );

  sl.registerLazySingleton<EncounterRepository>(
    () => EncounterRepositoryImpl(
      remoteDatasource: sl(),
    ),
  );

  // ✅ Disease Program Repository
  sl.registerLazySingleton<ProgramRepository>(
    () => ProgramRepositoryImpl(
      localDatasource: sl(),
      remoteDatasource: sl(),
      networkInfo: sl(),
    ),
  );

  // ==================
  // USE CASES
  // ==================
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Logout(sl()));

  sl.registerLazySingleton(() => RegisterPatient(sl()));
  sl.registerLazySingleton(() => SearchPatient(sl()));
  sl.registerLazySingleton(() => GetAllPatients(sl()));
  sl.registerLazySingleton(() => GetAllPatientsByFacility(sl()));

  sl.registerLazySingleton(() => CreateReferral(sl()));
  sl.registerLazySingleton(() => GetOutgoingReferrals(sl()));
  sl.registerLazySingleton(() => GetIncomingReferrals(sl()));
  sl.registerLazySingleton(() => UpdateReferralStatus(sl()));

  sl.registerLazySingleton(() => SearchFacilities(sl()));
  sl.registerLazySingleton(() => GetFacilitiesByCounty(sl()));
  sl.registerLazySingleton(() => GetFacility(sl()));
  sl.registerLazySingleton(() => GetAllFacilities(sl()));

  sl.registerLazySingleton(() => CreateEncounter(sl()));
  sl.registerLazySingleton(() => GetPatientEncounters(sl()));

  // ✅ Disease Program Use Cases
  sl.registerLazySingleton(() => EnrollPatient(sl()));
  sl.registerLazySingleton(() => GetFacilityEnrollments(sl()));

  // ==================
  // SERVICES
  // ==================
  sl.registerLazySingleton(() => DashboardService());

  // ==================
  // BLOCS
  // ==================
  sl.registerFactory(
    () => AuthBloc(
      loginUsecase: sl(),
      logoutUsecase: sl(),
    ),
  );

  sl.registerFactory(
    () => PatientBloc(
      registerPatientUsecase: sl(),
      searchPatientUsecase: sl(),
      getAllPatientsUsecase: sl(),
      getAllPatientsByFacilityUsecase: sl(),
    ),
  );

  sl.registerFactory(
    () => ReferralBloc(
      createReferralUsecase: sl(),
      getOutgoingReferralsUsecase: sl(),
      getIncomingReferralsUsecase: sl(),
      updateReferralStatusUsecase: sl(),
    ),
  );

  sl.registerFactory<EncounterBloc>(
    () => EncounterBloc(
      createEncounterUsecase: sl(),
      getPatientEncountersUsecase: sl(),
      repository: sl(),
    ),
  );

  sl.registerFactory<DashboardBloc>(
    () => DashboardBloc(sl()),
  );

  sl.registerFactory<LookupBloc>(
    () => LookupBloc(datasource: sl()),
  );

  sl.registerFactory(
    () => FacilityBloc(
      searchFacilities: sl(),
      getFacilitiesByCounty: sl(),
      getFacility: sl(),
      getAllFacilities: sl(),
    ),
  );

  sl.registerFactory(
    () => ProgramBloc(
      enrollPatient: sl(),
      getFacilityEnrollments: sl(),
      repository: sl(),
    ),
  );
}