// TODO Implement this library.
// lib/features/home/presentation/pages/nurse_shell_page.dart
//
// Nurse shell — 3 tabs:
//   0 Triage    → today's triage queue with priority + status management
//   1 Patients  → PatientListView (existing)
//   2 Profile   → ProfilePage (existing)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/sync/widgets/sync_status_widget.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/pages/nupi_lookup_page.dart';
import '../../../patient/presentation/pages/patient_list_page.dart';
import '../../../patient/presentation/pages/patient_registration_page.dart';
import 'profile_page.dart';
import 'shell_widgets.dart';

class NurseShellPage extends StatefulWidget {
  const NurseShellPage({super.key});

  @override
  State<NurseShellPage> createState() => _NurseShellPageState();
}

class _NurseShellPageState extends State<NurseShellPage> {
  int _tab = 0;
  final _pageController = PageController();

  static const _navItems = [
    ShellNavItem(Icons.local_hospital_rounded, Icons.local_hospital_outlined, 'Triage'),
    ShellNavItem(Icons.people_rounded,         Icons.people_outline_rounded,  'Patients'),
    ShellNavItem(Icons.person_rounded,         Icons.person_outline_rounded,  'Profile'),
  ];

  void _goTo(int index) {
    setState(() => _tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = state.user;

        return Scaffold(
          backgroundColor: kBgSlate,
          appBar: _buildAppBar(user.facilityName),
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              NurseTriageTab(user: user, onNavigate: _goTo),
              BlocProvider(
                create: (_) =>
                    sl<PatientBloc>()..add(const LoadPatientsByFacilityEvent()),
                child: const PatientListView(),
              ),
              ProfilePage(state: state, primaryColor: Colors.teal),
            ],
          ),
          bottomNavigationBar: ShellBottomNav(
            items: _navItems,
            current: _tab,
            onTap: _goTo,
            color: Colors.teal,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(String facilityName) {
    final authState = context.read<AuthBloc>().state;
    final facilityId = authState is Authenticated ? authState.user.facilityId : '';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ClinicConnect',
            style: TextStyle(
              color: kPrimaryGreen, fontWeight: FontWeight.w900, fontSize: 20,
            ),
          ),
          Text(facilityName,
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
      actions: [
        const RoleBadge(label: 'NURSE', color: Colors.teal),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SyncStatusWidget(),
        ),
        NotificationBell(facilityId: facilityId),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─── Nurse Triage tab ─────────────────────────────────────────────────────────

class NurseTriageTab extends StatefulWidget {
  final dynamic         user;
  final void Function(int) onNavigate;

  const NurseTriageTab({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  @override
  State<NurseTriageTab> createState() => _NurseTriageTabState();
}

class _NurseTriageTabState extends State<NurseTriageTab> {
  String _statusFilter = 'all';

  Stream<QuerySnapshot> get _queueStream {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));

    var q = FirebaseFirestore.instance
        .collection('triage_queue')
        .where('facility_id', isEqualTo: widget.user.facilityId as String)
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at', isLessThan: Timestamp.fromDate(end));

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    return q.orderBy('created_at').snapshots();
  }

  static const _filters = [
    _FilterOption('All',         'all',              Colors.grey),
    _FilterOption('Waiting',     'waiting',          Colors.orange),
    _FilterOption('In Triage',   'in_triage',        Colors.blue),
    _FilterOption('Ready',       'ready_for_doctor', Colors.green),
    _FilterOption('With Doctor', 'with_doctor',      Colors.purple),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TRIAGE QUEUE',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 10, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(
                widget.user.name as String,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900),
              ),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        // Quick action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _QuickActionCard(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Register\nPatient',
                color: Colors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const PatientRegistrationPage())),
              ),
              const SizedBox(width: 12),
              _QuickActionCard(
                icon: Icons.travel_explore_rounded,
                label: 'Lookup\nPatient',
                color: Colors.indigo,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NupiLookupPage())),
              ),
              const SizedBox(width: 12),
              _QuickActionCard(
                icon: Icons.people_rounded,
                label: 'Patient\nList',
                color: kPrimaryGreen,
                onTap: () => widget.onNavigate(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _filters.map((f) {
              final selected = _statusFilter == f.value;
              return GestureDetector(
                onTap: () => setState(() => _statusFilter = f.value),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? f.color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? f.color : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    f.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Queue list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _queueStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }
              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Queue is empty',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Patients added via check-in appear here',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return TriageQueueCard(id: docs[i].id, data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Triage queue card ────────────────────────────────────────────────────────

class TriageQueueCard extends StatelessWidget {
  final String             id;
  final Map<String, dynamic> data;

  const TriageQueueCard({super.key, required this.id, required this.data});

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical': return Colors.red;
      case 'high':     return Colors.orange;
      case 'medium':   return Colors.blue;
      default:         return Colors.green;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'waiting':          return Colors.orange;
      case 'in_triage':        return Colors.blue;
      case 'ready_for_doctor': return Colors.green;
      case 'with_doctor':      return Colors.purple;
      default:                 return Colors.grey;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('triage_queue')
        .doc(id)
        .update({
      'status':     newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final priority = data['priority'] as String? ?? 'medium';
    final status   = data['status']   as String? ?? 'waiting';
    final pc       = _priorityColor(priority);
    final sc       = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient name + status badge
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: pc, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['patient_name'] as String? ?? 'Unknown',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                      color: sc, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          // Chief complaint
          if ((data['chief_complaint'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              'CC: ${data['chief_complaint']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],

          const SizedBox(height: 10),

          // Priority badge + action button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                      color: pc, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (status == 'waiting')
                _StatusButton(
                  label: 'Start Triage',
                  color: Colors.blue,
                  onTap: () => _updateStatus('in_triage'),
                ),
              if (status == 'in_triage')
                _StatusButton(
                  label: 'Mark Ready',
                  color: Colors.green,
                  onTap: () => _updateStatus('ready_for_doctor'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Private helpers ──────────────────────────────────────────────────────────

class _StatusButton extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FilterOption {
  final String label;
  final String value;
  final Color  color;
  const _FilterOption(this.label, this.value, this.color);
}