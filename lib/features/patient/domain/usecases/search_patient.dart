import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class SearchPatient {
  final PatientRepository repository;

  SearchPatient(this.repository);

  Future<Either<Failure, List<Patient>>> call(SearchParams params) async {
    // Validate search query
    if (params.query.isEmpty) {
      return Left(InvalidSearchFailure('Search query cannot be empty'));
    }

    // For non-NUPI searches, require minimum 3 characters
    if (params.searchType != SearchType.byNupi && params.query.length < 3) {
      return Left(InvalidSearchFailure('Search query must be at least 3 characters'));
    }

    return await repository.searchPatients(
      query: params.query,
      searchType: params.searchType,
      facilityId: params.facilityId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class SearchParams {
  final String query;
  final SearchType searchType;
  final String? facilityId;
  final int page;
  final int limit;

  SearchParams({
    required this.query,
    this.searchType = SearchType.all,
    this.facilityId,
    this.page = 1,
    this.limit = 20,
  });
}

enum SearchType {
  all,
  byName,
  byNupi,
  byPhone,
  byIdNumber,
  byFacility,
}