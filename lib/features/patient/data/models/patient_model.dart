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

  // ─────────────────────────────────────────────────────────────
  // FROM FIRESTORE
  // ─────────────────────────────────────────────────────────────
  //
  // Two document shapes exist in Firestore:
  //
  // Shape A — HIE / seeded records (camelCase + nested address map)
  // ──────────────────────────────────────────────────────────────
  //   firstName, lastName, middleName, phoneNumber, dateOfBirth (String),
  //   address: { county, subCounty, ward, village },
  //   nupi, gender, facilityId, nationalId, blockIndex, isFederatedRecord
  //   (no top-level id — document ID is used)
  //
  // Shape B — manually registered records (snake_case + flat address)
  // ──────────────────────────────────────────────────────────────
  //   first_name, last_name, …, phone_number, date_of_birth (Timestamp),
  //   county, sub_county, ward, village  (all top-level)
  //   blood_group, next_of_kin_*, allergies, chronic_conditions
  //   id / patient_id
  //
  // The factory resolves both transparently.
  // ─────────────────────────────────────────────────────────────
  factory PatientModel.fromFirestore(Map<String, dynamic> json) {
    // ── Helper: read snake_case OR camelCase ──────────────────
    T? r<T>(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v == null) return null;
      return v as T?;
    }

    // ── Helper: parse date from Timestamp, ISO string, or null ─
    DateTime parseDate(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    // ── Helper: parse list stored as List or null ─────────────
    List<String> parseList(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v == null) return [];
      if (v is List) return List<String>.from(v);
      return [];
    }

    // ── Address resolution ────────────────────────────────────
    // Priority order for each field:
    //   1. Nested address map  (Shape A — HIE / seeded)
    //   2. Flat snake_case     (Shape B — manually registered)
    //   3. Flat camelCase      (future-proof / mixed)
    //   4. Empty string fallback
    final addr = json['address'];
    final addrMap = (addr is Map) ? Map<String, dynamic>.from(addr) : <String, dynamic>{};

    String resolveAddr(String addrKey, String snake, String camel) {
      // 1. Nested map
      final nested = addrMap[addrKey];
      if (nested is String && nested.isNotEmpty) return nested;
      // 2. Flat snake_case
      final flat = json[snake];
      if (flat is String && flat.isNotEmpty) return flat;
      // 3. Flat camelCase
      final flatCamel = json[camel];
      if (flatCamel is String && flatCamel.isNotEmpty) return flatCamel;
      return '';
    }

    return PatientModel(
      // ── Identity ────────────────────────────────────────────
      // Shape A has no 'id' field — the Firestore document ID must be
      // injected by the datasource before calling fromFirestore.
      // Shape B stores it as 'id' or 'patient_id'.
      id:       json['id'] ?? json['patient_id'] ?? '',
      nupi:     json['nupi'] ?? '',

      // ── Name ────────────────────────────────────────────────
      firstName:  r<String>('first_name',  'firstName')  ?? '',
      middleName: r<String>('middle_name', 'middleName') ?? '',
      lastName:   r<String>('last_name',   'lastName')   ?? '',

      // ── Demographics ─────────────────────────────────────────
      gender:      json['gender'] ?? '',
      dateOfBirth: parseDate('date_of_birth', 'dateOfBirth'),
      phoneNumber: r<String>('phone_number', 'phoneNumber') ?? '',
      email:       r<String>('email', 'email'),

      // ── Address (nested map OR flat fields) ───────────────────
      county:    resolveAddr('county',    'county',     'county'),
      subCounty: resolveAddr('subCounty', 'sub_county', 'subCounty'),
      ward:      resolveAddr('ward',      'ward',       'ward'),
      village:   resolveAddr('village',   'village',    'village'),

      // ── Clinical ─────────────────────────────────────────────
      bloodGroup:        r<String>('blood_group', 'bloodGroup'),
      allergies:         parseList('allergies',          'allergies'),
      chronicConditions: parseList('chronic_conditions', 'chronicConditions'),

      // ── Facility ──────────────────────────────────────────────
      facilityId: r<String>('facility_id', 'facilityId') ?? '',

      // ── Next of Kin ───────────────────────────────────────────
      nextOfKinName:         r<String>('next_of_kin_name',         'nextOfKinName'),
      nextOfKinPhone:        r<String>('next_of_kin_phone',        'nextOfKinPhone'),
      nextOfKinRelationship: r<String>('next_of_kin_relationship', 'nextOfKinRelationship'),

      // ── Timestamps ───────────────────────────────────────────
      createdAt: parseDate('created_at', 'createdAt'),
      updatedAt: parseDate('updated_at', 'updatedAt'),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TO FIRESTORE — always writes the canonical snake_case flat shape
  // (Shape B). Old HIE/seeded documents are normalised on first update.
  // ─────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'patient_id':               id,
      'nupi':                     nupi,
      'first_name':               firstName,
      'middle_name':              middleName,
      'last_name':                lastName,
      'gender':                   gender,
      'date_of_birth':            Timestamp.fromDate(dateOfBirth),
      'phone_number':             phoneNumber,
      'email':                    email,
      'county':                   county,
      'sub_county':               subCounty,
      'ward':                     ward,
      'village':                  village,
      'blood_group':              bloodGroup,
      'facility_id':              facilityId,
      'allergies':                allergies,
      'chronic_conditions':       chronicConditions,
      'next_of_kin_name':         nextOfKinName,
      'next_of_kin_phone':        nextOfKinPhone,
      'next_of_kin_relationship': nextOfKinRelationship,
      'created_at':               Timestamp.fromDate(createdAt),
      'updated_at':               Timestamp.fromDate(updatedAt),
    };
  }

  /// Alias kept for callers that expect toJson() (sync queue, etc.)
  Map<String, dynamic> toJson() => toSqlite();

  // ─────────────────────────────────────────────────────────────
  // FROM SQLITE
  // ─────────────────────────────────────────────────────────────
  factory PatientModel.fromSqlite(Map<String, dynamic> json) {
    return PatientModel(
      id:           json['id']           ?? '',
      nupi:         json['nupi']         ?? '',
      firstName:    json['first_name']   ?? '',
      middleName:   json['middle_name']  ?? '',
      lastName:     json['last_name']    ?? '',
      gender:       json['gender']       ?? '',
      dateOfBirth:  DateTime.parse(json['date_of_birth'] as String),
      phoneNumber:  json['phone_number'] ?? '',
      email:        json['email']        as String?,
      county:       json['county']       ?? '',
      subCounty:    json['sub_county']   ?? '',
      ward:         json['ward']         ?? '',
      village:      json['village']      ?? '',
      bloodGroup:   json['blood_group']  as String?,
      facilityId:   json['facility_id']  ?? '',
      allergies: json['allergies'] != null
          ? List<String>.from(jsonDecode(json['allergies'] as String))
          : [],
      chronicConditions: json['chronic_conditions'] != null
          ? List<String>.from(jsonDecode(json['chronic_conditions'] as String))
          : [],
      nextOfKinName:         json['next_of_kin_name']         as String?,
      nextOfKinPhone:        json['next_of_kin_phone']        as String?,
      nextOfKinRelationship: json['next_of_kin_relationship'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TO SQLITE
  // ─────────────────────────────────────────────────────────────
  Map<String, dynamic> toSqlite() {
    return {
      'id':                       id,
      'nupi':                     nupi,
      'first_name':               firstName,
      'middle_name':              middleName,
      'last_name':                lastName,
      'gender':                   gender,
      'date_of_birth':            dateOfBirth.toIso8601String(),
      'phone_number':             phoneNumber,
      'email':                    email,
      'county':                   county,
      'sub_county':               subCounty,
      'ward':                     ward,
      'village':                  village,
      'blood_group':              bloodGroup,
      'facility_id':              facilityId,
      'allergies':                jsonEncode(allergies),
      'chronic_conditions':       jsonEncode(chronicConditions),
      'next_of_kin_name':         nextOfKinName,
      'next_of_kin_phone':        nextOfKinPhone,
      'next_of_kin_relationship': nextOfKinRelationship,
      'created_at':               createdAt.toIso8601String(),
      'updated_at':               updatedAt.toIso8601String(),
    };
  }

  // ─────────────────────────────────────────────────────────────
  // FROM ENTITY
  // ─────────────────────────────────────────────────────────────
  factory PatientModel.fromEntity(Patient patient) {
    return PatientModel(
      id:                    patient.id,
      nupi:                  patient.nupi,
      firstName:             patient.firstName,
      middleName:            patient.middleName,
      lastName:              patient.lastName,
      gender:                patient.gender,
      dateOfBirth:           patient.dateOfBirth,
      phoneNumber:           patient.phoneNumber,
      email:                 patient.email,
      county:                patient.county,
      subCounty:             patient.subCounty,
      ward:                  patient.ward,
      village:               patient.village,
      bloodGroup:            patient.bloodGroup,
      facilityId:            patient.facilityId,
      allergies:             patient.allergies,
      chronicConditions:     patient.chronicConditions,
      nextOfKinName:         patient.nextOfKinName,
      nextOfKinPhone:        patient.nextOfKinPhone,
      nextOfKinRelationship: patient.nextOfKinRelationship,
      createdAt:             patient.createdAt,
      updatedAt:             patient.updatedAt,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TO ENTITY
  // ─────────────────────────────────────────────────────────────
  Patient toEntity() => Patient(
    id:                    id,
    nupi:                  nupi,
    firstName:             firstName,
    middleName:            middleName,
    lastName:              lastName,
    gender:                gender,
    dateOfBirth:           dateOfBirth,
    phoneNumber:           phoneNumber,
    email:                 email,
    county:                county,
    subCounty:             subCounty,
    ward:                  ward,
    village:               village,
    bloodGroup:            bloodGroup,
    facilityId:            facilityId,
    allergies:             allergies,
    chronicConditions:     chronicConditions,
    nextOfKinName:         nextOfKinName,
    nextOfKinPhone:        nextOfKinPhone,
    nextOfKinRelationship: nextOfKinRelationship,
    createdAt:             createdAt,
    updatedAt:             updatedAt,
  );

  // ─────────────────────────────────────────────────────────────
  // COPY WITH
  // ─────────────────────────────────────────────────────────────
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
      id:                    id                    ?? this.id,
      nupi:                  nupi                  ?? this.nupi,
      firstName:             firstName             ?? this.firstName,
      middleName:            middleName            ?? this.middleName,
      lastName:              lastName              ?? this.lastName,
      gender:                gender                ?? this.gender,
      dateOfBirth:           dateOfBirth           ?? this.dateOfBirth,
      phoneNumber:           phoneNumber           ?? this.phoneNumber,
      email:                 email                 ?? this.email,
      county:                county                ?? this.county,
      subCounty:             subCounty             ?? this.subCounty,
      ward:                  ward                  ?? this.ward,
      village:               village               ?? this.village,
      bloodGroup:            bloodGroup            ?? this.bloodGroup,
      facilityId:            facilityId            ?? this.facilityId,
      allergies:             allergies             ?? this.allergies,
      chronicConditions:     chronicConditions     ?? this.chronicConditions,
      nextOfKinName:         nextOfKinName         ?? this.nextOfKinName,
      nextOfKinPhone:        nextOfKinPhone        ?? this.nextOfKinPhone,
      nextOfKinRelationship: nextOfKinRelationship ?? this.nextOfKinRelationship,
      createdAt:             createdAt             ?? this.createdAt,
      updatedAt:             updatedAt             ?? this.updatedAt,
    );
  }
}