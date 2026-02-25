import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class GetAllPatientsByFacility {
  final PatientRepository repository;

  GetAllPatientsByFacility(this.repository);

  Future<Either<Failure, List<Patient>>> call() async {
    return await repository.getPatientsByFacility();
  }
}