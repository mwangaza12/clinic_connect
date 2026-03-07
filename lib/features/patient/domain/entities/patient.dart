// lib/features/patients/domain/entities/patient.dart

class Patient {
  final String id;
  final String nupi;
  final String firstName;
  final String middleName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final String phoneNumber;
  final String? email;
  final String county;
  final String subCounty;
  final String ward;
  final String village;
  final String? bloodGroup;
  final String facilityId;
  final List<String> allergies;
  final List<String> chronicConditions;
  final String? nextOfKinName;
  final String? nextOfKinPhone;
  final String? nextOfKinRelationship;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Patient({
    required this.id,
    required this.nupi,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.phoneNumber,
    this.email,
    required this.county,
    required this.subCounty,
    required this.ward,
    required this.village,
    this.bloodGroup,
    required this.facilityId,
    required this.allergies,
    required this.chronicConditions,
    this.nextOfKinName,
    this.nextOfKinPhone,
    this.nextOfKinRelationship,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName =>
      '$firstName $middleName $lastName'.trim().replaceAll(RegExp(r'\s+'), ' ');

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  // ── HIE factory ───────────────────────────────────────────────────
  // Builds a Patient from the demographics map returned by
  // HieApiService.verifySecurityAnswer() → patientData.
  //
  // The gateway returns a single 'name' field; we split on the first
  // space so firstName = given name(s), lastName = family name.
  factory Patient.fromHieData({
    required Map<String, dynamic> data,
    required String facilityId,
  }) {
    final now      = DateTime.now();
    final rawName  = data['name']?.toString().trim() ?? '';
    final spaceIdx = rawName.indexOf(' ');
    final firstName = spaceIdx == -1 ? rawName : rawName.substring(0, spaceIdx);
    final lastName  = spaceIdx == -1 ? '' : rawName.substring(spaceIdx + 1).trim();

    // dob arrives as 'yyyy-MM-dd' string from the gateway
    DateTime dob = now;
    try {
      final raw = data['dateOfBirth']?.toString() ?? '';
      if (raw.isNotEmpty) dob = DateTime.parse(raw);
    } catch (_) {}

    return Patient(
      // Use gateway-provided id if present, otherwise generate a
      // deterministic local id that can be reconciled later.
      id:         data['id']?.toString()   ?? _localId(),
      nupi:       data['nupi']?.toString() ?? '',
      firstName:  firstName,
      middleName: '',
      lastName:   lastName,
      gender:     data['gender']?.toString().toLowerCase() ?? 'unknown',
      dateOfBirth: dob,
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      email:       data['email']?.toString(),
      county:      data['county']?.toString()    ?? '',
      subCounty:   data['subCounty']?.toString() ?? '',
      ward:        data['ward']?.toString()      ?? '',
      village:     data['village']?.toString()   ?? '',
      bloodGroup:  data['bloodGroup']?.toString(),
      facilityId:  facilityId,
      allergies:         const [],
      chronicConditions: const [],
      nextOfKinName:         null,
      nextOfKinPhone:        null,
      nextOfKinRelationship: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Fallback id when the HIE record has no id field.
  /// Prefixed so it's easy to identify unreconciled records.
  static String _localId() {
    return 'hie-${DateTime.now().millisecondsSinceEpoch}';
  }

  Patient copyWith({
    String? id,
    String? nupi,
    String? firstName,
    String? middleName,
    String? lastName,
    String? gender,
    DateTime? dateOfBirth,
    String? phoneNumber,
    String? email,
    String? county,
    String? subCounty,
    String? ward,
    String? village,
    String? bloodGroup,
    String? facilityId,
    List<String>? allergies,
    List<String>? chronicConditions,
    String? nextOfKinName,
    String? nextOfKinPhone,
    String? nextOfKinRelationship,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id:           id           ?? this.id,
      nupi:         nupi         ?? this.nupi,
      firstName:    firstName    ?? this.firstName,
      middleName:   middleName   ?? this.middleName,
      lastName:     lastName     ?? this.lastName,
      gender:       gender       ?? this.gender,
      dateOfBirth:  dateOfBirth  ?? this.dateOfBirth,
      phoneNumber:  phoneNumber  ?? this.phoneNumber,
      email:        email        ?? this.email,
      county:       county       ?? this.county,
      subCounty:    subCounty    ?? this.subCounty,
      ward:         ward         ?? this.ward,
      village:      village      ?? this.village,
      bloodGroup:   bloodGroup   ?? this.bloodGroup,
      facilityId:   facilityId   ?? this.facilityId,
      allergies:         allergies         ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      nextOfKinName:         nextOfKinName         ?? this.nextOfKinName,
      nextOfKinPhone:        nextOfKinPhone        ?? this.nextOfKinPhone,
      nextOfKinRelationship: nextOfKinRelationship ?? this.nextOfKinRelationship,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}