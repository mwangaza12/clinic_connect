import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/encounter.dart';
import '../../domain/repositories/encounter_repository.dart';
import '../datasources/encounter_remote_datasource.dart';
import '../models/encounter_model.dart';

class EncounterRepositoryImpl implements EncounterRepository {
  final EncounterRemoteDatasource remoteDatasource;
  EncounterRepositoryImpl({required this.remoteDatasource});

  @override
  Future<Either<Failure, Encounter>> createEncounter(
      Encounter encounter) async {
    try {
      final model = EncounterModel.fromEntity(encounter);
      final result = await remoteDatasource.createEncounter(model);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Encounter>>> getPatientEncounters(
      String patientId) async {
    try {
      final result =
          await remoteDatasource.getPatientEncounters(patientId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Encounter>>> getFacilityEncounters(
      String facilityId) async {
    try {
      final result =
          await remoteDatasource.getFacilityEncounters(facilityId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Encounter>> updateEncounter(
      Encounter encounter) async {
    try {
      final model = EncounterModel.fromEntity(encounter);
      final result = await remoteDatasource.updateEncounter(model);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Encounter>> getEncounter(
      String encounterId) async {
    try {
      final result =
          await remoteDatasource.getEncounter(encounterId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}