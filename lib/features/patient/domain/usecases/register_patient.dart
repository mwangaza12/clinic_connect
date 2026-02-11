import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class RegisterPatient {
  final PatientRepository repository;

  RegisterPatient(this.repository);

  Future<Either<Failure, Patient>> call(Patient patient) async {
    return await repository.registerPatient(patient);
  }
}