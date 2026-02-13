import 'package:clinic_connect/features/facility/data/datasources/facility_remote_datasource.dart';
import 'package:clinic_connect/features/facility/data/repositories/facility_repository_impl.dart';
import 'package:clinic_connect/features/facility/domain/repositories/facility_repository.dart';
import 'package:clinic_connect/features/patient/domain/usecases/get_all_patients.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'core/database/database_helper.dart';
import 'core/network/network_info.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login.dart';
import 'features/auth/domain/usecases/logout.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/patient/data/datasources/patient_local_datasource.dart';
import 'features/patient/data/datasources/patient_remote_datasource.dart';
import 'features/patient/data/repositories/patient_repository_impl.dart';
import 'features/patient/domain/repositories/patient_repository.dart';
import 'features/patient/domain/usecases/register_patient.dart';
import 'features/patient/domain/usecases/search_patient.dart';
import 'features/patient/presentation/bloc/patient_bloc.dart';
import 'features/referral/data/datasources/referral_remote_datasource.dart';
import 'features/referral/data/datasources/referral_remote_datasource_impl.dart';
import 'features/referral/data/repositories/referral_repository_impl.dart';
import 'features/referral/domain/repositories/referral_repository.dart';
import 'features/referral/domain/usecases/create_referral.dart';
import 'features/referral/domain/usecases/get_referrals.dart';
import 'features/referral/domain/usecases/update_referral_status.dart';
import 'features/referral/presentation/bloc/referral_bloc.dart';

// FACILITY IMPORTS
import 'features/facility/domain/usecases/get_all_facilities.dart';
import 'features/facility/domain/usecases/get_facilities_by_county.dart';
import 'features/facility/domain/usecases/get_facility.dart';
import 'features/facility/domain/usecases/search_facilities.dart';
import 'features/facility/presentation/bloc/facility_bloc.dart';

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
    () => NetworkInfoImpl(
      connectionChecker: sl(),
    ),
  );

  // ==================
  // DATA SOURCES
  // ==================
  // Auth Data Sources
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

  // Patient Data Sources
  sl.registerLazySingleton<PatientRemoteDatasource>(
    () => PatientRemoteDatasourceImpl(),
  );

  sl.registerLazySingleton<PatientLocalDatasource>(
    () => PatientLocalDatasourceImpl(
      databaseHelper: sl(),
    ),
  );

  // Referral Data Sources
  sl.registerLazySingleton<ReferralRemoteDatasource>(
    () => ReferralRemoteDatasourceImpl(),
  );

  // FACILITY DATA SOURCES - REGISTER ONLY ONCE!
  sl.registerLazySingleton<FacilityRemoteDatasource>(
    () => FacilityRemoteDatasourceImpl(),
  );

  // ==================
  // REPOSITORIES
  // ==================
  // Auth Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDatasource: sl(),
      localDatasource: sl(),
    ),
  );

  // Patient Repository
  sl.registerLazySingleton<PatientRepository>(
    () => PatientRepositoryImpl(
      remoteDatasource: sl(),
      localDatasource: sl(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // Referral Repository
  sl.registerLazySingleton<ReferralRepository>(
    () => ReferralRepositoryImpl(
      remoteDatasource: sl(),
    ),
  );

  // FACILITY REPOSITORY
  sl.registerLazySingleton<FacilityRepository>(
    () => FacilityRepositoryImpl(
      remoteDatasource: sl(),
    ),
  );

  // ==================
  // USE CASES
  // ==================
  // Auth Use Cases
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Logout(sl()));
  
  // Patient Use Cases
  sl.registerLazySingleton(() => RegisterPatient(sl()));
  sl.registerLazySingleton(() => SearchPatient(sl()));
  sl.registerLazySingleton(() => GetAllPatients(sl()));

  // Referral Use Cases
  sl.registerLazySingleton(() => CreateReferral(sl()));
  sl.registerLazySingleton(() => GetOutgoingReferrals(sl()));
  sl.registerLazySingleton(() => GetIncomingReferrals(sl()));
  sl.registerLazySingleton(() => UpdateReferralStatus(sl()));

  // FACILITY USE CASES
  sl.registerLazySingleton(() => SearchFacilities(sl()));
  sl.registerLazySingleton(() => GetFacilitiesByCounty(sl()));
  sl.registerLazySingleton(() => GetFacility(sl()));
  sl.registerLazySingleton(() => GetAllFacilities(sl()));

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

  // FACILITY BLOC
  sl.registerFactory(
    () => FacilityBloc(
      searchFacilities: sl(),
      getFacilitiesByCounty: sl(),
      getFacility: sl(),
      getAllFacilities: sl(),
    ),
  );
}