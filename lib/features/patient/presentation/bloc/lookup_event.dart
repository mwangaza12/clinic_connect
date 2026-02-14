import 'package:equatable/equatable.dart';

abstract class LookupEvent extends Equatable {
  const LookupEvent();
  @override
  List<Object> get props => [];
}

class LookupPatientEvent extends LookupEvent {
  final String nupi;
  final String currentFacilityId;

  const LookupPatientEvent({
    required this.nupi,
    required this.currentFacilityId,
  });

  @override
  List<Object> get props => [nupi, currentFacilityId];
}

class FetchPatientSummaryEvent extends LookupEvent {
  final String nupi;
  final String facilityId;

  const FetchPatientSummaryEvent({
    required this.nupi,
    required this.facilityId,
  });

  @override
  List<Object> get props => [nupi, facilityId];
}

class ClearLookupEvent extends LookupEvent {}