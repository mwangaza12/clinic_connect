import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/referral.dart';

abstract class ReferralRepository {
  Future<Either<Failure, Referral>> createReferral(Referral referral);
  Future<Either<Failure, List<Referral>>> getOutgoingReferrals(String facilityId);
  Future<Either<Failure, List<Referral>>> getIncomingReferrals(String facilityId);
  Future<Either<Failure, Referral>> updateReferralStatus(
      String referralId, ReferralStatus status, {String? feedbackNotes});
  Future<Either<Failure, Referral>> getReferral(String referralId);
}