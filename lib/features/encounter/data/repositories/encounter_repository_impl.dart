// lib/features/encounter/data/repositories/encounter_repository_impl.dart
//
// CHANGE: After saving to Firestore/SQLite, also calls
// HieApiService.recordEncounter() to mint an ENCOUNTER_RECORDED block
// on AfyaChain via the Node.js backend.
//
// The blockchain call is fire-and-forget — if it fails the encounter
// is still saved locally. A console warning is printed.

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/hie_api_service.dart';
import '../../domain/entities/encounter.dart';
import '../../domain/repositories/encounter_repository.dart';
import '../datasources/encounter_remote_datasource.dart';
import '../models/encounter_model.dart';

class EncounterRepositoryImpl implements EncounterRepository {
  final EncounterRemoteDatasource remoteDatasource;
  EncounterRepositoryImpl({required this.remoteDatasource});

  @override
  Future<Either<Failure, Encounter>> createEncounter(Encounter encounter) async {
    try {
      // 1. Save to Firestore + SQLite (existing flow)
      final model  = EncounterModel.fromEntity(encounter);
      final result = await remoteDatasource.createEncounter(model);

      // 2. Notify blockchain via Node.js backend (fire-and-forget)
      //    We pass an empty token here — the backend will accept it because
      //    staff are already authenticated to the system.  The gateway logs
      //    the encounter block without needing a patient access token.
      _notifyBlockchain(encounter);

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  void _notifyBlockchain(Encounter encounter) {
    // Build vital-signs map if present
    Map<String, dynamic>? vitals;
    if (encounter.vitals != null) {
      final v = encounter.vitals!;
      vitals = {
        if (v.systolicBP   != null) 'systolicBP':      v.systolicBP,
        if (v.diastolicBP  != null) 'diastolicBP':     v.diastolicBP,
        if (v.temperature  != null) 'temperature':     v.temperature,
        if (v.weight       != null) 'weight':          v.weight,
        if (v.height       != null) 'height':          v.height,
        if (v.pulseRate    != null) 'pulseRate':       v.pulseRate,
        if (v.respiratoryRate != null) 'respiratoryRate': v.respiratoryRate,
        if (v.oxygenSaturation != null) 'oxygenSaturation': v.oxygenSaturation,
        if (v.bloodGlucose != null) 'bloodGlucose':   v.bloodGlucose,
      };
    }

    // Diagnoses list
    final diagnoses = encounter.diagnoses.map((d) => {
      'code':        d.code,
      'description': d.description,
      'isPrimary':   d.isPrimary,
    }).toList();

    HieApiService.instance.recordEncounter(
      nupi:             encounter.patientNupi,
      accessToken:      '',       // staff token — backend accepts empty for encounter recording
      encounterType:    encounter.type.name,
      chiefComplaint:   encounter.chiefComplaint ?? '',
      practitionerName: encounter.clinicianName,
      vitalSigns:       vitals,
      diagnoses:        diagnoses.isEmpty ? null : diagnoses,
      notes:            encounter.clinicalNotes,
      encounterDate:    encounter.encounterDate.toIso8601String(),
    ).then((result) {
      if (result.success) {
        debugPrint('[HIE] ⛓ Encounter block #${result.blockIndex} minted for ${encounter.patientNupi}');
      } else {
        debugPrint('[HIE] ⚠ Blockchain notification failed: ${result.error}');
      }
    });
  }

  @override
  Future<Either<Failure, List<Encounter>>> getPatientEncounters(String patientId) async {
    try {
      final result = await remoteDatasource.getPatientEncounters(patientId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Encounter>>> getFacilityEncounters(String facilityId) async {
    try {
      final result = await remoteDatasource.getFacilityEncounters(facilityId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Encounter>> updateEncounter(Encounter encounter) async {
    try {
      final model  = EncounterModel.fromEntity(encounter);
      final result = await remoteDatasource.updateEncounter(model);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Encounter>> getEncounter(String encounterId) async {
    try {
      final result = await remoteDatasource.getEncounter(encounterId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}