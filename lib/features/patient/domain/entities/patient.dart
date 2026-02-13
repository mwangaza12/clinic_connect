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

  String get fullName => '$firstName $middleName $lastName'.trim().replaceAll(RegExp(r'\s+'), ' ');
  
  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
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
      id: id ?? this.id,
      nupi: nupi ?? this.nupi,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      county: county ?? this.county,
      subCounty: subCounty ?? this.subCounty,
      ward: ward ?? this.ward,
      village: village ?? this.village,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      facilityId: facilityId ?? this.facilityId,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      nextOfKinName: nextOfKinName ?? this.nextOfKinName,
      nextOfKinPhone: nextOfKinPhone ?? this.nextOfKinPhone,
      nextOfKinRelationship: nextOfKinRelationship ?? this.nextOfKinRelationship,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}