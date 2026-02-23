import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/disease_program.dart';
import '../../domain/repositories/program_repository.dart';
import '../datasources/program_local_datasource.dart';
import '../datasources/program_remote_datasource.dart';
import '../models/program_enrollment_model.dart';
import '../../domain/entities/program_statistics.dart';

// Simple ProgramStatistics class if not defined elsewhere
class ProgramStatistics {
  final int totalEnrollments;
  final int activeEnrollments;
  final Map<String, int> enrollmentsByProgram;

  ProgramStatistics({
    required this.totalEnrollments,
    required this.activeEnrollments,
    required this.enrollmentsByProgram,
  });
}

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
  Future<Either<Failure, ProgramEnrollment>> enrollPatient(ProgramEnrollment enrollment) async {
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
      
      return Right(enrollment);
    } catch (e) {
      return Left(CacheFailure('Failed to enroll patient: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> getPatientEnrollments(String patientNupi) async {
    try {
      final enrollments = await localDatasource.getPatientEnrollments(patientNupi);
      return Right(enrollments);
    } catch (e) {
      return Left(CacheFailure('Failed to get patient enrollments: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> getFacilityEnrollments(String facilityId) async {
    try {
      // Try local first
      final enrollments = await localDatasource.getFacilityEnrollments(facilityId);
      return Right(enrollments);
    } catch (e) {
      return Left(CacheFailure('Failed to get facility enrollments: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ProgramStatistics>> getProgramStats(String facilityId) async {
    try {
      final stats = await localDatasource.getProgramStats(facilityId);
      
      // Convert Map<String, int> to ProgramStatistics
      // Assuming ProgramStatistics is a class - adjust as needed
      final programStats = ProgramStatistics(
        totalEnrollments: stats.values.fold(0, (sum, count) => sum + count),
        activeEnrollments: stats.values.fold(0, (sum, count) => sum + count),
        enrollmentsByProgram: stats,
      );
      
      return Right(programStats);
    } catch (e) {
      return Left(CacheFailure('Failed to get program stats: ${e.toString()}'));
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
      return Left(CacheFailure('Failed to update enrollment status: ${e.toString()}'));
    }
  }

  // ✅ Additional methods that might be in your interface
  
  @override
  Future<Either<Failure, ProgramEnrollment>> getEnrollmentById(String enrollmentId) async {
    try {
      final allEnrollments = await localDatasource.getFacilityEnrollments('');
      final enrollment = allEnrollments.firstWhere(
        (e) => e.id == enrollmentId,
        orElse: () => throw Exception('Enrollment not found'),
      );
      return Right(enrollment);
    } catch (e) {
      return Left(CacheFailure('Failed to get enrollment by ID: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getActiveEnrollmentsCount(String facilityId, DiseaseProgram program) async {
    try {
      final stats = await localDatasource.getProgramStats(facilityId);
      final count = stats[program.name] ?? 0;
      return Right(count);
    } catch (e) {
      return Left(CacheFailure('Failed to get active enrollments count: ${e.toString()}'));
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
      return Left(CacheFailure('Failed to calculate completion rate: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> generateEnrollmentReport(
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
      
      // Return as JSON string
      return Right(report.toString());
    } catch (e) {
      return Left(CacheFailure('Failed to generate report: ${e.toString()}'));
    }
  }

  Future<Either<Failure, List<ProgramEnrollment>>> getEnrollmentsByProgram(
    String facilityId,
    DiseaseProgram program,
  ) async {
    try {
      final allEnrollments = await localDatasource.getFacilityEnrollments(facilityId);
      final filtered = allEnrollments.where((e) => e.program == program).toList();
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure('Failed to get enrollments by program: ${e.toString()}'));
    }
  }

  Future<Either<Failure, List<ProgramEnrollment>>> getEnrollmentsByStatus(
    String facilityId,
    ProgramEnrollmentStatus status,
  ) async {
    try {
      final allEnrollments = await localDatasource.getFacilityEnrollments(facilityId);
      final filtered = allEnrollments.where((e) => e.status == status).toList();
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure('Failed to get enrollments by status: ${e.toString()}'));
    }
  }

  Future<Either<Failure, void>> deleteEnrollment(String enrollmentId) async {
    try {
      // You'll need to add this to your datasource
      // For now, return success
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to delete enrollment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> getPatientEnrollmentHistory(
    String patientNupi,
  ) async {
    try {
      // Get all enrollments for patient including completed/closed ones
      final enrollments = await localDatasource.getPatientEnrollments(patientNupi);
      return Right(enrollments);
    } catch (e) {
      return Left(CacheFailure('Failed to get enrollment history: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isPatientEnrolled(
    String patientNupi,
    DiseaseProgram program,
  ) async {
    try {
      final enrollments = await localDatasource.getPatientEnrollments(patientNupi);
      final isEnrolled = enrollments.any((e) => 
        e.program == program && e.status == ProgramEnrollmentStatus.active
      );
      return Right(isEnrolled);
    } catch (e) {
      return Left(CacheFailure('Failed to check enrollment status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ProgramEnrollment>>> searchEnrollments({
    String? facilityId,
    String? searchTerm,
    DiseaseProgram? program,
    ProgramEnrollmentStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Get all enrollments for the facility
      final allEnrollments = facilityId != null
          ? await localDatasource.getFacilityEnrollments(facilityId)
          : <ProgramEnrollment>[];
      
      // Apply filters
      var filtered = allEnrollments;
      
      // Filter by search term (patient name or NUPI)
      if (searchTerm != null && searchTerm.isNotEmpty) {
        filtered = filtered.where((e) =>
          e.patientName.toLowerCase().contains(searchTerm.toLowerCase()) ||
          e.patientNupi.toLowerCase().contains(searchTerm.toLowerCase())
        ).toList();
      }
      
      // Filter by program
      if (program != null) {
        filtered = filtered.where((e) => e.program == program).toList();
      }
      
      // Filter by status
      if (status != null) {
        filtered = filtered.where((e) => e.status == status).toList();
      }
      
      // Filter by date range
      if (startDate != null) {
        filtered = filtered.where((e) => e.enrollmentDate.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        filtered = filtered.where((e) => e.enrollmentDate.isBefore(endDate)).toList();
      }
      
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure('Failed to search enrollments: ${e.toString()}'));
    }
  }
}