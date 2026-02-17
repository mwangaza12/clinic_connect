import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/patient_model.dart';

abstract class PatientRemoteDatasource {
  Future<PatientModel> registerPatient(PatientModel patient);
  Future<PatientModel> getPatient(String patientId);
  Future<List<PatientModel>> searchPatients(String query);
  Future<PatientModel> updatePatient(PatientModel patient);
  Future<PatientModel?> getPatientByNupi(String nupi);
  Future<List<PatientModel>> getPatientsByFacility(
      String facilityId);
  Future<List<PatientModel>> getAllPatients();
}

class PatientRemoteDatasourceImpl
    implements PatientRemoteDatasource {
  // ✅ Facility info passed in via constructor
  final String facilityId;
  final String facilityName;
  final String facilityCounty;

  PatientRemoteDatasourceImpl({
    required this.facilityId,
    required this.facilityName,
    required this.facilityCounty,
  });

  @override
  Future<PatientModel> registerPatient(
      PatientModel patient) async {
    try {
      // 1. Save full record in OWN facility DB
      await FirebaseConfig.facilityDb
          .collection('patients')
          .doc(patient.id)
          .set(patient.toFirestore());

      // 2. Register NUPI in shared index
      //    Only safe demographics — no clinical data
      await FirebaseConfig.sharedDb
          .collection('patient_index')
          .doc(patient.nupi)
          .set({
        'nupi': patient.nupi,
        'facility_id': patient.facilityId,
        'facility_name': facilityName,
        'facility_county': facilityCounty,
        'full_name': patient.fullName,
        'gender': patient.gender,
        'date_of_birth':
            Timestamp.fromDate(patient.dateOfBirth),
        'registered_at': Timestamp.now(),
      }, SetOptions(merge: true));

      return patient;
    } catch (e) {
      throw ServerException(
          'Failed to register patient: $e');
    }
  }

  @override
  Future<PatientModel> getPatient(
      String patientId) async {
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
  Future<PatientModel?> getPatientByNupi(
      String nupi) async {
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
  Future<List<PatientModel>> searchPatients(
      String query) async {
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
      final phoneQuery =
          await FirebaseConfig.facilityDb
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
      final snapshot =
          await FirebaseConfig.facilityDb
              .collection('patients')
              .limit(50)
              .get();

      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final fullName =
            '${data['first_name']} ${data['middle_name']} ${data['last_name']}'
                .toLowerCase();
        return fullName
            .contains(query.toLowerCase());
      }).map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PatientModel.fromFirestore(data);
      }).toList();

      return results.take(10).toList();
    } catch (e) {
      throw ServerException(
          'Failed to search patients: $e');
    }
  }

  @override
  Future<PatientModel> updatePatient(
      PatientModel patient) async {
    try {
      final updatedPatient = patient.copyWith(
        updatedAt: DateTime.now(),
      );

      await FirebaseConfig.facilityDb
          .collection('patients')
          .doc(patient.id)
          .update(updatedPatient.toFirestore());

      return updatedPatient;
    } catch (e) {
      throw ServerException(
          'Failed to update patient: $e');
    }
  }

  @override
  Future<List<PatientModel>> getPatientsByFacility(
      String facilityId) async {
    try {
      final snapshot =
          await FirebaseConfig.facilityDb
              .collection('patients')
              .where('facility_id',
                  isEqualTo: facilityId)
              .orderBy('created_at', descending: true)
              .limit(100)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PatientModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException(
          'Failed to get patients by facility: $e');
    }
  }

  @override
  Future<List<PatientModel>> getAllPatients() async {
    try {
      final snapshot =
          await FirebaseConfig.facilityDb
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
      throw ServerException(
          'Failed to get all patients: $e');
    }
  }
}