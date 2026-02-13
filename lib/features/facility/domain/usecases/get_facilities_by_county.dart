// lib/features/facility/domain/usecases/get_facilities_by_county.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/facility.dart';
import '../repositories/facility_repository.dart';

class GetFacilitiesByCounty {
  final FacilityRepository repository;

  GetFacilitiesByCounty(this.repository);

  Future<Either<Failure, List<Facility>>> call(String county) async {
    return await repository.getFacilitiesByCounty(county);
  }
}