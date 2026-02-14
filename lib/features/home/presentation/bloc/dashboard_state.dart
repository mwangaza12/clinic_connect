import 'package:equatable/equatable.dart';
import '../../data/dashboard_service.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final List<Map<String, dynamic>> todayEncounters;

  const DashboardLoaded({
    required this.stats,
    required this.todayEncounters,
  });

  @override
  List<Object> get props => [stats, todayEncounters];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object> get props => [message];
}