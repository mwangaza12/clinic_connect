// lib/features/notifications/presentation/widgets/notification_bell.dart
//
// Drop-in AppBar action widget. Shows a bell icon with a live red badge
// showing unread count. Tapping opens the NotificationsPage.

import 'package:flutter/material.dart';
import '../../data/notification_service.dart';
import '../pages/notifications_page.dart';

class NotificationBell extends StatelessWidget {
  final String facilityId;
  final Color? color;

  const NotificationBell({
    super.key,
    required this.facilityId,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.watchUnreadCount(facilityId),
      builder: (context, snap) {
        final count = snap.data ?? 0;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsPage(facilityId: facilityId),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  count > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  color: color ?? const Color(0xFF1B4332),
                  size: 26,
                ),

                // Badge — only shown when count > 0
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}