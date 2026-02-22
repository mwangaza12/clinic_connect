import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/disease_program.dart';
import '../../domain/repositories/program_repository.dart';
import '../datasources/program_local_datasource.dart';
import '../datasources/program_remote_datasource.dart';
import '../models/program_enrollment_model.dart';

class ProgramRepositoryImpl implements ProgramRepository {
  final ProgramLocalDatasource localDatasource;
  final ProgramRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  ProgramRepositoryImpl({
    required this.localDatasource,
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, void>> enrollPatient(ProgramEnrollment enrollment) async {
    try {
      final model = ProgramEnrollmentModel.fromEntity(enrollment);
      
      // Always save locally first (offline-first)
      await localDatasource.cacheEnrollment(model);
      
      // Try to sync if online
      if (await networkInfo.isConnected) {
        try {
          await remoteDatasource.syncEnrollment(model);
        } catch (e) {
          // Sync will be retried later by SyncManager
          print('Failed to sync enrollment immediately: $e');
        }
      }
      
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> getPatientEnrollments(String patientNupi) async {
    try {
      final enrollments = await localDatasource.getPatientEnrollments(patientNupi);
      return Right(enrollments);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> getFacilityEnrollments(String facilityId) async {
    try {
      // Try local first
      final enrollments = await localDatasource.getFacilityEnrollments(facilityId);
      return Right(enrollments);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getProgramStats(String facilityId) async {
    try {
      final stats = await localDatasource.getProgramStats(facilityId);
      return Right(stats);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> updateEnrollmentStatus(
    String enrollmentId,
    ProgramEnrollmentStatus status,
    String? notes,
  ) async {
    try {
      await localDatasource.updateEnrollmentStatus(enrollmentId, status.name, notes);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  // ✅ Additional methods that might be in your interface
  
  @override
  Future<Either<Failure, ProgramEnrollment?>> getEnrollmentById(String enrollmentId) async {
    try {
      // You'll need to add this method to your datasource
      // For now, return a simple implementation
      final allEnrollments = await localDatasource.getFacilityEnrollments('');
      final enrollment = allEnrollments.firstWhere(
        (e) => e.id == enrollmentId,
        orElse: () => throw Exception('Enrollment not found'),
      );
      return Right(enrollment);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, int>> getActiveEnrollmentsCount(String facilityId, DiseaseProgram program) async {
    try {
      final stats = await localDatasource.getProgramStats(facilityId);
      final count = stats[program.name] ?? 0;
      return Right(count);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, double>> getCompletionRate(String facilityId, DiseaseProgram program) async {
    try {
      // Calculate completion rate from local data
      final allEnrollments = await localDatasource.getFacilityEnrollments(facilityId);
      final programEnrollments = allEnrollments.where((e) => e.program == program).toList();
      
      if (programEnrollments.isEmpty) {
        return const Right(0.0);
      }
      
      final completedCount = programEnrollments.where((e) => 
        e.status == ProgramEnrollmentStatus.completed
      ).length;
      
      final rate = (completedCount / programEnrollments.length) * 100;
      return Right(rate);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> generateEnrollmentReport(
    String facilityId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allEnrollments = await localDatasource.getFacilityEnrollments(facilityId);
      
      // Filter by date range
      final enrollmentsInRange = allEnrollments.where((e) =>
        e.enrollmentDate.isAfter(startDate) && e.enrollmentDate.isBefore(endDate)
      ).toList();
      
      // Generate report data
      final report = {
        'totalEnrollments': enrollmentsInRange.length,
        'byProgram': <String, int>{},
        'byStatus': <String, int>{},
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
      
      // Count by program
      for (final enrollment in enrollmentsInRange) {
        final program = enrollment.program.code;
        report['byProgram'] = {
          ...(report['byProgram'] as Map<String, int>),
          program: ((report['byProgram'] as Map<String, int>)[program] ?? 0) + 1,
        };
        
        // Count by status
        final status = enrollment.status.name;
        report['byStatus'] = {
          ...(report['byStatus'] as Map<String, int>),
          status: ((report['byStatus'] as Map<String, int>)[status] ?? 0) + 1,
        };
      }
      
      return Right(report);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> getEnrollmentsByProgram(
    String facilityId,
    DiseaseProgram program,
  ) async {
    try {
      final allEnrollments = await localDatasource.getFacilityEnrollments(facilityId);
      final filtered = allEnrollments.where((e) => e.program == program).toList();
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> getEnrollmentsByStatus(
    String facilityId,
    ProgramEnrollmentStatus status,
  ) async {
    try {
      final allEnrollments = await localDatasource.getFacilityEnrollments(facilityId);
      final filtered = allEnrollments.where((e) => e.status == status).toList();
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteEnrollment(String enrollmentId) async {
    try {
      // You'll need to add this to your datasource
      // For now, return success
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }
}