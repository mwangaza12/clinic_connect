// lib/features/facility/data/repositories/facility_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/facility.dart';
import '../../domain/repositories/facility_repository.dart';
import '../datasources/facility_remote_datasource.dart';
import '../models/facility_model.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  final FacilityRemoteDatasource remoteDatasource;

  FacilityRepositoryImpl({required this.remoteDatasource});

  @override
  Future<Either<Failure, List<Facility>>> searchFacilities(String query) async {
    try {
      final result = await remoteDatasource.searchFacilities(query);
      return Right(result.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Facility>>> getFacilitiesByCounty(String county) async {
    try {
      final result = await remoteDatasource.getFacilitiesByCounty(county);
      return Right(result.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Facility?>> getFacility(String facilityId) async {
    try {
      final result = await remoteDatasource.getFacility(facilityId);
      return Right(result?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> registerFacility(Facility facility) async {
    try {
      final model = FacilityModel.fromEntity(facility);
      await remoteDatasource.registerFacility(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateFacility(Facility facility) async {
    try {
      final model = FacilityModel.fromEntity(facility);
      await remoteDatasource.updateFacility(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Facility>>> getAllFacilities({int limit = 50}) async {
    try {
      final result = await remoteDatasource.getAllFacilities(limit: limit);
      return Right(result.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}