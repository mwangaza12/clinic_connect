// lib/features/facility/presentation/bloc/facility_event.dart

import 'package:equatable/equatable.dart';

abstract class FacilityEvent extends Equatable {
  const FacilityEvent();

  @override
  List<Object?> get props => [];
}

class SearchFacilitiesEvent extends FacilityEvent {
  final String query;

  const SearchFacilitiesEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class GetFacilitiesByCountyEvent extends FacilityEvent {
  final String county;

  const GetFacilitiesByCountyEvent(this.county);

  @override
  List<Object?> get props => [county];
}

class GetFacilityEvent extends FacilityEvent {
  final String facilityId;

  const GetFacilityEvent(this.facilityId);

  @override
  List<Object?> get props => [facilityId];
}

class LoadAllFacilitiesEvent extends FacilityEvent {
  final int limit;

  const LoadAllFacilitiesEvent({this.limit = 50});

  @override
  List<Object?> get props => [limit];
}

class ClearFacilitySearchEvent extends FacilityEvent {}