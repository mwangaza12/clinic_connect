// lib/features/patients/data/models/patient_model.dart

import 'dart:convert';
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
    required super.facilityId,
    required super.allergies,
    required super.chronicConditions,
    super.nextOfKinName,
    super.nextOfKinPhone,
    super.nextOfKinRelationship,
    required super.createdAt,
    required super.updatedAt,
  });

  // ─────────────────────────────────────────
  // FROM FIRESTORE (uses Timestamp)
  // ─────────────────────────────────────────
  factory PatientModel.fromFirestore(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? json['patient_id'] ?? '',
      nupi: json['nupi'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'] ?? '',
      lastName: json['last_name'] ?? '',
      gender: json['gender'] ?? '',
      dateOfBirth: (json['date_of_birth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      county: json['county'] ?? '',
      subCounty: json['sub_county'] ?? '',
      ward: json['ward'] ?? '',
      village: json['village'] ?? '',
      bloodGroup: json['blood_group'],
      facilityId: json['facility_id'] ?? '',
      allergies: json['allergies'] != null 
          ? List<String>.from(json['allergies'] as List) 
          : [],
      chronicConditions: json['chronic_conditions'] != null 
          ? List<String>.from(json['chronic_conditions'] as List) 
          : [],
      nextOfKinName: json['next_of_kin_name'],
      nextOfKinPhone: json['next_of_kin_phone'],
      nextOfKinRelationship: json['next_of_kin_relationship'],
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ─────────────────────────────────────────
  // TO FIRESTORE (uses Timestamp)
  // ─────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'patient_id': id,
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
      'facility_id': facilityId,
      'allergies': allergies,
      'chronic_conditions': chronicConditions,
      'next_of_kin_name': nextOfKinName,
      'next_of_kin_phone': nextOfKinPhone,
      'next_of_kin_relationship': nextOfKinRelationship,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  // ─────────────────────────────────────────
  // FROM SQLITE (uses String for dates/lists)
  // ─────────────────────────────────────────
  factory PatientModel.fromSqlite(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? '',
      nupi: json['nupi'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'] ?? '',
      lastName: json['last_name'] ?? '',
      gender: json['gender'] ?? '',
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'] as String?,
      county: json['county'] ?? '',
      subCounty: json['sub_county'] ?? '',
      ward: json['ward'] ?? '',
      village: json['village'] ?? '',
      bloodGroup: json['blood_group'] as String?,
      facilityId: json['facility_id'] ?? '',
      allergies: json['allergies'] != null
          ? List<String>.from(jsonDecode(json['allergies'] as String))
          : [],
      chronicConditions: json['chronic_conditions'] != null
          ? List<String>.from(jsonDecode(json['chronic_conditions'] as String))
          : [],
      nextOfKinName: json['next_of_kin_name'] as String?,
      nextOfKinPhone: json['next_of_kin_phone'] as String?,
      nextOfKinRelationship: json['next_of_kin_relationship'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // ─────────────────────────────────────────
  // TO SQLITE (converts dates/lists to String)
  // ─────────────────────────────────────────
  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'nupi': nupi,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'phone_number': phoneNumber,
      'email': email,
      'county': county,
      'sub_county': subCounty,
      'ward': ward,
      'village': village,
      'blood_group': bloodGroup,
      'facility_id': facilityId,
      'allergies': jsonEncode(allergies),
      'chronic_conditions': jsonEncode(chronicConditions),
      'next_of_kin_name': nextOfKinName,
      'next_of_kin_phone': nextOfKinPhone,
      'next_of_kin_relationship': nextOfKinRelationship,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ─────────────────────────────────────────
  // FROM ENTITY
  // ─────────────────────────────────────────
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
      facilityId: patient.facilityId,
      allergies: patient.allergies,
      chronicConditions: patient.chronicConditions,
      nextOfKinName: patient.nextOfKinName,
      nextOfKinPhone: patient.nextOfKinPhone,
      nextOfKinRelationship: patient.nextOfKinRelationship,
      createdAt: patient.createdAt,
      updatedAt: patient.updatedAt,
    );
  }

  // ─────────────────────────────────────────
  // TO ENTITY
  // ─────────────────────────────────────────
  Patient toEntity() {
    return Patient(
      id: id,
      nupi: nupi,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      gender: gender,
      dateOfBirth: dateOfBirth,
      phoneNumber: phoneNumber,
      email: email,
      county: county,
      subCounty: subCounty,
      ward: ward,
      village: village,
      bloodGroup: bloodGroup,
      facilityId: facilityId,
      allergies: allergies,
      chronicConditions: chronicConditions,
      nextOfKinName: nextOfKinName,
      nextOfKinPhone: nextOfKinPhone,
      nextOfKinRelationship: nextOfKinRelationship,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ─────────────────────────────────────────
  // COPY WITH
  // ─────────────────────────────────────────
  @override
  PatientModel copyWith({
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
    return PatientModel(
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