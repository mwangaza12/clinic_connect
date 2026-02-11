import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/patient.dart';

class PatientModel extends Patient {
  const PatientModel({
    required super.id,
    required super.nupi,
    required super.firstName,
    required super.middleName,
    required super.lastName,
    required super.gender,
    required super.dateOfBirth,
    required super.phoneNumber,
    super.email,
    required super.county,
    required super.subCounty,
    required super.ward,
    required super.village,
    super.bloodGroup,
    required super.allergies,
    required super.chronicConditions,
    super.nextOfKinName,
    super.nextOfKinPhone,
    super.nextOfKinRelationship,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? '',
      nupi: json['nupi'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'] ?? '',
      lastName: json['last_name'] ?? '',
      gender: json['gender'] ?? '',
      dateOfBirth: (json['date_of_birth'] as Timestamp).toDate(),
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      county: json['county'] ?? '',
      subCounty: json['sub_county'] ?? '',
      ward: json['ward'] ?? '',
      village: json['village'] ?? '',
      bloodGroup: json['blood_group'],
      allergies: List<String>.from(json['allergies'] ?? []),
      chronicConditions: List<String>.from(json['chronic_conditions'] ?? []),
      nextOfKinName: json['next_of_kin_name'],
      nextOfKinPhone: json['next_of_kin_phone'],
      nextOfKinRelationship: json['next_of_kin_relationship'],
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nupi': nupi,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': Timestamp.fromDate(dateOfBirth),
      'phone_number': phoneNumber,
      'email': email,
      'county': county,
      'sub_county': subCounty,
      'ward': ward,
      'village': village,
      'blood_group': bloodGroup,
      'allergies': allergies,
      'chronic_conditions': chronicConditions,
      'next_of_kin_name': nextOfKinName,
      'next_of_kin_phone': nextOfKinPhone,
      'next_of_kin_relationship': nextOfKinRelationship,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  factory PatientModel.fromEntity(Patient patient) {
    return PatientModel(
      id: patient.id,
      nupi: patient.nupi,
      firstName: patient.firstName,
      middleName: patient.middleName,
      lastName: patient.lastName,
      gender: patient.gender,
      dateOfBirth: patient.dateOfBirth,
      phoneNumber: patient.phoneNumber,
      email: patient.email,
      county: patient.county,
      subCounty: patient.subCounty,
      ward: patient.ward,
      village: patient.village,
      bloodGroup: patient.bloodGroup,
      allergies: patient.allergies,
      chronicConditions: patient.chronicConditions,
      nextOfKinName: patient.nextOfKinName,
      nextOfKinPhone: patient.nextOfKinPhone,
      nextOfKinRelationship: patient.nextOfKinRelationship,
      createdAt: patient.createdAt,
      updatedAt: patient.updatedAt,
    );
  }
}