import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object> get props => [];
}

class LoadDashboardEvent extends DashboardEvent {
  final String facilityId;
  const LoadDashboardEvent(this.facilityId);
  @override
  List<Object> get props => [facilityId];
}

class RefreshDashboardEvent extends DashboardEvent {
  final String facilityId;
  const RefreshDashboardEvent(this.facilityId);
  @override
  List<Object> get props => [facilityId];
}