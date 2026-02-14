import 'dart:convert';

enum SyncOperation { create, update, delete }
enum SyncEntityType { patient, encounter, referral }

class SyncQueueItem {
  final int? id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;

  const SyncQueueItem({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.attempts = 0,
    this.lastError,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType.name,
      'entity_id': entityId,
      'operation': operation.name,
      'payload': jsonEncode(payload),
      'attempts': attempts,
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int?,
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == map['entity_type'],
      ),
      entityId: map['entity_id'],
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == map['operation'],
      ),
      payload: Map<String, dynamic>.from(
        jsonDecode(map['payload']),
      ),
      attempts: map['attempts'] ?? 0,
      lastError: map['last_error'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}