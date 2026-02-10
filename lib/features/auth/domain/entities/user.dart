import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final String role;
  final String facilityId;
  final String facilityName;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  List<Object> get props => [id, email, name, role, facilityId, facilityName];
}