import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/referral.dart';
import '../repositories/referral_repository.dart';

class GetOutgoingReferrals {
  final ReferralRepository repository;
  GetOutgoingReferrals(this.repository);

  Future<Either<Failure, List<Referral>>> call(String facilityId) async {
    return await repository.getOutgoingReferrals(facilityId);
  }
}

class GetIncomingReferrals {
  final ReferralRepository repository;
  GetIncomingReferrals(this.repository);

  Future<Either<Failure, List<Referral>>> call(String facilityId) async {
    return await repository.getIncomingReferrals(facilityId);
  }
}