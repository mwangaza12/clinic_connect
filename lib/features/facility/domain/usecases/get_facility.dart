// lib/features/facility/domain/usecases/get_facility.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/facility.dart';
import '../repositories/facility_repository.dart';

class GetFacility {
  final FacilityRepository repository;

  GetFacility(this.repository);

  Future<Either<Failure, Facility?>> call(String facilityId) async {
    return await repository.getFacility(facilityId);
  }
}