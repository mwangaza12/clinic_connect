import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/dashboard_service.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardService _service;

  DashboardBloc(this._service) : super(DashboardInitial()) {
    on<LoadDashboardEvent>(_onLoad);
    on<RefreshDashboardEvent>(_onRefresh);
  }

  Future<void> _onLoad(
      LoadDashboardEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    await _fetch(event.facilityId, emit);
  }

  Future<void> _onRefresh(
      RefreshDashboardEvent event, Emitter<DashboardState> emit) async {
    // Keep the last loaded state visible while refreshing so numbers
    // don't flash back to "—" during a pull-to-refresh.
    await _fetch(event.facilityId, emit);
  }

  Future<void> _fetch(
      String facilityId, Emitter<DashboardState> emit) async {
    try {
      // Both calls are offline-aware — they route to SQLite when offline,
      // Firestore when online. No stream.first that can hang indefinitely.
      final results = await Future.wait([
        _service.getStats(facilityId),
        _service.getTodayEncountersList(facilityId),
      ]);

      emit(DashboardLoaded(
        stats:           results[0] as DashboardStats,
        todayEncounters: results[1] as List<Map<String, dynamic>>,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}