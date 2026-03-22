import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/facility_info.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/usecases/search_patient.dart';
import '../datasources/patient_local_datasource.dart';
import '../datasources/patient_remote_datasource.dart';
import '../models/patient_model.dart';

class PatientRepositoryImpl implements PatientRepository {
  final PatientRemoteDatasource remoteDatasource;
  final PatientLocalDatasource localDatasource;

  PatientRepositoryImpl({
    required this.remoteDatasource,
    required this.localDatasource,
  });

  // Callback set by the bloc to be notified when background refresh completes
  void Function(List<Patient>)? onPatientsRefreshed;

  @override
  Future<Either<Failure, Patient>> registerPatient(Patient patient) async {
    try {
      final patientModel = PatientModel.fromEntity(patient);
      final savedPatient = await localDatasource.savePatient(patientModel);
      try {
        await remoteDatasource.registerPatient(patientModel);
        await localDatasource.updateSyncStatus(patientModel.id, 'synced');
      } catch (e) {
        await localDatasource.updateSyncStatus(patientModel.id, 'pending');
      }
      return Right(savedPatient);
    } on LocalException catch (e) {
      return Left(LocalFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Patient>> getPatient(String patientId) async {
    try {
      try {
        final patient = await localDatasource.getPatientByNupi(patientId);
        if (patient != null) return Right(patient);
      } on LocalException {
        // Continue to remote
      }
      final patient = await remoteDatasource.getPatient(patientId);
      await localDatasource.cachePatient(patient);
      return Right(patient);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on LocalException catch (e) {
      return Left(LocalFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Patient>>> searchPatients({
    required String query,
    required SearchType searchType,
    String? facilityId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      try {
        final patients = await remoteDatasource.searchPatients(query);
        for (final patient in patients) {
          await localDatasource.cachePatient(patient);
        }
        return Right(patients);
      } on ServerException {
        final allPatients = await localDatasource.getAllPatients();
        final filteredPatients = allPatients.where((patient) {
          final fullName =
              '${patient.firstName} ${patient.lastName}'.toLowerCase();
          final nupi = patient.nupi.toLowerCase();
          final searchQuery = query.toLowerCase();
          return fullName.contains(searchQuery) ||
              nupi.contains(searchQuery) ||
              patient.phoneNumber.contains(searchQuery);
        }).toList();
        return Right(filteredPatients);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on LocalException catch (e) {
      return Left(LocalFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Patient>> updatePatient(Patient patient) async {
    try {
      final patientModel = PatientModel.fromEntity(patient);
      await localDatasource.updatePatient(patientModel);
      try {
        final updatedPatient = await remoteDatasource
            .updatePatient(patientModel)
            .timeout(const Duration(seconds: 10));
        await localDatasource.updateSyncStatus(patientModel.id, 'synced');
        return Right(updatedPatient);
      } catch (_) {
        await localDatasource.updateSyncStatus(patientModel.id, 'pending');
        return Right(patientModel);
      }
    } on LocalException catch (e) {
      return Left(LocalFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Patient>>> getAllPatients() async {
    try {
      try {
        final patients = await remoteDatasource.getAllPatients();
        for (final patient in patients) {
          await localDatasource.cachePatient(patient);
        }
        return Right(patients.map((p) => p.toEntity()).toList());
      } on ServerException {
        final patients = await localDatasource.getAllPatients();
        return Right(patients.map((p) => p.toEntity()).toList());
      }
    } catch (e) {
      try {
        final patients = await localDatasource.getAllPatients();
        return Right(patients.map((p) => p.toEntity()).toList());
      } catch (cacheError) {
        return Left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, List<Patient>>> getPatientsByFacility() async {
    final facilityId = FacilityInfo().facilityId.trim();
    debugPrint('[PatientRepo] getPatientsByFacility facilityId="$facilityId"');

    try {
      // Always try Firestore first — it is the source of truth.
      // SQLite-first was failing because FacilityInfo was sometimes
      // empty before restoreFromStorage completed.
      try {
        final remote = await remoteDatasource
            .getPatientsByFacility()
            .timeout(const Duration(seconds: 15));
        debugPrint('[PatientRepo] Firestore returned ${remote.length} patients');

        // Cache locally without re-enqueueing to Firestore
        for (final p in remote) {
          await localDatasource.cachePatient(p);
        }

        // Return Firestore data even if empty
        final entities = remote.map((p) => p.toEntity()).toList();
        // Notify bloc so it re-emits (covers the background-refresh case)
        onPatientsRefreshed?.call(entities);
        return Right(entities);

      } catch (e) {
        debugPrint('[PatientRepo] Firestore failed ($e) — falling back to SQLite');
      }

      // Firestore failed (offline) — read SQLite
      final allLocal = await localDatasource.getAllPatients();
      debugPrint('[PatientRepo] SQLite has ${allLocal.length} total patients');

      // Filter by facilityId if set, otherwise return everything
      final filtered = facilityId.isEmpty
          ? allLocal
          : allLocal
              .where((p) => p.facilityId.trim() == facilityId)
              .toList();

      debugPrint('[PatientRepo] Returning ${filtered.length} patients');
      return Right(filtered.map((p) => p.toEntity()).toList());

    } catch (e) {
      debugPrint('[PatientRepo] Fatal error: $e');
      return Left(CacheFailure('Failed to load patients: $e'));
    }
  }

}