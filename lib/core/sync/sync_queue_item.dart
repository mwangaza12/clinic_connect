// lib/core/sync/sync_queue_item.dart

import 'dart:convert';

enum SyncOperation { create, update, delete }

enum SyncEntityType {
  // ── Firestore entities ──────────────────────────────────────
  // Written to FirebaseConfig.facilityDb on sync.
  patient,
  encounter,
  referral,
  programEnrollment,

  // ── HIE Gateway entities ────────────────────────────────────
  // POSTed to the Node.js backend on sync so AfyaChain blocks
  // are minted even when the device was offline at creation time.
  hiePatient,    // POST /api/patients/register
  hieEncounter,  // POST /api/patients/encounter
  hieReferral,   // POST /api/referrals
}

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

  Map<String, dynamic> toMap() => {
        'entity_type': entityType.name,
        'entity_id':   entityId,
        'operation':   operation.name,
        'payload':     jsonEncode(payload),
        'attempts':    attempts,
        'last_error':  lastError,
        'created_at':  createdAt.toIso8601String(),
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) => SyncQueueItem(
        id:         map['id'] as int?,
        entityType: SyncEntityType.values.firstWhere(
            (e) => e.name == map['entity_type']),
        entityId:   map['entity_id'] as String,
        operation:  SyncOperation.values.firstWhere(
            (e) => e.name == map['operation']),
        payload:    Map<String, dynamic>.from(
            jsonDecode(map['payload'] as String)),
        attempts:   map['attempts'] as int? ?? 0,
        lastError:  map['last_error'] as String?,
        createdAt:  DateTime.parse(map['created_at'] as String),
      );
}