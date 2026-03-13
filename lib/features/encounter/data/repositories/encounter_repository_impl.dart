// lib/features/encounter/data/repositories/encounter_repository_impl.dart
//
// OFFLINE-FIRST ENCOUNTER FLOW:
//
//   createEncounter:
//     EncounterRemoteDatasource already does:
//       1. SQLite insert
//       2. SyncManager.enqueue(SyncEntityType.encounter) → Firestore
//     This repo additionally enqueues the HIE blockchain call:
//       3. SyncManager.enqueue(SyncEntityType.hieEncounter) → AfyaChain
//     Online  → queue flushes in 500 ms.
//     Offline → runs automatically on reconnect.
//
//   getPatientEncounters / getFacilityEncounters:
//     Offline → reads SQLite directly.
//     Online  → Firestore (existing behaviour).

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/connectivity_manager.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../../domain/entities/encounter.dart';
import '../../domain/repositories/encounter_repository.dart';
import '../datasources/encounter_remote_datasource.dart';
import '../models/encounter_model.dart';

class EncounterRepositoryImpl implements EncounterRepository {
  final EncounterRemoteDatasource remoteDatasource;
  final _dbHelper = DatabaseHelper();
  final _conn     = ConnectivityManager();

  EncounterRepositoryImpl({required this.remoteDatasource});

  // ── CREATE ─────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Encounter>> createEncounter(
      Encounter encounter) async {
    try {
      // 1 + 2: SQLite insert + Firestore sync queue (via remoteDatasource)
      final model  = EncounterModel.fromEntity(encounter);
      final result = await remoteDatasource.createEncounter(model);

      // 3: Queue the HIE blockchain call — fire now if online,
      //    otherwise runs automatically on reconnect.
      _queueHieEncounter(encounter);

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  void _queueHieEncounter(Encounter encounter) {
    // Build vitals map
    Map<String, dynamic>? vitals;
    if (encounter.vitals != null) {
      final v = encounter.vitals!;
      vitals = {
        if (v.systolicBP      != null) 'systolicBP':      v.systolicBP,
        if (v.diastolicBP     != null) 'diastolicBP':     v.diastolicBP,
        if (v.temperature     != null) 'temperature':     v.temperature,
        if (v.weight          != null) 'weight':          v.weight,
        if (v.height          != null) 'height':          v.height,
        if (v.pulseRate       != null) 'pulseRate':       v.pulseRate,
        if (v.respiratoryRate != null) 'respiratoryRate': v.respiratoryRate,
        if (v.oxygenSaturation != null)
          'oxygenSaturation': v.oxygenSaturation,
        if (v.bloodGlucose    != null) 'bloodGlucose':    v.bloodGlucose,
      };
    }

    final diagnoses = encounter.diagnoses
        .map((d) => {
              'code':        d.code,
              'description': d.description,
              'isPrimary':   d.isPrimary,
            })
        .toList();

    SyncManager()
        .enqueue(
          entityType: SyncEntityType.hieEncounter,
          entityId:   'hie_${encounter.id}',
          operation:  SyncOperation.create,
          payload: {
            'nupi':             encounter.patientNupi,
            'accessToken':      '',
            'encounterType':    encounter.type.name,
            'chiefComplaint':   encounter.chiefComplaint ?? '',
            'practitionerName': encounter.clinicianName,
            'vitalSigns':       vitals,
            'diagnoses':        diagnoses.isEmpty ? null : diagnoses,
            'notes':            encounter.clinicalNotes,
            'encounterDate':    encounter.encounterDate.toIso8601String(),
          },
        )
        .then((_) =>
            debugPrint('[Encounter] HIE block queued for ${encounter.patientNupi}'))
        .catchError((e) =>
            debugPrint('[Encounter] HIE queue error: $e'));
  }

  // ── READ ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Encounter>>> getPatientEncounters(
      String patientId) async {
    final online = await _conn.checkConnectivity();
    if (!online) {
      return _getPatientEncountersSQLite(patientId);
    }
    try {
      final result = await remoteDatasource.getPatientEncounters(patientId);
      return Right(result);
    } on ServerException catch (_) {
      return _getPatientEncountersSQLite(patientId);
    }
  }

  Future<Either<Failure, List<Encounter>>>
      _getPatientEncountersSQLite(String patientId) async {
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('encounters',
          where:     'patient_id = ?',
          whereArgs: [patientId],
          orderBy:   'encounter_date DESC');
      return Right(rows
          .map((r) => EncounterModel.fromSqlite(r))
          .toList());
    } catch (e) {
      return Left(LocalFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Encounter>>> getFacilityEncounters(
      String facilityId) async {
    final online = await _conn.checkConnectivity();
    if (!online) {
      return _getFacilityEncountersSQLite(facilityId);
    }
    try {
      final result =
          await remoteDatasource.getFacilityEncounters(facilityId);
      return Right(result);
    } on ServerException catch (_) {
      return _getFacilityEncountersSQLite(facilityId);
    }
  }

  Future<Either<Failure, List<Encounter>>>
      _getFacilityEncountersSQLite(String facilityId) async {
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('encounters',
          where:     'facility_id = ?',
          whereArgs: [facilityId],
          orderBy:   'encounter_date DESC',
          limit:     50);
      return Right(rows
          .map((r) => EncounterModel.fromSqlite(r))
          .toList());
    } catch (e) {
      return Left(LocalFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Encounter>> updateEncounter(
      Encounter encounter) async {
    try {
      final model = EncounterModel.fromEntity(encounter);

      // 1. Update SQLite immediately — offline-safe, returns instantly
      final db = await _dbHelper.database;
      await db.update(
        'encounters',
        model.toSqlite(),
        where: 'id = ?',
        whereArgs: [model.id],
      );

      // 2. Enqueue as an update for Firestore sync
      await SyncManager().enqueue(
        entityType: SyncEntityType.encounter,
        entityId: model.id,
        operation: SyncOperation.update,
        payload: model.toSqlite(),
      );

      // 3. Try live Firestore update with a 10-second timeout
      //    If it fails/times out the sync queue will retry on reconnect
      try {
        await remoteDatasource
            .updateEncounter(model)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Offline or slow — local already saved, sync will handle it
      }

      return Right(model);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Encounter>> getEncounter(
      String encounterId) async {
    // Try SQLite first (offline-safe)
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('encounters',
          where: 'id = ?', whereArgs: [encounterId], limit: 1);
      if (rows.isNotEmpty) {
        return Right(EncounterModel.fromSqlite(rows.first));
      }
    } catch (_) {}

    // Firestore fallback
    try {
      final result =
          await remoteDatasource.getEncounter(encounterId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}