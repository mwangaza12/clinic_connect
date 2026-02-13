import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/referral.dart';
import '../repositories/referral_repository.dart';

class UpdateReferralStatus {
  final ReferralRepository repository;
  UpdateReferralStatus(this.repository);

  Future<Either<Failure, Referral>> call(
    String referralId,
    ReferralStatus status, {
    String? feedbackNotes,
  }) async {
    return await repository.updateReferralStatus(
      referralId,
      status,
      feedbackNotes: feedbackNotes,
    );
  }
}