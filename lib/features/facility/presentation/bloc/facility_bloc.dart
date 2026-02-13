// lib/features/facility/presentation/bloc/facility_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/search_facilities.dart';
import '../../domain/usecases/get_facilities_by_county.dart';
import '../../domain/usecases/get_facility.dart';
import '../../domain/usecases/get_all_facilities.dart';
import 'facility_event.dart';
import 'facility_state.dart';

class FacilityBloc extends Bloc<FacilityEvent, FacilityState> {
  final SearchFacilities searchFacilities;
  final GetFacilitiesByCounty getFacilitiesByCounty;
  final GetFacility getFacility;
  final GetAllFacilities getAllFacilities;

  FacilityBloc({
    required this.searchFacilities,
    required this.getFacilitiesByCounty,
    required this.getFacility,
    required this.getAllFacilities,
  }) : super(FacilityInitial()) {
    on<SearchFacilitiesEvent>(_onSearchFacilities);
    on<GetFacilitiesByCountyEvent>(_onGetFacilitiesByCounty);
    on<GetFacilityEvent>(_onGetFacility);
    on<LoadAllFacilitiesEvent>(_onLoadAllFacilities);
    on<ClearFacilitySearchEvent>(_onClearSearch);
  }

  Future<void> _onSearchFacilities(
    SearchFacilitiesEvent event,
    Emitter<FacilityState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(const FacilitySearchLoaded(facilities: [], query: ''));
      return;
    }

    emit(FacilityLoading());

    final result = await searchFacilities(event.query);

    result.fold(
      (failure) => emit(FacilityError(failure.message)),
      (facilities) => emit(FacilitySearchLoaded(
        facilities: facilities,
        query: event.query,
      )),
    );
  }

  Future<void> _onGetFacilitiesByCounty(
    GetFacilitiesByCountyEvent event,
    Emitter<FacilityState> emit,
  ) async {
    emit(FacilityLoading());

    final result = await getFacilitiesByCounty(event.county);

    result.fold(
      (failure) => emit(FacilityError(failure.message)),
      (facilities) => emit(FacilitiesByCountyLoaded(
        facilities: facilities,
        county: event.county,
      )),
    );
  }

  Future<void> _onGetFacility(
    GetFacilityEvent event,
    Emitter<FacilityState> emit,
  ) async {
    emit(FacilityLoading());

    final result = await getFacility(event.facilityId);

    result.fold(
      (failure) => emit(FacilityError(failure.message)),
      (facility) {
        if (facility != null) {
          emit(FacilityLoaded(facility));
        } else {
          emit(const FacilityError('Facility not found'));
        }
      },
    );
  }

  Future<void> _onLoadAllFacilities(
    LoadAllFacilitiesEvent event,
    Emitter<FacilityState> emit,
  ) async {
    emit(FacilityLoading());

    final result = await getAllFacilities(limit: event.limit);

    result.fold(
      (failure) => emit(FacilityError(failure.message)),
      (facilities) => emit(AllFacilitiesLoaded(facilities)),
    );
  }

  void _onClearSearch(
    ClearFacilitySearchEvent event,
    Emitter<FacilityState> emit,
  ) {
    emit(const FacilitySearchLoaded(facilities: [], query: ''));
  }
}