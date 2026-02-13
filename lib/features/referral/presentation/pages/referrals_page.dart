// lib/features/referral/presentation/pages/referrals_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/referral.dart';
import '../bloc/referral_bloc.dart';
import '../bloc/referral_event.dart';
import '../bloc/referral_state.dart';
import 'create_referral_page.dart';
import 'referral_detail_page.dart';

class ReferralsPage extends StatelessWidget {
  const ReferralsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return const SizedBox();

    return BlocProvider(
      create: (_) => sl<ReferralBloc>()
        ..add(LoadReferralsEvent(authState.user.facilityId)),
      child: const ReferralsView(),
    );
  }
}

class ReferralsView extends StatelessWidget {
  const ReferralsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(context),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final authState = context.read<AuthBloc>().state;
          if (authState is! Authenticated) return;

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ReferralBloc>(),
                child: CreateReferralPage(user: authState.user),
              ),
            ),
          );

          if (context.mounted) {
            context
                .read<ReferralBloc>()
                .add(LoadReferralsEvent(authState.user.facilityId));
          }
        },
        backgroundColor: const Color(0xFF2D6A4F),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Referral',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Referrals',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              BlocBuilder<ReferralBloc, ReferralState>(
                builder: (context, state) {
                  if (state is ReferralsLoaded) {
                    final total =
                        state.outgoing.length + state.incoming.length;
                    return Text(
                      '$total total referrals',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                context
                    .read<ReferralBloc>()
                    .add(LoadReferralsEvent(authState.user.facilityId));
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF2D6A4F),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return BlocBuilder<ReferralBloc, ReferralState>(
      builder: (context, state) {
        final activeTab = state is ReferralsLoaded ? state.activeTab : 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _tabButton(
                  context,
                  'Outgoing',
                  Icons.send_rounded,
                  0,
                  activeTab,
                  state is ReferralsLoaded
                      ? state.outgoing.length
                      : 0,
                ),
              ),
              Expanded(
                child: _tabButton(
                  context,
                  'Incoming',
                  Icons.call_received_rounded,
                  1,
                  activeTab,
                  state is ReferralsLoaded
                      ? state.incoming.length
                      : 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabButton(
    BuildContext context,
    String label,
    IconData icon,
    int index,
    int activeTab,
    int count,
  ) {
    final isActive = activeTab == index;
    return GestureDetector(
      onTap: () => context
          .read<ReferralBloc>()
          .add(SwitchReferralTabEvent(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2D6A4F) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.3)
                      : const Color(0xFF2D6A4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? Colors.white
                        : const Color(0xFF2D6A4F),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return BlocBuilder<ReferralBloc, ReferralState>(
      builder: (context, state) {
        if (state is ReferralLoading) {
          return const Center(
            child: CircularProgressIndicator.adaptive(),
          );
        }

        if (state is ReferralError) {
          return _buildError(context, state.message);
        }

        if (state is ReferralsLoaded) {
          final list =
              state.activeTab == 0 ? state.outgoing : state.incoming;

          if (list.isEmpty) return _buildEmpty(state.activeTab);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            itemCount: list.length,
            itemBuilder: (context, index) =>
                _buildReferralCard(context, list[index], state.activeTab),
          );
        }

        // Initial state — show empty outgoing
        return _buildEmpty(0);
      },
    );
  }

  Widget _buildReferralCard(
      BuildContext context, Referral referral, int tabIndex) {
    final priorityColor = _getPriorityColor(referral.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: priorityColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ReferralBloc>(),
                  child: ReferralDetailPage(referral: referral),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        referral.patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _priorityBadge(referral.priority),
                  ],
                ),
                const SizedBox(height: 6),

                // NUPI
                Text(
                  'NUPI: ${referral.patientNupi}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // Facility Route
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FROM',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              referral.fromFacilityName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFF2D6A4F),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'TO',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              referral.toFacilityName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statusBadge(referral.status),
                    Text(
                      DateFormat('dd MMM yyyy').format(referral.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _priorityBadge(ReferralPriority priority) {
    final color = _getPriorityColor(priority);
    // FIXED: Use proper enum value name
    final priorityText = priority == ReferralPriority.normal 
        ? 'ROUTINE' 
        : priority.name.toUpperCase();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priorityText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _statusBadge(ReferralStatus status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(int tabIndex) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tabIndex == 0
                      ? Icons.send_rounded
                      : Icons.call_received_rounded,
                  size: 48,
                  color: const Color(0xFF2D6A4F),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tabIndex == 0
                    ? 'No Outgoing Referrals'
                    : 'No Incoming Referrals',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tabIndex == 0
                    ? 'Create a referral to transfer\na patient to another facility'
                    : 'No referrals have been\nsent to your facility yet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Color(0xFFE11D48),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is Authenticated) {
                    context
                        .read<ReferralBloc>()
                        .add(LoadReferralsEvent(authState.user.facilityId));
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(ReferralPriority priority) {
    switch (priority) {
      case ReferralPriority.normal: // FIXED: Changed from routine to normal
        return const Color(0xFF2D6A4F);
      case ReferralPriority.urgent:
        return const Color(0xFFF59E0B);
      case ReferralPriority.emergency:
        return const Color(0xFFE11D48);
    }
  }

  Color _getStatusColor(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return const Color(0xFFF59E0B);
      case ReferralStatus.accepted:
        return const Color(0xFF6366F1);
      case ReferralStatus.rejected: // FIXED: Changed from inTransit/cancelled
        return const Color(0xFFE11D48);
      case ReferralStatus.completed:
        return const Color(0xFF2D6A4F);
    }
  }
}