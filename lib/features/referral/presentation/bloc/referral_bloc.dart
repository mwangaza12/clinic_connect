import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/create_referral.dart';
import '../../domain/usecases/get_referrals.dart';
import '../../domain/usecases/update_referral_status.dart';
import 'referral_event.dart';
import 'referral_state.dart';

class ReferralBloc extends Bloc<ReferralEvent, ReferralState> {
  final CreateReferral createReferralUsecase;
  final GetOutgoingReferrals getOutgoingReferralsUsecase;
  final GetIncomingReferrals getIncomingReferralsUsecase;
  final UpdateReferralStatus updateReferralStatusUsecase;

  ReferralBloc({
    required this.createReferralUsecase,
    required this.getOutgoingReferralsUsecase,
    required this.getIncomingReferralsUsecase,
    required this.updateReferralStatusUsecase,
  }) : super(ReferralInitial()) {
    on<LoadReferralsEvent>(_onLoadReferrals);
    on<CreateReferralEvent>(_onCreateReferral);
    on<UpdateReferralStatusEvent>(_onUpdateStatus);
    on<SwitchReferralTabEvent>(_onSwitchTab);
  }

  Future<void> _onLoadReferrals(
    LoadReferralsEvent event,
    Emitter<ReferralState> emit,
  ) async {
    emit(ReferralLoading());

    final outgoingResult = await getOutgoingReferralsUsecase(event.facilityId);
    
    final incomingResult = await getIncomingReferralsUsecase(event.facilityId);

    outgoingResult.fold(
      (failure) {
        emit(ReferralError(failure.message));
      },
      (outgoing) {
        incomingResult.fold(
          (failure) {
            emit(ReferralError(failure.message));
          },
          (incoming) {
            emit(ReferralsLoaded(
              outgoing: outgoing,
              incoming: incoming,
              activeTab: 0,
            ));
          },
        );
      },
    );
  }

  Future<void> _onCreateReferral(
    CreateReferralEvent event,
    Emitter<ReferralState> emit,
  ) async {
    
    emit(ReferralLoading());
    
    try {
      final result = await createReferralUsecase(event.referral);
      
      result.fold(
        (failure) {
          emit(ReferralError(failure.message));
        },
        (referral) {
          emit(ReferralCreated(referral));
        },
      );
    } catch (e) {
      emit(ReferralError(e.toString()));
    }
  }

  Future<void> _onUpdateStatus(
    UpdateReferralStatusEvent event,
    Emitter<ReferralState> emit,
  ) async {
    emit(ReferralLoading());
    
    final result = await updateReferralStatusUsecase(
      event.referralId,
      event.status,
      feedbackNotes: event.feedbackNotes,
    );
    
    result.fold(
      (failure) {
        emit(ReferralError(failure.message));
      },
      (referral) {
        emit(ReferralUpdated(referral));
      },
    );
  }

  void _onSwitchTab(
    SwitchReferralTabEvent event,
    Emitter<ReferralState> emit,
  ) {
    if (state is ReferralsLoaded) {
      final currentState = state as ReferralsLoaded;
      emit(currentState.copyWith(activeTab: event.tabIndex));
    }
  }
}