class ProgramStatistics {
  final int totalEnrollments;
  final int activeEnrollments;
  final int completedEnrollments;
  final int defaultedEnrollments;
  final Map<String, int> enrollmentsByProgram;
  final Map<String, int> enrollmentsByStatus;
  final double completionRate;

  const ProgramStatistics({
    required this.totalEnrollments,
    required this.activeEnrollments,
    required this.completedEnrollments,
    required this.defaultedEnrollments,
    required this.enrollmentsByProgram,
    required this.enrollmentsByStatus,
    required this.completionRate,
  });

  ProgramStatistics copyWith({
    int? totalEnrollments,
    int? activeEnrollments,
    int? completedEnrollments,
    int? defaultedEnrollments,
    Map<String, int>? enrollmentsByProgram,
    Map<String, int>? enrollmentsByStatus,
    double? completionRate,
  }) {
    return ProgramStatistics(
      totalEnrollments: totalEnrollments ?? this.totalEnrollments,
      activeEnrollments: activeEnrollments ?? this.activeEnrollments,
      completedEnrollments: completedEnrollments ?? this.completedEnrollments,
      defaultedEnrollments: defaultedEnrollments ?? this.defaultedEnrollments,
      enrollmentsByProgram: enrollmentsByProgram ?? this.enrollmentsByProgram,
      enrollmentsByStatus: enrollmentsByStatus ?? this.enrollmentsByStatus,
      completionRate: completionRate ?? this.completionRate,
    );
  }
}