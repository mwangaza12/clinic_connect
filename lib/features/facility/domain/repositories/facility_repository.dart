// lib/features/facility/domain/repositories/facility_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/facility.dart';

abstract class FacilityRepository {
  Future<Either<Failure, List<Facility>>> searchFacilities(String query);
  Future<Either<Failure, List<Facility>>> getFacilitiesByCounty(String county);
  Future<Either<Failure, Facility?>> getFacility(String facilityId);
  Future<Either<Failure, void>> registerFacility(Facility facility);
  Future<Either<Failure, void>> updateFacility(Facility facility);
  Future<Either<Failure, List<Facility>>> getAllFacilities({int limit = 50});
}