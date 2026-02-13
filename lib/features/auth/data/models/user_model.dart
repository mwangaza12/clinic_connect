// lib/features/auth/data/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.role,
    required super.facilityId,
    required super.facilityName,
    super.phoneNumber,
    super.isActive,
    super.lastLogin,
    super.createdAt,
  });

  // ─────────────────────────────────────────
  // FROM FIRESTORE (Fixes your error!)
  // ─────────────────────────────────────────
  factory UserModel.fromFirestore(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['user_id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? json['display_name'] ?? '',
      role: json['role'] ?? 'clinician',
      facilityId: json['facility_id'] ?? '',
      facilityName: json['facility_name'] ?? '',
      phoneNumber: json['phone_number'],
      isActive: json['is_active'] ?? true,
      lastLogin: json['last_login'] != null 
          ? (json['last_login'] as Timestamp).toDate() 
          : null,
      createdAt: json['created_at'] != null 
          ? (json['created_at'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // ─────────────────────────────────────────
  // FROM JSON (for API responses)
  // ─────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      facilityId: json['facility_id'] ?? '',
      facilityName: json['facility_name'] ?? '',
      phoneNumber: json['phone_number'],
      isActive: json['is_active'] ?? true,
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  // ─────────────────────────────────────────
  // TO FIRESTORE
  // ─────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': id,
      'email': email,
      'name': name,
      'role': role,
      'facility_id': facilityId,
      'facility_name': facilityName,
      'phone_number': phoneNumber,
      'is_active': isActive,
      'last_login': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'created_at': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  // ─────────────────────────────────────────
  // TO JSON
  // ─────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'facility_id': facilityId,
      'facility_name': facilityName,
      'phone_number': phoneNumber,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // ─────────────────────────────────────────
  // FROM ENTITY
  // ─────────────────────────────────────────
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      facilityId: user.facilityId,
      facilityName: user.facilityName,
      phoneNumber: user.phoneNumber,
      isActive: user.isActive,
      lastLogin: user.lastLogin,
      createdAt: user.createdAt,
    );
  }

  // ─────────────────────────────────────────
  // TO ENTITY
  // ─────────────────────────────────────────
  User toEntity() {
    return User(
      id: id,
      email: email,
      name: name,
      role: role,
      facilityId: facilityId,
      facilityName: facilityName,
      phoneNumber: phoneNumber,
      isActive: isActive ?? true,
      lastLogin: lastLogin,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  // ─────────────────────────────────────────
  // COPY WITH
  // ─────────────────────────────────────────
  @override
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? facilityId,
    String? facilityName,
    String? phoneNumber,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}