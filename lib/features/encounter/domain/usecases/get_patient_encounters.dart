import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/encounter.dart';
import '../repositories/encounter_repository.dart';

class GetPatientEncounters {
  final EncounterRepository repository;
  GetPatientEncounters(this.repository);

  Future<Either<Failure, List<Encounter>>> call(String patientId) =>
      repository.getPatientEncounters(patientId);
}