import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/encounter.dart';

abstract class EncounterRepository {
  Future<Either<Failure, Encounter>> createEncounter(Encounter encounter);
  Future<Either<Failure, List<Encounter>>> getPatientEncounters(
      String patientId);
  Future<Either<Failure, List<Encounter>>> getFacilityEncounters(
      String facilityId);
  Future<Either<Failure, Encounter>> updateEncounter(Encounter encounter);
  Future<Either<Failure, Encounter>> getEncounter(String encounterId);
}