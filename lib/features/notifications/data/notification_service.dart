// lib/features/notifications/data/notification_service.dart
//
// Firestore-backed notification service.
//
// Notifications are stored in:
//   /notifications/{facilityId}/items/{notificationId}
//
// This means each facility has its own notification inbox — perfectly
// aligned with the federated architecture. When Facility B sends a
// referral to Facility A, it writes a notification document into
// Facility A's subcollection. Facility A's app listens in real-time.
//
// Notification types:
//   referral_received   — incoming referral from another facility
//   referral_accepted   — a referral you sent was accepted
//   referral_completed  — a referral you sent was completed
//   referral_rejected   — a referral you sent was rejected
//   sync_conflict       — a sync conflict needs clinician review
//   patient_arrived     — referred patient has arrived
//   system              — general system message

import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  referralReceived,
  referralAccepted,
  referralCompleted,
  referralRejected,
  patientArrived,
  syncConflict,
  system,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> metadata; // referralId, patientNupi, etc.

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.metadata,
  });

  factory AppNotification.fromFirestore(
      String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      type: _parseType(data['type'] as String? ?? 'system'),
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      isRead: data['is_read'] as bool? ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': _typeName(type),
      'title': title,
      'body': body,
      'is_read': isRead,
      'created_at': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      metadata: metadata,
    );
  }

  static NotificationType _parseType(String value) {
    switch (value) {
      case 'referral_received':  return NotificationType.referralReceived;
      case 'referral_accepted':  return NotificationType.referralAccepted;
      case 'referral_completed': return NotificationType.referralCompleted;
      case 'referral_rejected':  return NotificationType.referralRejected;
      case 'patient_arrived':    return NotificationType.patientArrived;
      case 'sync_conflict':      return NotificationType.syncConflict;
      default:                   return NotificationType.system;
    }
  }

  static String _typeName(NotificationType type) {
    switch (type) {
      case NotificationType.referralReceived:  return 'referral_received';
      case NotificationType.referralAccepted:  return 'referral_accepted';
      case NotificationType.referralCompleted: return 'referral_completed';
      case NotificationType.referralRejected:  return 'referral_rejected';
      case NotificationType.patientArrived:    return 'patient_arrived';
      case NotificationType.syncConflict:      return 'sync_conflict';
      case NotificationType.system:            return 'system';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Each facility has its own notification inbox
  CollectionReference _inbox(String facilityId) => _db
      .collection('notifications')
      .doc(facilityId)
      .collection('items');

  // ── Real-time stream ─────────────────────────────────────────

  /// Stream of all notifications for a facility, newest first.
  Stream<List<AppNotification>> watchNotifications(String facilityId) {
    return _inbox(facilityId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppNotification.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Stream of unread count only — used for the badge.
  Stream<int> watchUnreadCount(String facilityId) {
    return _inbox(facilityId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> markAsRead(String facilityId, String notificationId) async {
    await _inbox(facilityId).doc(notificationId).update({'is_read': true});
  }

  Future<void> markAllAsRead(String facilityId) async {
    final snap = await _inbox(facilityId)
        .where('is_read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String facilityId, String notificationId) async {
    await _inbox(facilityId).doc(notificationId).delete();
  }

  // ── Send helpers ─────────────────────────────────────────────
  // These are called by the referral flow to notify the receiving facility.

  Future<void> sendReferralReceived({
    required String toFacilityId,
    required String fromFacilityName,
    required String patientName,
    required String patientNupi,
    required String referralId,
    required String reason,
    required String priority,
  }) async {
    await _send(
      facilityId: toFacilityId,
      notification: AppNotification(
        id: '',
        type: NotificationType.referralReceived,
        title: 'New Referral Received',
        body: '$patientName referred from $fromFacilityName — $reason',
        isRead: false,
        createdAt: DateTime.now(),
        metadata: {
          'referral_id': referralId,
          'patient_nupi': patientNupi,
          'patient_name': patientName,
          'from_facility': fromFacilityName,
          'priority': priority,
        },
      ),
    );
  }

  Future<void> sendReferralStatusUpdate({
    required String toFacilityId,
    required String status, // accepted | completed | rejected
    required String patientName,
    required String patientNupi,
    required String referralId,
    required String facilityName,
  }) async {
    final type = status == 'accepted'
        ? NotificationType.referralAccepted
        : status == 'completed'
            ? NotificationType.referralCompleted
            : NotificationType.referralRejected;

    final title = status == 'accepted'
        ? 'Referral Accepted'
        : status == 'completed'
            ? 'Referral Completed'
            : 'Referral Rejected';

    final body = status == 'accepted'
        ? '$facilityName has accepted the referral for $patientName'
        : status == 'completed'
            ? 'Patient $patientName has completed treatment at $facilityName'
            : '$facilityName has rejected the referral for $patientName';

    await _send(
      facilityId: toFacilityId,
      notification: AppNotification(
        id: '',
        type: type,
        title: title,
        body: body,
        isRead: false,
        createdAt: DateTime.now(),
        metadata: {
          'referral_id': referralId,
          'patient_nupi': patientNupi,
          'patient_name': patientName,
          'facility': facilityName,
          'status': status,
        },
      ),
    );
  }

  Future<void> sendSyncConflict({
    required String facilityId,
    required String entityType,
    required String entityId,
    required String note,
  }) async {
    await _send(
      facilityId: facilityId,
      notification: AppNotification(
        id: '',
        type: NotificationType.syncConflict,
        title: 'Sync Conflict Requires Review',
        body: 'A conflict was detected in $entityType record and needs clinician review.',
        isRead: false,
        createdAt: DateTime.now(),
        metadata: {
          'entity_type': entityType,
          'entity_id': entityId,
          'note': note,
        },
      ),
    );
  }

  Future<void> _send({
    required String facilityId,
    required AppNotification notification,
  }) async {
    await _inbox(facilityId).add(notification.toFirestore());
  }
}