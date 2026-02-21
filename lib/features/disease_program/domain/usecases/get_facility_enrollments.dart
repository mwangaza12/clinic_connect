import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/disease_program.dart';
import '../repositories/program_repository.dart';

class GetFacilityEnrollments {
  final ProgramRepository repository;

  GetFacilityEnrollments(this.repository);

  Future<Either<Failure, List<ProgramEnrollment>>> call(GetFacilityEnrollmentsParams params) {
    return repository.getFacilityEnrollments(params.facilityId);
  }
}

class GetFacilityEnrollmentsParams {
  final String facilityId;

  GetFacilityEnrollmentsParams({required this.facilityId});
}