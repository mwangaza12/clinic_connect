import 'package:equatable/equatable.dart';

class PatientLookupResult extends Equatable {
  final String nupi;
  final String facilityId;
  final String facilityName;
  final String facilityCounty;
  final bool isCurrentFacility;

  const PatientLookupResult({
    required this.nupi,
    required this.facilityId,
    required this.facilityName,
    required this.facilityCounty,
    required this.isCurrentFacility,
  });

  @override
  List<Object> get props => [
        nupi,
        facilityId,
        facilityName,
        facilityCounty,
        isCurrentFacility,
      ];
}