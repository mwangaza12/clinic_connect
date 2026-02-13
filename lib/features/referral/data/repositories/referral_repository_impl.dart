import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/referral.dart';
import '../../domain/repositories/referral_repository.dart';
import '../datasources/referral_remote_datasource.dart';
import '../models/referral_model.dart';

class ReferralRepositoryImpl implements ReferralRepository {
  final ReferralRemoteDatasource remoteDatasource;

  ReferralRepositoryImpl({required this.remoteDatasource});

  @override
  Future<Either<Failure, Referral>> createReferral(Referral referral) async {
    try {
      final model = ReferralModel.fromEntity(referral);
      final result = await remoteDatasource.createReferral(model);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Referral>>> getOutgoingReferrals(
      String facilityId) async {
    try {
      final result = await remoteDatasource.getOutgoingReferrals(facilityId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Referral>>> getIncomingReferrals(
      String facilityId) async {
    try {
      final result = await remoteDatasource.getIncomingReferrals(facilityId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Referral>> updateReferralStatus(
    String referralId,
    ReferralStatus status, {
    String? feedbackNotes,
  }) async {
    try {
      final result = await remoteDatasource.updateReferralStatus(
        referralId,
        status,
        feedbackNotes: feedbackNotes,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Referral>> getReferral(String referralId) async {
    try {
      final result = await remoteDatasource.getReferral(referralId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}