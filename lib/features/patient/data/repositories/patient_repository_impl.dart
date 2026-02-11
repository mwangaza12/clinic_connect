import 'package:clinic_connect/features/patient/domain/usecases/search_patient.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_local_datasource.dart';
import '../datasources/patient_remote_datasource.dart';
import '../models/patient_model.dart';

class PatientRepositoryImpl implements PatientRepository {
  final PatientRemoteDatasource remoteDatasource;
  final PatientLocalDatasource localDatasource;

  PatientRepositoryImpl({
    required this.remoteDatasource,
    required this.localDatasource,
  });

  @override
  Future<Either<Failure, Patient>> registerPatient(Patient patient) async {
    try {
      final patientModel = PatientModel.fromEntity(patient);

      // Save to remote (Firestore)
      final savedPatient = await remoteDatasource.registerPatient(patientModel);

      // Cache locally
      await localDatasource.cachePatient(savedPatient);

      return Right(savedPatient);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Patient>> getPatient(String patientId) async {
    try {
      // Try local first
      try {
        final patient = await localDatasource.getPatient(patientId);
        return Right(patient);
      } on CacheException {
        // If not in cache, get from remote
        final patient = await remoteDatasource.getPatient(patientId);
        await localDatasource.cachePatient(patient);
        return Right(patient);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Patient>>> searchPatients({
    required String query,
    required SearchType searchType,
    String? facilityId,
    int page = 1,
    int limit = 20,
  }) async{
    try {
      // Search remote
      final patients = await remoteDatasource.searchPatients(query);

      // Cache results
      for (final patient in patients) {
        await localDatasource.cachePatient(patient);
      }

      return Right(patients);
    } on ServerException catch (e) {
      // If remote fails, try local
      try {
        final patients = await localDatasource.searchPatients(query);
        return Right(patients);
      } catch (_) {
        return Left(ServerFailure(e.message));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Patient>> updatePatient(Patient patient) async {
    try {
      final patientModel = PatientModel.fromEntity(patient);

      // Update remote
      final updatedPatient = await remoteDatasource.updatePatient(patientModel);

      // Update cache
      await localDatasource.cachePatient(updatedPatient);

      return Right(updatedPatient);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}