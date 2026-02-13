// lib/features/auth/domain/entities/user.dart

class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String facilityId;
  final String facilityName;
  final String? phoneNumber;
  final bool? isActive;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.facilityId,
    required this.facilityName,
    this.phoneNumber,
    this.isActive,
    this.lastLogin,
    this.createdAt,
  });

  // Getters for common checks
  bool get isAdmin => role == 'admin';
  bool get isClinician => role == 'clinician' || role == 'doctor' || role == 'nurse';
  bool get isReceptionist => role == 'receptionist';

  User copyWith({
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
    return User(
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