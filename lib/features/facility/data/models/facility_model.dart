// lib/features/facility/data/models/facility_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/facility.dart';

class FacilityModel extends Facility {
  const FacilityModel({
    required super.id,
    required super.name,
    required super.type,
    required super.county,
    required super.subCounty,
    required super.isActive,
    super.lastSeen,
  });

  // FROM FIRESTORE
  factory FacilityModel.fromFirestore(Map<String, dynamic> json) {
    return FacilityModel(
      id: json['id'] ?? json['facility_id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'clinic',
      county: json['county'] ?? '',
      subCounty: json['sub_county'] ?? '',
      isActive: json['is_active'] ?? true,
      lastSeen: json['last_seen'] != null 
          ? (json['last_seen'] as Timestamp).toDate() 
          : null,
    );
  }

  // FROM JSON (API)
  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'clinic',
      county: json['county'] ?? '',
      subCounty: json['sub_county'] ?? '',
      isActive: json['is_active'] ?? true,
      lastSeen: json['last_seen'] != null 
          ? DateTime.parse(json['last_seen']) 
          : null,
    );
  }

  // TO FIRESTORE
  Map<String, dynamic> toFirestore() {
    return {
      'facility_id': id,
      'name': name,
      'type': type,
      'county': county,
      'sub_county': subCounty,
      'is_active': isActive,
      'last_seen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }

  // TO JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'county': county,
      'sub_county': subCounty,
      'is_active': isActive,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  // FROM ENTITY
  factory FacilityModel.fromEntity(Facility entity) {
    return FacilityModel(
      id: entity.id,
      name: entity.name,
      type: entity.type,
      county: entity.county,
      subCounty: entity.subCounty,
      isActive: entity.isActive,
      lastSeen: entity.lastSeen,
    );
  }

  // TO ENTITY
  Facility toEntity() {
    return Facility(
      id: id,
      name: name,
      type: type,
      county: county,
      subCounty: subCounty,
      isActive: isActive,
      lastSeen: lastSeen,
    );
  }
}