import 'package:clinic_connect/core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/patient_model.dart';

abstract class PatientRemoteDatasource {
  Future<PatientModel> registerPatient(PatientModel patient);
  Future<PatientModel> getPatient(String patientId);
  Future<List<PatientModel>> searchPatients(String query);
  Future<PatientModel> updatePatient(PatientModel patient);
  Future<PatientModel?> getPatientByNupi(String nupi);
  Future<List<PatientModel>> getPatientsByFacility();
  Future<List<PatientModel>> getAllPatients();
}

class PatientRemoteDatasourceImpl implements PatientRemoteDatasource {
  String get facilityId   => FacilityInfo().facilityId.trim();
  String get facilityName => FacilityInfo().facilityName;

  PatientRemoteDatasourceImpl();

  @override
  Future<PatientModel> registerPatient(PatientModel patient) async {
    try {
      final patientWithFacility = patient.copyWith(facilityId: facilityId);

      // Save full record in this facility's own Firestore.
      // NOTE: the shared NUPI index write to sharedDb has been removed.
      // The AfyaLink HIE Gateway (HieApiService.registerPatient) already
      // registers the patient on AfyaChain and the gateway's own Firestore
      // when called from patient_registration_page.dart — no second write needed.
      await FirebaseConfig.facilityDb
          .collection('patients')
          .doc(patientWithFacility.id)
          .set(patientWithFacility.toFirestore());

      return patientWithFacility;
    } catch (e) {
      throw ServerException('Failed to register patient: $e');
    }
  }

  @override
  Future<PatientModel> getPatient(String patientId) async {
    try {
      final doc = await FirebaseConfig.facilityDb
          .collection('patients')
          .doc(patientId)
          .get();

      if (!doc.exists) {
        throw ServerException('Patient not found');
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return PatientModel.fromFirestore(data);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get patient: $e');
    }
  }

  @override
  Future<PatientModel?> getPatientByNupi(String nupi) async {
    try {
      final query = await FirebaseConfig.facilityDb
          .collection('patients')
          .where('nupi', isEqualTo: nupi)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;
      return PatientModel.fromFirestore(data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<PatientModel>> searchPatients(String query) async {
    try {
      if (query.isEmpty) return [];

      // Search by NUPI (exact match)
      final nupiQuery = await FirebaseConfig.facilityDb
          .collection('patients')
          .where('nupi', isEqualTo: query)
          .limit(10)
          .get();

      if (nupiQuery.docs.isNotEmpty) {
        return nupiQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return PatientModel.fromFirestore(data);
        }).toList();
      }

      // Search by phone (exact match)
      final phoneQuery = await FirebaseConfig.facilityDb
          .collection('patients')
          .where('phone_number', isEqualTo: query)
          .limit(10)
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        return phoneQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return PatientModel.fromFirestore(data);
        }).toList();
      }

      // Search by name (client-side filtering)
      final snapshot = await FirebaseConfig.facilityDb
          .collection('patients')
          .limit(50)
          .get();

      final results = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final fullName =
                '${data['first_name']} ${data['middle_name']} ${data['last_name']}'
                    .toLowerCase();
            return fullName.contains(query.toLowerCase());
          })
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return PatientModel.fromFirestore(data);
          })
          .toList();

      return results.take(10).toList();
    } catch (e) {
      throw ServerException('Failed to search patients: $e');
    }
  }

  @override
  Future<PatientModel> updatePatient(PatientModel patient) async {
    try {
      final updatedPatient = patient.copyWith(updatedAt: DateTime.now());

      await FirebaseConfig.facilityDb
          .collection('patients')
          .doc(patient.id)
          .update(updatedPatient.toFirestore());

      return updatedPatient;
    } catch (e) {
      throw ServerException('Failed to update patient: $e');
    }
  }

  @override
  Future<List<PatientModel>> getPatientsByFacility() async {
    final currentFacilityId = facilityId;

    if (currentFacilityId.isEmpty) {
      throw ServerException('Facility ID not set');
    }

    try {
      // Query both field name formats:
      // snake_case (app-registered patients) + camelCase (seeded patients)
      final results = await Future.wait([
        FirebaseConfig.facilityDb
            .collection('patients')
            .where('facility_id', isEqualTo: currentFacilityId)
            .get(),
        FirebaseConfig.facilityDb
            .collection('patients')
            .where('facilityId', isEqualTo: currentFacilityId)
            .get(),
      ]);

      // Merge and deduplicate by document ID
      final seen = <String>{};
      final patients = <PatientModel>[];
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          if (seen.add(doc.id)) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            patients.add(PatientModel.fromFirestore(data));
          }
        }
      }

      patients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return patients;
    } catch (e) {
      throw ServerException('Failed to get patients by facility: $e');
    }
  }

  @override
  Future<List<PatientModel>> getAllPatients() async {
    try {
      final snapshot = await FirebaseConfig.facilityDb
          .collection('patients')
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PatientModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to get all patients: $e');
    }
  }
}