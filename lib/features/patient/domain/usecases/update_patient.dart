import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class UpdatePatient {
  final PatientRepository repository;

  UpdatePatient(this.repository);

  Future<Either<Failure, Patient>> call(Patient patient) async {
    return await repository.updatePatient(patient);
  }
}