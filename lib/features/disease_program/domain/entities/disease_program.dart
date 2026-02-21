// lib/features/disease_program/domain/entities/disease_program.dart

enum DiseaseProgram {
  hivArt('HIV/ART', 'Antiretroviral Therapy'),
  ncdDiabetes('NCD/Diabetes', 'Non-Communicable Diseases - Diabetes'),
  hypertension('Hypertension', 'Blood Pressure Management'),
  malaria('Malaria', 'Malaria Treatment Protocol'),
  tb('TB', 'Tuberculosis Treatment'),
  mch('MCH', 'Maternal & Child Health');

  final String code;
  final String name;
  const DiseaseProgram(this.code, this.name);
}

enum ProgramEnrollmentStatus {
  active,
  completed,
  defaulted,
  transferred,
  died
}

// Program Enrollment Entity
class ProgramEnrollment {
  final String id;
  final String patientNupi;
  final String patientName;
  final String facilityId;
  final DiseaseProgram program;
  final ProgramEnrollmentStatus status;
  final DateTime enrollmentDate;
  final DateTime? completionDate;
  final String? outcomeNotes;
  final Map<String, dynamic>? programSpecificData; // JSON for program-specific fields
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProgramEnrollment({
    required this.id,
    required this.patientNupi,
    required this.patientName,
    required this.facilityId,
    required this.program,
    required this.status,
    required this.enrollmentDate,
    this.completionDate,
    this.outcomeNotes,
    this.programSpecificData,
    required this.createdAt,
    this.updatedAt,
  });

  ProgramEnrollment copyWith({
    String? id,
    String? patientNupi,
    String? patientName,
    String? facilityId,
    DiseaseProgram? program,
    ProgramEnrollmentStatus? status,
    DateTime? enrollmentDate,
    DateTime? completionDate,
    String? outcomeNotes,
    Map<String, dynamic>? programSpecificData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProgramEnrollment(
      id: id ?? this.id,
      patientNupi: patientNupi ?? this.patientNupi,
      patientName: patientName ?? this.patientName,
      facilityId: facilityId ?? this.facilityId,
      program: program ?? this.program,
      status: status ?? this.status,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      completionDate: completionDate ?? this.completionDate,
      outcomeNotes: outcomeNotes ?? this.outcomeNotes,
      programSpecificData: programSpecificData ?? this.programSpecificData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// HIV/ART Specific Data Model
class HivArtData {
  final DateTime? hivDiagnosisDate;
  final String? whoStage; // Stage 1, 2, 3, 4
  final double? baselineCd4Count;
  final double? currentCd4Count;
  final String? arvRegimen; // e.g., "TDF/3TC/DTG"
  final DateTime? arvStartDate;
  final String? viralLoadStatus; // Suppressed, Detectable, Pending
  final double? lastViralLoad;
  final DateTime? lastViralLoadDate;
  final DateTime? nextAppointmentDate;
  final bool? onTbProphylaxis;
  final bool? onCotrimoxazole;

  const HivArtData({
    this.hivDiagnosisDate,
    this.whoStage,
    this.baselineCd4Count,
    this.currentCd4Count,
    this.arvRegimen,
    this.arvStartDate,
    this.viralLoadStatus,
    this.lastViralLoad,
    this.lastViralLoadDate,
    this.nextAppointmentDate,
    this.onTbProphylaxis,
    this.onCotrimoxazole,
  });

  Map<String, dynamic> toJson() => {
    'hivDiagnosisDate': hivDiagnosisDate?.toIso8601String(),
    'whoStage': whoStage,
    'baselineCd4Count': baselineCd4Count,
    'currentCd4Count': currentCd4Count,
    'arvRegimen': arvRegimen,
    'arvStartDate': arvStartDate?.toIso8601String(),
    'viralLoadStatus': viralLoadStatus,
    'lastViralLoad': lastViralLoad,
    'lastViralLoadDate': lastViralLoadDate?.toIso8601String(),
    'nextAppointmentDate': nextAppointmentDate?.toIso8601String(),
    'onTbProphylaxis': onTbProphylaxis,
    'onCotrimoxazole': onCotrimoxazole,
  };

  factory HivArtData.fromJson(Map<String, dynamic> json) => HivArtData(
    hivDiagnosisDate: json['hivDiagnosisDate'] != null ? DateTime.parse(json['hivDiagnosisDate']) : null,
    whoStage: json['whoStage'],
    baselineCd4Count: json['baselineCd4Count']?.toDouble(),
    currentCd4Count: json['currentCd4Count']?.toDouble(),
    arvRegimen: json['arvRegimen'],
    arvStartDate: json['arvStartDate'] != null ? DateTime.parse(json['arvStartDate']) : null,
    viralLoadStatus: json['viralLoadStatus'],
    lastViralLoad: json['lastViralLoad']?.toDouble(),
    lastViralLoadDate: json['lastViralLoadDate'] != null ? DateTime.parse(json['lastViralLoadDate']) : null,
    nextAppointmentDate: json['nextAppointmentDate'] != null ? DateTime.parse(json['nextAppointmentDate']) : null,
    onTbProphylaxis: json['onTbProphylaxis'],
    onCotrimoxazole: json['onCotrimoxazole'],
  );
}

// Diabetes Specific Data Model
class DiabetesData {
  final String? diabetesType; // Type 1, Type 2, Gestational
  final DateTime? diagnosisDate;
  final double? hba1c; // Glycated hemoglobin
  final double? fastingBloodSugar;
  final double? randomBloodSugar;
  final String? medication; // e.g., "Metformin 500mg BD"
  final bool? onInsulin;
  final String? insulinRegimen;
  final String? complications; // Retinopathy, Neuropathy, Nephropathy
  final DateTime? lastFootExam;
  final DateTime? lastEyeExam;
  final DateTime? nextAppointmentDate;

  const DiabetesData({
    this.diabetesType,
    this.diagnosisDate,
    this.hba1c,
    this.fastingBloodSugar,
    this.randomBloodSugar,
    this.medication,
    this.onInsulin,
    this.insulinRegimen,
    this.complications,
    this.lastFootExam,
    this.lastEyeExam,
    this.nextAppointmentDate,
  });

  Map<String, dynamic> toJson() => {
    'diabetesType': diabetesType,
    'diagnosisDate': diagnosisDate?.toIso8601String(),
    'hba1c': hba1c,
    'fastingBloodSugar': fastingBloodSugar,
    'randomBloodSugar': randomBloodSugar,
    'medication': medication,
    'onInsulin': onInsulin,
    'insulinRegimen': insulinRegimen,
    'complications': complications,
    'lastFootExam': lastFootExam?.toIso8601String(),
    'lastEyeExam': lastEyeExam?.toIso8601String(),
    'nextAppointmentDate': nextAppointmentDate?.toIso8601String(),
  };

  factory DiabetesData.fromJson(Map<String, dynamic> json) => DiabetesData(
    diabetesType: json['diabetesType'],
    diagnosisDate: json['diagnosisDate'] != null ? DateTime.parse(json['diagnosisDate']) : null,
    hba1c: json['hba1c']?.toDouble(),
    fastingBloodSugar: json['fastingBloodSugar']?.toDouble(),
    randomBloodSugar: json['randomBloodSugar']?.toDouble(),
    medication: json['medication'],
    onInsulin: json['onInsulin'],
    insulinRegimen: json['insulinRegimen'],
    complications: json['complications'],
    lastFootExam: json['lastFootExam'] != null ? DateTime.parse(json['lastFootExam']) : null,
    lastEyeExam: json['lastEyeExam'] != null ? DateTime.parse(json['lastEyeExam']) : null,
    nextAppointmentDate: json['nextAppointmentDate'] != null ? DateTime.parse(json['nextAppointmentDate']) : null,
  );
}

// Hypertension Specific Data Model
class HypertensionData {
  final DateTime? diagnosisDate;
  final double? baselineSystolic;
  final double? baselineDiastolic;
  final String? medication; // e.g., "Amlodipine 5mg OD"
  final String? stage; // Stage 1, Stage 2, Crisis
  final String? riskFactors; // Smoking, Obesity, Diabetes
  final DateTime? lastEcg;
  final DateTime? lastEcho;
  final String? complications; // Stroke, Heart failure, CKD
  final DateTime? nextAppointmentDate;

  const HypertensionData({
    this.diagnosisDate,
    this.baselineSystolic,
    this.baselineDiastolic,
    this.medication,
    this.stage,
    this.riskFactors,
    this.lastEcg,
    this.lastEcho,
    this.complications,
    this.nextAppointmentDate,
  });

  Map<String, dynamic> toJson() => {
    'diagnosisDate': diagnosisDate?.toIso8601String(),
    'baselineSystolic': baselineSystolic,
    'baselineDiastolic': baselineDiastolic,
    'medication': medication,
    'stage': stage,
    'riskFactors': riskFactors,
    'lastEcg': lastEcg?.toIso8601String(),
    'lastEcho': lastEcho?.toIso8601String(),
    'complications': complications,
    'nextAppointmentDate': nextAppointmentDate?.toIso8601String(),
  };

  factory HypertensionData.fromJson(Map<String, dynamic> json) => HypertensionData(
    diagnosisDate: json['diagnosisDate'] != null ? DateTime.parse(json['diagnosisDate']) : null,
    baselineSystolic: json['baselineSystolic']?.toDouble(),
    baselineDiastolic: json['baselineDiastolic']?.toDouble(),
    medication: json['medication'],
    stage: json['stage'],
    riskFactors: json['riskFactors'],
    lastEcg: json['lastEcg'] != null ? DateTime.parse(json['lastEcg']) : null,
    lastEcho: json['lastEcho'] != null ? DateTime.parse(json['lastEcho']) : null,
    complications: json['complications'],
    nextAppointmentDate: json['nextAppointmentDate'] != null ? DateTime.parse(json['nextAppointmentDate']) : null,
  );
}

// Malaria Specific Data Model
class MalariaData {
  final DateTime? symptomsStartDate;
  final String? testType; // RDT, Microscopy
  final String? testResult; // P. falciparum, P. vivax, P. malariae, Mixed
  final String? severity; // Uncomplicated, Severe
  final String? treatment; // AL, Quinine, Artesunate
  final String? dosage;
  final int? treatmentDays;
  final DateTime? treatmentStartDate;
  final DateTime? followUpDate;
  final String? outcome; // Cured, Treatment failure, Death

  const MalariaData({
    this.symptomsStartDate,
    this.testType,
    this.testResult,
    this.severity,
    this.treatment,
    this.dosage,
    this.treatmentDays,
    this.treatmentStartDate,
    this.followUpDate,
    this.outcome,
  });

  Map<String, dynamic> toJson() => {
    'symptomsStartDate': symptomsStartDate?.toIso8601String(),
    'testType': testType,
    'testResult': testResult,
    'severity': severity,
    'treatment': treatment,
    'dosage': dosage,
    'treatmentDays': treatmentDays,
    'treatmentStartDate': treatmentStartDate?.toIso8601String(),
    'followUpDate': followUpDate?.toIso8601String(),
    'outcome': outcome,
  };

  factory MalariaData.fromJson(Map<String, dynamic> json) => MalariaData(
    symptomsStartDate: json['symptomsStartDate'] != null ? DateTime.parse(json['symptomsStartDate']) : null,
    testType: json['testType'],
    testResult: json['testResult'],
    severity: json['severity'],
    treatment: json['treatment'],
    dosage: json['dosage'],
    treatmentDays: json['treatmentDays'],
    treatmentStartDate: json['treatmentStartDate'] != null ? DateTime.parse(json['treatmentStartDate']) : null,
    followUpDate: json['followUpDate'] != null ? DateTime.parse(json['followUpDate']) : null,
    outcome: json['outcome'],
  );
}

// TB Specific Data Model
class TbData {
  final DateTime? diagnosisDate;
  final String? tbType; // Pulmonary, Extra-pulmonary
  final String? siteOfDisease; // Lungs, Lymph nodes, Spine, etc.
  final String? tbCategory; // New, Relapse, Treatment failure, MDR-TB
  final String? testType; // GeneXpert, Smear microscopy, Culture
  final String? testResult; // MTB detected, RIF resistance
  final String? treatmentRegimen; // 2RHZE/4RH, MDR regimen
  final DateTime? treatmentStartDate;
  final int? treatmentPhase; // Intensive phase, Continuation phase
  final String? dotProvider; // Directly Observed Therapy provider
  final DateTime? lastSputumTest;
  final String? treatmentOutcome; // Cured, Completed, Failed, Died, Lost to follow-up
  final DateTime? nextAppointmentDate;

  const TbData({
    this.diagnosisDate,
    this.tbType,
    this.siteOfDisease,
    this.tbCategory,
    this.testType,
    this.testResult,
    this.treatmentRegimen,
    this.treatmentStartDate,
    this.treatmentPhase,
    this.dotProvider,
    this.lastSputumTest,
    this.treatmentOutcome,
    this.nextAppointmentDate,
  });

  Map<String, dynamic> toJson() => {
    'diagnosisDate': diagnosisDate?.toIso8601String(),
    'tbType': tbType,
    'siteOfDisease': siteOfDisease,
    'tbCategory': tbCategory,
    'testType': testType,
    'testResult': testResult,
    'treatmentRegimen': treatmentRegimen,
    'treatmentStartDate': treatmentStartDate?.toIso8601String(),
    'treatmentPhase': treatmentPhase,
    'dotProvider': dotProvider,
    'lastSputumTest': lastSputumTest?.toIso8601String(),
    'treatmentOutcome': treatmentOutcome,
    'nextAppointmentDate': nextAppointmentDate?.toIso8601String(),
  };

  factory TbData.fromJson(Map<String, dynamic> json) => TbData(
    diagnosisDate: json['diagnosisDate'] != null ? DateTime.parse(json['diagnosisDate']) : null,
    tbType: json['tbType'],
    siteOfDisease: json['siteOfDisease'],
    tbCategory: json['tbCategory'],
    testType: json['testType'],
    testResult: json['testResult'],
    treatmentRegimen: json['treatmentRegimen'],
    treatmentStartDate: json['treatmentStartDate'] != null ? DateTime.parse(json['treatmentStartDate']) : null,
    treatmentPhase: json['treatmentPhase'],
    dotProvider: json['dotProvider'],
    lastSputumTest: json['lastSputumTest'] != null ? DateTime.parse(json['lastSputumTest']) : null,
    treatmentOutcome: json['treatmentOutcome'],
    nextAppointmentDate: json['nextAppointmentDate'] != null ? DateTime.parse(json['nextAppointmentDate']) : null,
  );
}

// MCH Specific Data Model
class MchData {
  final String? programType; // ANC, PNC, Child Wellness
  final DateTime? lmp; // Last Menstrual Period
  final DateTime? edd; // Expected Date of Delivery
  final int? gravida; // Number of pregnancies
  final int? parity; // Number of deliveries
  final String? antenatalProfile; // Blood group, HIV status, etc.
  final DateTime? lastAncVisit;
  final int? ancVisitNumber;
  final String? hivStatus; // Positive, Negative, Unknown
  final bool? onPmtct; // Prevention of Mother-to-Child Transmission
  final String? deliveryOutcome; // Live birth, Stillbirth
  final DateTime? deliveryDate;
  final String? infantFeedingMethod; // Exclusive breastfeeding, Mixed, Formula
  final DateTime? nextImmunizationDate;
  final String? childGrowthStatus; // Normal, Underweight, Stunted, Wasted

  const MchData({
    this.programType,
    this.lmp,
    this.edd,
    this.gravida,
    this.parity,
    this.antenatalProfile,
    this.lastAncVisit,
    this.ancVisitNumber,
    this.hivStatus,
    this.onPmtct,
    this.deliveryOutcome,
    this.deliveryDate,
    this.infantFeedingMethod,
    this.nextImmunizationDate,
    this.childGrowthStatus,
  });

  Map<String, dynamic> toJson() => {
    'programType': programType,
    'lmp': lmp?.toIso8601String(),
    'edd': edd?.toIso8601String(),
    'gravida': gravida,
    'parity': parity,
    'antenatalProfile': antenatalProfile,
    'lastAncVisit': lastAncVisit?.toIso8601String(),
    'ancVisitNumber': ancVisitNumber,
    'hivStatus': hivStatus,
    'onPmtct': onPmtct,
    'deliveryOutcome': deliveryOutcome,
    'deliveryDate': deliveryDate?.toIso8601String(),
    'infantFeedingMethod': infantFeedingMethod,
    'nextImmunizationDate': nextImmunizationDate?.toIso8601String(),
    'childGrowthStatus': childGrowthStatus,
  };

  factory MchData.fromJson(Map<String, dynamic> json) => MchData(
    programType: json['programType'],
    lmp: json['lmp'] != null ? DateTime.parse(json['lmp']) : null,
    edd: json['edd'] != null ? DateTime.parse(json['edd']) : null,
    gravida: json['gravida'],
    parity: json['parity'],
    antenatalProfile: json['antenatalProfile'],
    lastAncVisit: json['lastAncVisit'] != null ? DateTime.parse(json['lastAncVisit']) : null,
    ancVisitNumber: json['ancVisitNumber'],
    hivStatus: json['hivStatus'],
    onPmtct: json['onPmtct'],
    deliveryOutcome: json['deliveryOutcome'],
    deliveryDate: json['deliveryDate'] != null ? DateTime.parse(json['deliveryDate']) : null,
    infantFeedingMethod: json['infantFeedingMethod'],
    nextImmunizationDate: json['nextImmunizationDate'] != null ? DateTime.parse(json['nextImmunizationDate']) : null,
    childGrowthStatus: json['childGrowthStatus'],
  );
}