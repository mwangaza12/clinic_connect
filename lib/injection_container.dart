import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login.dart';
import 'features/auth/domain/usecases/logout.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

import 'core/database/database_helper.dart';
import 'features/patient/data/datasources/patient_local_datasource.dart';
import 'features/patient/data/datasources/patient_remote_datasource.dart';
import 'features/patient/data/repositories/patient_repository_impl.dart';
import 'features/patient/domain/repositories/patient_repository.dart';
import 'features/patient/domain/usecases/register_patient.dart';
import 'features/patient/domain/usecases/search_patient.dart';
import 'features/patient/presentation/bloc/patient_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // BLoCs
  sl.registerFactory(
    () => AuthBloc(
      loginUsecase: sl(),
      logoutUsecase: sl(),
    ),
  );

  // Patient BLoC
  sl.registerFactory(
    () => PatientBloc(
      registerPatientUsecase: sl(),
      searchPatientUsecase: sl(),
    ),
  );

  // Patient Use cases
  sl.registerLazySingleton(() => RegisterPatient(sl()));
  sl.registerLazySingleton(() => SearchPatient(sl()));

 // Patient Repository
  sl.registerLazySingleton<PatientRepository>(
    () => PatientRepositoryImpl(
      remoteDatasource: sl(),
      localDatasource: sl(),
    ),
  );

  // Patient Datasources
  sl.registerLazySingleton<PatientRemoteDatasource>(
    () => PatientRemoteDatasourceImpl(firestore: sl()),
  );

  sl.registerLazySingleton<PatientLocalDatasource>(
    () => PatientLocalDatasourceImpl(databaseHelper: sl()),
  );
  // Database
  sl.registerLazySingleton(() => DatabaseHelper());

  // Use cases
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Logout(sl()));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDatasource: sl(),
      localDatasource: sl(),
    ),
  );

  // Data sources
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

  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
}