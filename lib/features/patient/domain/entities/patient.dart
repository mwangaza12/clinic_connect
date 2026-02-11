import 'package:equatable/equatable.dart';

class Patient extends Equatable {
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
    required this.allergies,
    required this.chronicConditions,
    this.nextOfKinName,
    this.nextOfKinPhone,
    this.nextOfKinRelationship,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $middleName $lastName'.trim();

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  @override
  List<Object?> get props => [
        id,
        nupi,
        firstName,
        middleName,
        lastName,
        gender,
        dateOfBirth,
        phoneNumber,
        email,
        county,
        subCounty,
        ward,
        village,
        bloodGroup,
        allergies,
        chronicConditions,
        nextOfKinName,
        nextOfKinPhone,
        nextOfKinRelationship,
        createdAt,
        updatedAt,
      ];
}