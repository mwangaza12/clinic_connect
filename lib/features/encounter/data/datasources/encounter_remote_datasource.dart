import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqlite_api.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_item.dart';
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
  Future<EncounterModel> createEncounter(
      EncounterModel encounter) async {
    try {
      final db = await DatabaseHelper().database;

      // Save to SQLite immediately
      await db.insert(
        'encounters',
        _encounterToSqlite(encounter),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Enqueue for Firestore sync
      await SyncManager().enqueue(
        entityType: SyncEntityType.encounter,
        entityId: encounter.id,
        operation: SyncOperation.create,
        payload: encounter.toFirestore().map(
              (k, v) => MapEntry(k, _firestoreValueToSqlite(v)),
            ),
      );

      return encounter;
    } catch (e) {
      throw ServerException('Failed to create encounter: $e');
    }
  }

  Map<String, dynamic> _encounterToSqlite(EncounterModel e) {
    return {
      'id': e.id,
      'patient_id': e.patientId,
      'patient_name': e.patientName,
      'patient_nupi': e.patientNupi,
      'facility_id': e.facilityId,
      'facility_name': e.facilityName,
      'clinician_id': e.clinicianId,
      'clinician_name': e.clinicianName,
      'type': e.type.name,
      'status': e.status.name,
      'vitals': e.vitals != null
          ? jsonEncode((e.vitals as VitalsModel).toMap())
          : null,
      'chief_complaint': e.chiefComplaint,
      'history': e.historyOfPresentingIllness,
      'examination': e.examinationFindings,
      'diagnoses': jsonEncode(
        e.diagnoses
            .map((d) => DiagnosisModel(
                  code: d.code,
                  description: d.description,
                  isPrimary: d.isPrimary,
                ).toMap())
            .toList(),
      ),
      'treatment_plan': e.treatmentPlan,
      'clinical_notes': e.clinicalNotes,
      'disposition': e.disposition?.name,
      'referral_id': e.referralId,
      'encounter_date': e.encounterDate.toIso8601String(),
      'sync_status': 'pending',
      'created_at': e.createdAt.toIso8601String(),
      'updated_at': e.updatedAt.toIso8601String(),
    };
  }

  dynamic _firestoreValueToSqlite(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is List) return jsonEncode(value);
    if (value is Map) return jsonEncode(value);
    return value;
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