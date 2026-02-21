import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/disease_program.dart';
import '../repositories/program_repository.dart';

class EnrollPatient {
  final ProgramRepository repository;

  EnrollPatient(this.repository);

  Future<Either<Failure, ProgramEnrollment>> call(EnrollPatientParams params) {
    return repository.enrollPatient(params.enrollment);
  }
}

class EnrollPatientParams {
  final ProgramEnrollment enrollment;

  EnrollPatientParams({required this.enrollment});
}