// lib/features/facility/domain/usecases/get_all_facilities.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/facility.dart';
import '../repositories/facility_repository.dart';

class GetAllFacilities {
  final FacilityRepository repository;

  GetAllFacilities(this.repository);

  Future<Either<Failure, List<Facility>>> call({int limit = 50}) async {
    return await repository.getAllFacilities(limit: limit);
  }
}