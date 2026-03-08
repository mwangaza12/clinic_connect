import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/hie_api_service.dart';
import '../../domain/entities/patient_lookup.dart';

abstract class PatientLookupDatasource {
  Future<PatientLookupResult?> lookupByNupi(
      String nupi, String currentFacilityId);
  Future<Map<String, dynamic>?> getPatientSummary(
      String nupi, String facilityId);
}

// Previously read from Firestore sharedDb.patient_index.
// Now calls the HIE Gateway: GET /api/patients/:nupi
// This is safe because the gateway only returns name, registration facility,
// and visit summary — no clinical data crosses facility boundaries.
class PatientLookupDatasourceImpl implements PatientLookupDatasource {
  @override
  Future<PatientLookupResult?> lookupByNupi(
      String nupi, String currentFacilityId) async {
    try {
      final result = await HieApiService.instance.lookupPatient(nupi: nupi);

      if (!result.success) {
        debugPrint('[HIE] patient lookup failed: ${result.error}');
        return null;
      }

      final patient = result.data?['patient'] as Map<String, dynamic>?;
      if (patient == null) return null;

      final registeredFacilityId =
          patient['registeredAtFacility'] as String? ?? '';

      return PatientLookupResult(
        nupi: nupi,
        facilityId:      registeredFacilityId,
        facilityName:    patient['facilityName']    as String? ?? 'Unknown Facility',
        facilityCounty:  patient['facilityCounty']  as String? ?? '',
        isCurrentFacility: registeredFacilityId == currentFacilityId,
      );
    } catch (e) {
      throw ServerException('Failed to lookup patient: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getPatientSummary(
      String nupi, String facilityId) async {
    try {
      final result = await HieApiService.instance.lookupPatient(nupi: nupi);

      if (!result.success || result.data == null) return null;

      final patient = result.data!['patient'] as Map<String, dynamic>?;
      if (patient == null) return null;

      // Return only the safe demographic summary — no clinical data
      return {
        'nupi':          nupi,
        'full_name':     patient['name']               ?? 'Unknown',
        'registered_at': patient['registeredAt'],
        'facility_id':   patient['registeredAtFacility'],
      };
    } catch (e) {
      throw ServerException('Failed to get patient summary: $e');
    }
  }
}