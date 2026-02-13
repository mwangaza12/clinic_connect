// lib/features/facility/domain/entities/facility.dart

class Facility {
  final String id;
  final String name;
  final String type;
  final String county;
  final String subCounty;
  final bool isActive;
  final DateTime? lastSeen;

  const Facility({
    required this.id,
    required this.name,
    required this.type,
    required this.county,
    required this.subCounty,
    required this.isActive,
    this.lastSeen,
  });

  Facility copyWith({
    String? id,
    String? name,
    String? type,
    String? county,
    String? subCounty,
    bool? isActive,
    DateTime? lastSeen,
  }) {
    return Facility(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      county: county ?? this.county,
      subCounty: subCounty ?? this.subCounty,
      isActive: isActive ?? this.isActive,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}