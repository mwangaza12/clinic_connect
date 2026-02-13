import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/referral.dart';
import '../repositories/referral_repository.dart';

class CreateReferral {
  final ReferralRepository repository;
  CreateReferral(this.repository);

  Future<Either<Failure, Referral>> call(Referral referral) async {
    return await repository.createReferral(referral);
  }
}