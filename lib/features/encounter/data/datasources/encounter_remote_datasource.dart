import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/encounter_model.dart';

abstract class EncounterRemoteDatasource {
  Future<EncounterModel> createEncounter(EncounterModel encounter);
  Future<List<EncounterModel>> getPatientEncounters(String patientId);
  Future<List<EncounterModel>> getFacilityEncounters(String facilityId);
  Future<EncounterModel> updateEncounter(EncounterModel encounter);
  Future<EncounterModel> getEncounter(String encounterId);
}

class EncounterRemoteDatasourceImpl implements EncounterRemoteDatasource {
  // Encounters live in facility's OWN Firebase — clinical data never leaves
  FirebaseFirestore get _db => FirebaseConfig.facilityDb;

  @override
  Future<EncounterModel> createEncounter(EncounterModel encounter) async {
    try {
      await _db
          .collection('encounters')
          .doc(encounter.id)
          .set(encounter.toFirestore());
      return encounter;
    } catch (e) {
      throw ServerException('Failed to create encounter: $e');
    }
  }

  @override
  Future<List<EncounterModel>> getPatientEncounters(
      String patientId) async {
    try {
      final query = await _db
          .collection('encounters')
          .where('patient_id', isEqualTo: patientId)
          .orderBy('encounter_date', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EncounterModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to get patient encounters: $e');
    }
  }

  @override
  Future<List<EncounterModel>> getFacilityEncounters(
      String facilityId) async {
    try {
      final query = await _db
          .collection('encounters')
          .where('facility_id', isEqualTo: facilityId)
          .orderBy('encounter_date', descending: true)
          .limit(50)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EncounterModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to get facility encounters: $e');
    }
  }

  @override
  Future<EncounterModel> updateEncounter(EncounterModel encounter) async {
    try {
      await _db
          .collection('encounters')
          .doc(encounter.id)
          .update(encounter.toFirestore());
      return encounter;
    } catch (e) {
      throw ServerException('Failed to update encounter: $e');
    }
  }

  @override
  Future<EncounterModel> getEncounter(String encounterId) async {
    try {
      final doc =
          await _db.collection('encounters').doc(encounterId).get();
      if (!doc.exists) throw ServerException('Encounter not found');
      final data = doc.data()!;
      data['id'] = doc.id;
      return EncounterModel.fromFirestore(data);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get encounter: $e');
    }
  }
}