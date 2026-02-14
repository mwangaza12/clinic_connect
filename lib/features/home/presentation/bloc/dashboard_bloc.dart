import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/dashboard_service.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardService _service;
  StreamSubscription? _encountersSub;

  DashboardBloc(this._service) : super(DashboardInitial()) {
    on<LoadDashboardEvent>(_onLoad);
    on<RefreshDashboardEvent>(_onRefresh);
  }

  Future<void> _onLoad(
      LoadDashboardEvent event,
      Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    await _fetch(event.facilityId, emit);
  }

  Future<void> _onRefresh(
      RefreshDashboardEvent event,
      Emitter<DashboardState> emit) async {
    await _fetch(event.facilityId, emit);
  }

  Future<void> _fetch(
      String facilityId, Emitter<DashboardState> emit) async {
    try {
      final stats =
          await _service.getStats(facilityId);

      final encounters =
          await _service
              .getTodayEncounters(facilityId)
              .first;

      emit(DashboardLoaded(
        stats: stats,
        todayEncounters: encounters,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _encountersSub?.cancel();
    return super.close();
  }
}