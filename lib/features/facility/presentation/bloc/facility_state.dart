// lib/features/facility/presentation/bloc/facility_state.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/facility.dart';

abstract class FacilityState extends Equatable {
  const FacilityState();

  @override
  List<Object?> get props => [];
}

class FacilityInitial extends FacilityState {}

class FacilityLoading extends FacilityState {}

class FacilitySearchLoaded extends FacilityState {
  final List<Facility> facilities;
  final String query;

  const FacilitySearchLoaded({
    required this.facilities,
    required this.query,
  });

  @override
  List<Object?> get props => [facilities, query];
}

class FacilitiesByCountyLoaded extends FacilityState {
  final List<Facility> facilities;
  final String county;

  const FacilitiesByCountyLoaded({
    required this.facilities,
    required this.county,
  });

  @override
  List<Object?> get props => [facilities, county];
}

class FacilityLoaded extends FacilityState {
  final Facility facility;

  const FacilityLoaded(this.facility);

  @override
  List<Object?> get props => [facility];
}

class AllFacilitiesLoaded extends FacilityState {
  final List<Facility> facilities;

  const AllFacilitiesLoaded(this.facilities);

  @override
  List<Object?> get props => [facilities];
}

class FacilityError extends FacilityState {
  final String message;

  const FacilityError(this.message);

  @override
  List<Object?> get props => [message];
}