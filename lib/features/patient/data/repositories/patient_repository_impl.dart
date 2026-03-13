import 'package:dartz/dartz.dart';
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

  @override
  Future<Either<Failure, Patient>> registerPatient(Patient patient) async {
    try {
      final patientModel = PatientModel.fromEntity(patient);

      // Save to local SQLite first (for offline support)
      final savedPatient = await localDatasource.savePatient(patientModel);

      // Attempt remote save (Firestore) through sync manager
      try {
        await remoteDatasource.registerPatient(patientModel);
        await localDatasource.updateSyncStatus(patientModel.id, 'synced');
      } catch (e) {
        // If remote fails, mark for later sync
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
      // Try local first
      try {
        final patient = await localDatasource.getPatientByNupi(patientId);
        if (patient != null) {
          return Right(patient);
        }
      } on LocalException {
        // Continue to remote
      }

      // If not in local, get from remote
      final patient = await remoteDatasource.getPatient(patientId);

      // Cache locally for future use
      await localDatasource.savePatient(patient);
      await localDatasource.updateSyncStatus(patient.id, 'synced');

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
      // Try remote search first
      try {
        final patients = await remoteDatasource.searchPatients(query);

        // Update local cache with results
        for (final patient in patients) {
          await localDatasource.savePatient(patient);
          await localDatasource.updateSyncStatus(patient.id, 'synced');
        }

        return Right(patients);
      } on ServerException {
        // If remote fails, search locally
        final allPatients = await localDatasource.getAllPatients();

        // Perform local filtering
        final filteredPatients = allPatients.where((patient) {
          final fullName = '${patient.firstName} ${patient.lastName}'
              .toLowerCase();
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

      // 1. Update SQLite immediately (offline-safe, returns instantly)
      await localDatasource.updatePatient(patientModel);

      // 2. Try remote update with a 10-second timeout so we never hang
      try {
        final updatedPatient = await remoteDatasource
            .updatePatient(patientModel)
            .timeout(const Duration(seconds: 10));
        await localDatasource.updateSyncStatus(patientModel.id, 'synced');
        return Right(updatedPatient);
      } catch (_) {
        // Remote failed or timed out — local is already saved, mark pending
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
      // Try remote first
      try {
        final patients = await remoteDatasource.getAllPatients();

        // Update local cache
        for (final patient in patients) {
          await localDatasource.savePatient(patient);
          await localDatasource.updateSyncStatus(patient.id, 'synced');
        }

        return Right(patients.map((p) => p.toEntity()).toList());
      } on ServerException {
        // Fallback to local
        final patients = await localDatasource.getAllPatients();
        return Right(patients.map((p) => p.toEntity()).toList());
      }
    } catch (e) {
      // Final fallback to local
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

    // BUG FIX: old code called Firestore first with no timeout — offline this
    // blocked 30+ seconds before falling back to SQLite.
    // New pattern: return SQLite immediately (instant), refresh Firestore in
    // the background so the next load gets fresh data.
    try {
      final allPatients = await localDatasource.getAllPatients();
      final localPatients = allPatients
          .where((p) => p.facilityId == facilityId)
          .toList();

      // Fire-and-forget — never awaited, never blocks the UI
      _refreshFromFirestoreInBackground(facilityId);

      return Right(localPatients.map((p) => p.toEntity()).toList());
    } catch (e) {
      return Left(CacheFailure('Failed to load patients: $e'));
    }
  }

  /// Pulls the latest patients from Firestore and writes them into SQLite.
  /// Called without await so callers get their SQLite data immediately.
  Future<void> _refreshFromFirestoreInBackground(String facilityId) async {
    try {
      final patients = await remoteDatasource
          .getPatientsByFacility()
          .timeout(const Duration(seconds: 10));
      for (final patient in patients) {
        await localDatasource.savePatient(patient);
        await localDatasource.updateSyncStatus(patient.id, 'synced');
      }
    } catch (_) {
      // Network unavailable or timed out — silently ignored.
    }
  }
}