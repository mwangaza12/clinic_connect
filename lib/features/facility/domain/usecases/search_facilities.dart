// lib/features/facility/domain/usecases/search_facilities.dart

import 'package:clinic_connect/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import '../entities/facility.dart';
import '../repositories/facility_repository.dart';

class SearchFacilities {
  final FacilityRepository repository;

  SearchFacilities(this.repository);

  Future<Either<Failure, List<Facility>>> call(String query) async {
    return await repository.searchFacilities(query);
  }
}