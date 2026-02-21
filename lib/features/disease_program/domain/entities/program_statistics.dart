// lib/features/disease_program/domain/entities/program_statistics.dart

import 'disease_program.dart';

class ProgramStatistics {
  final String facilityId;
  final Map<DiseaseProgram, int> enrollmentsByProgram;
  final Map<ProgramEnrollmentStatus, int> enrollmentsByStatus;
  final int totalActiveEnrollments;
  final int totalCompletedEnrollments;
  final Map<DiseaseProgram, double> completionRates;
  final Map<DiseaseProgram, int> activeEnrollmentsByProgram;
  final Map<DiseaseProgram, int> defaultedEnrollmentsByProgram;
  final DateTime lastUpdated;

  ProgramStatistics({
    required this.facilityId,
    required this.enrollmentsByProgram,
    required this.enrollmentsByStatus,
    required this.totalActiveEnrollments,
    required this.totalCompletedEnrollments,
    required this.completionRates,
    required this.activeEnrollmentsByProgram,
    required this.defaultedEnrollmentsByProgram,
    required this.lastUpdated,
  });

  // Factory constructor for empty statistics
  factory ProgramStatistics.empty(String facilityId) {
    return ProgramStatistics(
      facilityId: facilityId,
      enrollmentsByProgram: {},
      enrollmentsByStatus: {},
      totalActiveEnrollments: 0,
      totalCompletedEnrollments: 0,
      completionRates: {},
      activeEnrollmentsByProgram: {},
      defaultedEnrollmentsByProgram: {},
      lastUpdated: DateTime.now(),
    );
  }

  // Helper methods
  int getProgramEnrollmentCount(DiseaseProgram program) {
    return enrollmentsByProgram[program] ?? 0;
  }

  int getStatusCount(ProgramEnrollmentStatus status) {
    return enrollmentsByStatus[status] ?? 0;
  }

  double getProgramCompletionRate(DiseaseProgram program) {
    return completionRates[program] ?? 0.0;
  }

  int getActiveProgramEnrollments(DiseaseProgram program) {
    return activeEnrollmentsByProgram[program] ?? 0;
  }

  int getDefaultedProgramEnrollments(DiseaseProgram program) {
    return defaultedEnrollmentsByProgram[program] ?? 0;
  }
}