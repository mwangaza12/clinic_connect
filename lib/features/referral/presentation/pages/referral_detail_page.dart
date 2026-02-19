// lib/features/referral/presentation/pages/referral_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/referral.dart';
import '../bloc/referral_bloc.dart';
import '../bloc/referral_event.dart';
import '../bloc/referral_state.dart';

class ReferralDetailPage extends StatelessWidget {
  final Referral referral;

  const ReferralDetailPage({super.key, required this.referral});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isReceivingFacility = authState is Authenticated &&
        authState.user.facilityId == referral.toFacilityId;
    final isSendingFacility = authState is Authenticated &&
        authState.user.facilityId == referral.fromFacilityId;

    return BlocListener<ReferralBloc, ReferralState>(
      listener: (context, state) {
        if (state is ReferralUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Referral status updated!'),
              backgroundColor: Color(0xFF2D6A4F),
            ),
          );
          Navigator.pop(context, true); // Return true to trigger reload
        } else if (state is ReferralError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: _getPriorityColor(referral.priority),
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getPriorityColor(referral.priority),
                        _getPriorityColor(referral.priority).withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              _priorityBadge(referral.priority),
                              const SizedBox(width: 8),
                              _statusBadge(referral.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            referral.patientName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'NUPI: ${referral.patientNupi}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Facility Route Card
                  _sectionCard(
                    title: 'Transfer Route',
                    child: Row(
                      children: [
                        Expanded(
                          child: _facilityInfo(
                            'FROM',
                            referral.fromFacilityName,
                            Icons.upload_rounded,
                            const Color(0xFF6366F1),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D6A4F).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF2D6A4F),
                          ),
                        ),
                        Expanded(
                          child: _facilityInfo(
                            'TO',
                            referral.toFacilityName,
                            Icons.download_rounded,
                            const Color(0xFF2D6A4F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timeline
                  _sectionCard(
                    title: 'Timeline',
                    child: Column(
                      children: [
                        _timelineItem(
                          'Referral Created',
                          DateFormat('dd MMM yyyy, HH:mm')
                              .format(referral.createdAt),
                          Icons.send_rounded,
                          const Color(0xFF6366F1),
                          isFirst: true,
                        ),
                        if (referral.acceptedAt != null)
                          _timelineItem(
                            'Accepted',
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(referral.acceptedAt!),
                            Icons.check_circle_rounded,
                            const Color(0xFF2D6A4F),
                          ),
                        if (referral.status == ReferralStatus.inTransit ||
                            referral.status == ReferralStatus.arrived ||
                            referral.status == ReferralStatus.completed)
                          _timelineItem(
                            'Patient In Transit',
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(referral.updatedAt ?? DateTime.now()),
                            Icons.local_shipping_rounded,
                            const Color(0xFF0EA5E9),
                          ),
                        if (referral.status == ReferralStatus.arrived ||
                            referral.status == ReferralStatus.completed)
                          _timelineItem(
                            'Patient Arrived',
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(referral.updatedAt ?? DateTime.now()),
                            Icons.location_on_rounded,
                            const Color(0xFF8B5CF6),
                          ),
                        if (referral.completedAt != null)
                          _timelineItem(
                            'Completed',
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(referral.completedAt!),
                            Icons.task_alt_rounded,
                            const Color(0xFF059669),
                            isLast: true,
                          ),
                        if (referral.rejectedAt != null)
                          _timelineItem(
                            'Rejected',
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(referral.rejectedAt!),
                            Icons.cancel_rounded,
                            const Color(0xFFE11D48),
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Referral Reason
                  _sectionCard(
                    title: 'Referral Reason',
                    child: Text(
                      referral.reason,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Clinical Notes
                  if (referral.clinicalNotes != null) ...[
                    _sectionCard(
                      title: 'Clinical Notes',
                      child: Text(
                        referral.clinicalNotes!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Feedback Notes
                  if (referral.feedbackNotes != null) ...[
                    _sectionCard(
                      title: 'Feedback Notes',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF0EA5E9).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.feedback_outlined,
                              color: Color(0xFF0EA5E9),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                referral.feedbackNotes!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF475569),
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Created By
                  _sectionCard(
                    title: 'Created By',
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF6366F1),
                          child: Text(
                            referral.createdByName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                referral.createdByName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                referral.fromFacilityName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (referral.status != ReferralStatus.completed &&
                      referral.status != ReferralStatus.rejected &&
                      referral.status != ReferralStatus.cancelled)
                    _buildActionButtons(
                        context, isReceivingFacility, isSendingFacility),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isReceivingFacility,
    bool isSendingFacility,
  ) {
    return BlocBuilder<ReferralBloc, ReferralState>(
      builder: (context, state) {
        final isLoading = state is ReferralLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ RECEIVING FACILITY: Accept pending referral
            if (isReceivingFacility &&
                referral.status == ReferralStatus.pending)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => context.read<ReferralBloc>().add(
                          UpdateReferralStatusEvent(
                            referral.id,
                            ReferralStatus.accepted,
                          ),
                        ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Accept Referral'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

            // ✅ RECEIVING FACILITY: Reject pending referral
            if (isReceivingFacility &&
                referral.status == ReferralStatus.pending) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading ? null : () => _showRejectDialog(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject Referral'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],

            // ✅ SENDING FACILITY: Mark as In Transit after acceptance
            if (isSendingFacility &&
                referral.status == ReferralStatus.accepted) ...[
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => context.read<ReferralBloc>().add(
                          UpdateReferralStatusEvent(
                            referral.id,
                            ReferralStatus.inTransit,
                            feedbackNotes: 'Patient dispatched to facility',
                          ),
                        ),
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('Mark as In Transit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],

            // ✅ RECEIVING FACILITY: Confirm patient arrived
            if (isReceivingFacility &&
                referral.status == ReferralStatus.inTransit) ...[
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => context.read<ReferralBloc>().add(
                          UpdateReferralStatusEvent(
                            referral.id,
                            ReferralStatus.arrived,
                            feedbackNotes: 'Patient arrived safely',
                          ),
                        ),
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('Confirm Patient Arrived'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],

            // ✅ RECEIVING FACILITY: Complete referral after arrival
            if (isReceivingFacility &&
                (referral.status == ReferralStatus.accepted ||
                    referral.status == ReferralStatus.arrived)) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    isLoading ? null : () => _showCompleteDialog(context),
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Complete Referral'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],

            // ✅ SENDING FACILITY: Cancel pending referral
            if (isSendingFacility &&
                referral.status == ReferralStatus.pending) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading ? null : () => _showCancelDialog(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Referral'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFF64748B)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context) {
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Referral'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ReferralBloc>().add(
                    UpdateReferralStatusEvent(
                      referral.id,
                      ReferralStatus.rejected,
                      feedbackNotes: feedbackController.text.trim().isEmpty
                          ? 'Rejected by receiving facility'
                          : feedbackController.text.trim(),
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Referral'),
        content: const Text('Are you sure you want to cancel this referral?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ReferralBloc>().add(
                    UpdateReferralStatusEvent(
                      referral.id,
                      ReferralStatus.cancelled,
                      feedbackNotes: 'Cancelled by sending facility',
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64748B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(BuildContext context) {
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Complete Referral'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add feedback notes for the referring facility:'),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Patient outcome, treatment given...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ReferralBloc>().add(
                    UpdateReferralStatusEvent(
                      referral.id,
                      ReferralStatus.completed,
                      feedbackNotes: feedbackController.text.trim().isEmpty
                          ? 'Patient successfully treated'
                          : feedbackController.text.trim(),
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _facilityInfo(String label, String name, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _timelineItem(
    String title,
    String time,
    IconData icon,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _priorityBadge(ReferralPriority priority) {
    final priorityText = priority == ReferralPriority.normal
        ? 'ROUTINE'
        : priority.name.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priorityText,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _statusBadge(ReferralStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getPriorityColor(ReferralPriority priority) {
    switch (priority) {
      case ReferralPriority.normal:
        return const Color(0xFF2D6A4F);
      case ReferralPriority.urgent:
        return const Color(0xFFF59E0B);
      case ReferralPriority.emergency:
        return const Color(0xFFE11D48);
    }
  }
}