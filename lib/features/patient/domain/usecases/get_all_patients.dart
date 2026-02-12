import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class GetAllPatients {
  final PatientRepository repository;

  GetAllPatients(this.repository);

  Future<Either<Failure, List<Patient>>> call() async {
    return await repository.getAllPatients();
  }
}