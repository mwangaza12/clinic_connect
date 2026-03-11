// lib/features/notifications/presentation/pages/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/notification_service.dart';

class NotificationsPage extends StatelessWidget {
  final String facilityId;

  const NotificationsPage({super.key, required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF1B4332),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1B4332)),
        actions: [
          TextButton(
            onPressed: () =>
                NotificationService.instance.markAllAsRead(facilityId),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: Color(0xFF1B4332),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.instance.watchNotifications(facilityId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final notifications = snap.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B4332).withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 48,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Referrals, sync alerts and updates\nwill appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<AppNotification>>{};
          for (final n in notifications) {
            final key = _dateLabel(n.createdAt);
            grouped.putIfAbsent(key, () => []).add(n);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 4),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...entry.value.map((n) => _NotificationCard(
                        notification: n,
                        facilityId: facilityId,
                      )),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'TODAY';
    if (date == yesterday) return 'YESTERDAY';
    return DateFormat('EEEE, d MMMM').format(dt).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String facilityId;

  const _NotificationCard({
    required this.notification,
    required this.facilityId,
  });

  @override
  Widget build(BuildContext context) {
    final config = _NotificationConfig.from(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.red, size: 24),
      ),
      onDismissed: (_) => NotificationService.instance
          .delete(facilityId, notification.id),
      child: GestureDetector(
        onTap: () {
          if (!notification.isRead) {
            NotificationService.instance
                .markAsRead(facilityId, notification.id);
          }
          _handleTap(context);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white
                : config.color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0xFFE2E8F0)
                  : config.color.withOpacity(0.25),
              width: notification.isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(config.icon, color: config.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              fontSize: 14,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: config.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: config.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            config.label,
                            style: TextStyle(
                              color: config.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),

                    // Metadata preview for referrals
                    if (notification.metadata['patient_name'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(
                              notification.metadata['patient_name'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                            if (notification.metadata['patient_nupi'] != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· ${notification.metadata['patient_nupi']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    // Navigate to referral detail if this is a referral notification
    final referralId = notification.metadata['referral_id'] as String?;
    if (referralId != null) {
      // Navigator.push to referral detail page
      // (wired up once the referral detail page import is confirmed)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening referral $referralId'),
          backgroundColor: const Color(0xFF1B4332),
        ),
      );
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return DateFormat('d MMM').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NotificationConfig {
  final IconData icon;
  final Color color;
  final String label;

  const _NotificationConfig({
    required this.icon,
    required this.color,
    required this.label,
  });

  factory _NotificationConfig.from(NotificationType type) {
    switch (type) {
      case NotificationType.referralReceived:
        return const _NotificationConfig(
          icon: Icons.call_received_rounded,
          color: Color(0xFF2563EB),
          label: 'REFERRAL IN',
        );
      case NotificationType.referralAccepted:
        return const _NotificationConfig(
          icon: Icons.check_circle_outline_rounded,
          color: Color(0xFF16A34A),
          label: 'ACCEPTED',
        );
      case NotificationType.referralCompleted:
        return const _NotificationConfig(
          icon: Icons.task_alt_rounded,
          color: Color(0xFF1B4332),
          label: 'COMPLETED',
        );
      case NotificationType.referralRejected:
        return const _NotificationConfig(
          icon: Icons.cancel_outlined,
          color: Color(0xFFDC2626),
          label: 'REJECTED',
        );
      case NotificationType.patientArrived:
        return const _NotificationConfig(
          icon: Icons.directions_walk_rounded,
          color: Color(0xFF7C3AED),
          label: 'ARRIVED',
        );
      case NotificationType.syncConflict:
        return const _NotificationConfig(
          icon: Icons.sync_problem_rounded,
          color: Color(0xFFD97706),
          label: 'SYNC CONFLICT',
        );
      case NotificationType.system:
        return const _NotificationConfig(
          icon: Icons.info_outline_rounded,
          color: Color(0xFF64748B),
          label: 'SYSTEM',
        );
    }
  }
}