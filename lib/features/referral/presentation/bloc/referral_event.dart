import 'package:equatable/equatable.dart';
import '../../domain/entities/referral.dart';

abstract class ReferralEvent extends Equatable {
  const ReferralEvent();

  @override
  List<Object?> get props => [];
}

class LoadReferralsEvent extends ReferralEvent {
  final String facilityId;
  const LoadReferralsEvent(this.facilityId);

  @override
  List<Object> get props => [facilityId];
}

class CreateReferralEvent extends ReferralEvent {
  final Referral referral;
  const CreateReferralEvent(this.referral);

  @override
  List<Object> get props => [referral];
}

class UpdateReferralStatusEvent extends ReferralEvent {
  final String referralId;
  final ReferralStatus status;
  final String? feedbackNotes;

  const UpdateReferralStatusEvent(
    this.referralId,
    this.status, {
    this.feedbackNotes,
  });

  @override
  List<Object?> get props => [referralId, status, feedbackNotes];
}

class SwitchReferralTabEvent extends ReferralEvent {
  final int tabIndex;
  const SwitchReferralTabEvent(this.tabIndex);

  @override
  List<Object> get props => [tabIndex];
}