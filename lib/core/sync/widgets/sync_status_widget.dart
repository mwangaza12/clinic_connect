import 'package:flutter/material.dart';
import '../sync_manager.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncManager().syncStatus,
      initialData: SyncManager().currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) return const SizedBox();

        if (status.isSyncing) {
          return _chip(
            icon: const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFF1D4ED8),
              ),
            ),
            label: 'Syncing...',
            bgColor: const Color(0xFFEFF6FF),
            textColor: const Color(0xFF1D4ED8),
          );
        }

        if (status.pendingCount > 0) {
          return GestureDetector(
            onTap: () => SyncManager().syncNow(),
            child: _chip(
              icon: const Icon(
                Icons.cloud_upload_outlined,
                size: 12,
                color: Color(0xFFD97706),
              ),
              label: '${status.pendingCount} pending',
              bgColor: const Color(0xFFFFFBEB),
              textColor: const Color(0xFFD97706),
            ),
          );
        }

        if (status.lastError != null) {
          return GestureDetector(
            onTap: () => SyncManager().syncNow(),
            child: _chip(
              icon: const Icon(
                Icons.sync_problem_rounded,
                size: 12,
                color: Color(0xFFDC2626),
              ),
              label: 'Sync failed — tap to retry',
              bgColor: const Color(0xFFFEF2F2),
              textColor: const Color(0xFFDC2626),
            ),
          );
        }

        // All synced
        return _chip(
          icon: const Icon(
            Icons.cloud_done_rounded,
            size: 12,
            color: Color(0xFF166534),
          ),
          label: 'All synced',
          bgColor: const Color(0xFFDCFCE7),
          textColor: const Color(0xFF166534),
        );
      },
    );
  }

  Widget _chip({
    required Widget icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}