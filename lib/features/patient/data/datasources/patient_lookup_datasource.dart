import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/patient_lookup.dart';

abstract class PatientLookupDatasource {
  Future<PatientLookupResult?> lookupByNupi(
      String nupi, String currentFacilityId);
  Future<Map<String, dynamic>?> getPatientSummary(
      String nupi, String facilityId);
}

class PatientLookupDatasourceImpl
    implements PatientLookupDatasource {
  // Lookup uses shared index — not facility DB
  FirebaseFirestore get _sharedDb =>
      FirebaseConfig.sharedDb;

  // Summary fetched from the registering facility DB
  // (in real system this would be an API call)
  // For thesis demo: we use shared index summary
  FirebaseFirestore get _facilityDb =>
      FirebaseConfig.facilityDb;

  @override
  Future<PatientLookupResult?> lookupByNupi(
      String nupi, String currentFacilityId) async {
    try {
      final doc = await _sharedDb
          .collection('patient_index')
          .doc(nupi)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final facilityId =
          data['facility_id'] as String? ?? '';
      final facilityName =
          data['facility_name'] as String? ??
              'Unknown Facility';
      final facilityCounty =
          data['facility_county'] as String? ?? '';

      return PatientLookupResult(
        nupi: nupi,
        facilityId: facilityId,
        facilityName: facilityName,
        facilityCounty: facilityCounty,
        isCurrentFacility:
            facilityId == currentFacilityId,
      );
    } catch (e) {
      throw ServerException(
          'Failed to lookup patient: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getPatientSummary(
      String nupi, String facilityId) async {
    try {
      // Fetch safe summary from shared index
      // Only non-clinical data: name, age, gender
      final doc = await _sharedDb
          .collection('patient_index')
          .doc(nupi)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;

      return {
        'nupi': nupi,
        'full_name': data['full_name'] ?? 'Unknown',
        'gender': data['gender'] ?? 'unknown',
        'date_of_birth': data['date_of_birth'],
        'facility_id': data['facility_id'],
        'facility_name': data['facility_name'],
        'facility_county': data['facility_county'],
        'registered_at': data['registered_at'],
      };
    } catch (e) {
      throw ServerException(
          'Failed to get patient summary: $e');
    }
  }
}