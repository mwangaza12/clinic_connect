import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/disease_program.dart';
import '../entities/program_statistics.dart';

abstract class ProgramRepository {
  /// Enroll a patient in a disease program
  Future<Either<Failure, ProgramEnrollment>> enrollPatient(
    ProgramEnrollment enrollment,
  );

  /// Get all enrollments for a facility
  Future<Either<Failure, List<ProgramEnrollment>>> getFacilityEnrollments(
    String facilityId,
  );

  /// Get enrollments for a specific patient
  Future<Either<Failure, List<ProgramEnrollment>>> getPatientEnrollments(
    String patientNupi,
  );

  /// Get program statistics for a facility
  Future<Either<Failure, ProgramStatistics>> getProgramStats(
    String facilityId,
  );

  /// Update enrollment status
  Future<Either<Failure, void>> updateEnrollmentStatus(
    String enrollmentId,
    ProgramEnrollmentStatus status,
    String? outcomeNotes,
  );

  /// Get enrollment by ID
  Future<Either<Failure, ProgramEnrollment>> getEnrollmentById(
    String enrollmentId,
  );

  /// Search enrollments by criteria
  Future<Either<Failure, List<ProgramEnrollment>>> searchEnrollments({
    String? facilityId,
    DiseaseProgram? program,
    ProgramEnrollmentStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? searchTerm,
  });

  /// Get program completion rate
  Future<Either<Failure, double>> getCompletionRate(
    String facilityId,
    DiseaseProgram program,
  );

  /// Get active enrollments count
  Future<Either<Failure, int>> getActiveEnrollmentsCount(
    String facilityId,
    DiseaseProgram program,
  );

  /// Generate enrollment report
  Future<Either<Failure, String>> generateEnrollmentReport(
    String facilityId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Check if patient is already enrolled in a program
  Future<Either<Failure, bool>> isPatientEnrolled(
    String patientNupi,
    DiseaseProgram program,
  );

  /// Get patient's enrollment history
  Future<Either<Failure, List<ProgramEnrollment>>> getPatientEnrollmentHistory(
    String patientNupi,
  );
}