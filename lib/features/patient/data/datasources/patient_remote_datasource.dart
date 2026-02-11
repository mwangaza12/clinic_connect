import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/patient_model.dart';

abstract class PatientRemoteDatasource {
  Future<PatientModel> registerPatient(PatientModel patient);
  Future<PatientModel> getPatient(String patientId);
  Future<List<PatientModel>> searchPatients(String query);
  Future<PatientModel> updatePatient(PatientModel patient);
  Future<PatientModel?> getPatientByNupi(String nupi);
}

class PatientRemoteDatasourceImpl implements PatientRemoteDatasource {
  final FirebaseFirestore firestore;

  PatientRemoteDatasourceImpl({required this.firestore});

  @override
  Future<PatientModel> registerPatient(PatientModel patient) async {
    try {
      // Check if NUPI already exists
      final existing = await getPatientByNupi(patient.nupi);
      if (existing != null) {
        throw ServerException('Patient with NUPI ${patient.nupi} already exists');
      }

      // Save to Firestore
      await firestore.collection('patients').doc(patient.id).set(patient.toJson());

      return patient;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to register patient: ${e.toString()}');
    }
  }

  @override
  Future<PatientModel> getPatient(String patientId) async {
    try {
      final doc = await firestore.collection('patients').doc(patientId).get();

      if (!doc.exists) {
        throw ServerException('Patient not found');
      }

      final data = doc.data()!;
      data['id'] = doc.id;

      return PatientModel.fromJson(data);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get patient: ${e.toString()}');
    }
  }

  @override
  Future<List<PatientModel>> searchPatients(String query) async {
    try {
      query.toLowerCase();

      // Search by NUPI
      final nupiQuery = await firestore
          .collection('patients')
          .where('nupi', isEqualTo: query)
          .get();

      if (nupiQuery.docs.isNotEmpty) {
        return nupiQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return PatientModel.fromJson(data);
        }).toList();
      }

      // Search by phone number
      final phoneQuery = await firestore
          .collection('patients')
          .where('phone_number', isEqualTo: query)
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        return phoneQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return PatientModel.fromJson(data);
        }).toList();
      }

      // If not found by exact match, return empty list
      // (Full-text search would require Algolia or similar)
      return [];
    } catch (e) {
      throw ServerException('Failed to search patients: ${e.toString()}');
    }
  }

  @override
  Future<PatientModel> updatePatient(PatientModel patient) async {
    try {
      await firestore.collection('patients').doc(patient.id).update(patient.toJson());
      return patient;
    } catch (e) {
      throw ServerException('Failed to update patient: ${e.toString()}');
    }
  }

  @override
  Future<PatientModel?> getPatientByNupi(String nupi) async {
    try {
      final query = await firestore
          .collection('patients')
          .where('nupi', isEqualTo: nupi)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;

      return PatientModel.fromJson(data);
    } catch (e) {
      throw ServerException('Failed to check NUPI: ${e.toString()}');
    }
  }
}