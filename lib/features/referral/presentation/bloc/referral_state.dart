import 'package:equatable/equatable.dart';
import '../../domain/entities/referral.dart';

abstract class ReferralState extends Equatable {
  const ReferralState();

  @override
  List<Object?> get props => [];
}

class ReferralInitial extends ReferralState {}

class ReferralLoading extends ReferralState {}

class ReferralsLoaded extends ReferralState {
  final List<Referral> outgoing;
  final List<Referral> incoming;
  final int activeTab;

  const ReferralsLoaded({
    required this.outgoing,
    required this.incoming,
    this.activeTab = 0,
  });

  ReferralsLoaded copyWith({
    List<Referral>? outgoing,
    List<Referral>? incoming,
    int? activeTab,
  }) {
    return ReferralsLoaded(
      outgoing: outgoing ?? this.outgoing,
      incoming: incoming ?? this.incoming,
      activeTab: activeTab ?? this.activeTab,
    );
  }

  @override
  List<Object> get props => [outgoing, incoming, activeTab];
}

class ReferralCreated extends ReferralState {
  final Referral referral;
  const ReferralCreated(this.referral);

  @override
  List<Object> get props => [referral];
}

class ReferralUpdated extends ReferralState {
  final Referral referral;
  const ReferralUpdated(this.referral);

  @override
  List<Object> get props => [referral];
}

class ReferralError extends ReferralState {
  final String message;
  const ReferralError(this.message);

  @override
  List<Object> get props => [message];
}