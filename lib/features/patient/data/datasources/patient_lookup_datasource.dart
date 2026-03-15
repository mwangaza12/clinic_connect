import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/backend_api_service.dart';
import '../../domain/entities/patient_lookup.dart';

abstract class PatientLookupDatasource {
  Future<PatientLookupResult?> lookupByNupi(
      String nupi, String currentFacilityId);
  Future<Map<String, dynamic>?> getPatientSummary(
      String nupi, String facilityId);
}

// Calls the facility backend: GET /api/patients/nupi/:nupi
// The backend proxies to the HIE Gateway, adding facility credentials
// from env vars. This is the correct call chain:
//   Flutter → facility backend → HIE Gateway
class PatientLookupDatasourceImpl implements PatientLookupDatasource {
  @override
  Future<PatientLookupResult?> lookupByNupi(
      String nupi, String currentFacilityId) async {
    try {
      final backend = await BackendApiService.instanceAsync;
      final result = await backend.lookupPatient(nupi: nupi);

      if (!result.success) {
        debugPrint('[Backend] patient lookup failed: ${result.error}');
        return null;
      }

      final patient = result.data?['patient'] as Map<String, dynamic>?;
      if (patient == null) return null;

      final registeredFacilityId =
          patient['registeredAtFacility'] as String? ?? '';

      return PatientLookupResult(
        nupi: nupi,
        facilityId:        registeredFacilityId,
        facilityName:      patient['facilityName']   as String? ?? 'Unknown Facility',
        facilityCounty:    patient['facilityCounty'] as String? ?? '',
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
      final backend = await BackendApiService.instanceAsync;
      final result = await backend.lookupPatient(nupi: nupi);

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