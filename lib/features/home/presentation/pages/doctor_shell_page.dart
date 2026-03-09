// TODO Implement this library.
// lib/features/home/presentation/pages/doctor_shell_page.dart
//
// Doctor shell — 5 tabs:
//   0 Dashboard   → clinical quick-actions + today's encounters
//   1 Patients    → PatientListView (existing)
//   2 Encounters  → Firestore-backed encounter list for this facility
//   3 Referrals   → ReferralsPage (existing)
//   4 Profile     → ProfilePage (existing)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/sync/widgets/sync_status_widget.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../disease_program/presentation/bloc/program_bloc.dart';
import '../../../disease_program/presentation/pages/program_dashboard_page.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/pages/nupi_lookup_page.dart';
import '../../../patient/presentation/pages/patient_list_page.dart';
import '../../../patient/presentation/pages/patient_registration_page.dart';
import '../../../referral/presentation/pages/referrals_page.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import 'profile_page.dart';
import 'shell_widgets.dart';

class DoctorShellPage extends StatefulWidget {
  const DoctorShellPage({super.key});

  @override
  State<DoctorShellPage> createState() => _DoctorShellPageState();
}

class _DoctorShellPageState extends State<DoctorShellPage> {
  int _tab = 0;
  final _pageController = PageController();
  late final DashboardBloc _dashBloc;

  static const _navItems = [
    ShellNavItem(Icons.dashboard_rounded,        Icons.dashboard_outlined,         'Dashboard'),
    ShellNavItem(Icons.people_rounded,           Icons.people_outline_rounded,     'Patients'),
    ShellNavItem(Icons.medical_services_rounded, Icons.medical_services_outlined,  'Encounters'),
    ShellNavItem(Icons.swap_horiz_rounded,       Icons.swap_horiz_outlined,        'Referrals'),
    ShellNavItem(Icons.person_rounded,           Icons.person_outline_rounded,     'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _dashBloc = sl<DashboardBloc>();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dashBloc.close();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
          body: BlocProvider.value(
            value: _dashBloc..add(LoadDashboardEvent(user.facilityId)),
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                DoctorDashboardTab(user: user, onNavigate: _goTo),
                BlocProvider(
                  create: (_) =>
                      sl<PatientBloc>()..add(const LoadPatientsByFacilityEvent()),
                  child: const PatientListView(),
                ),
                DoctorEncountersTab(facilityId: user.facilityId),
                const ReferralsPage(),
                ProfilePage(state: state, primaryColor: kPrimaryGreen),
              ],
            ),
          ),
          bottomNavigationBar: ShellBottomNav(
            items: _navItems,
            current: _tab,
            onTap: _goTo,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(String facilityName) {
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
        const RoleBadge(label: 'DOCTOR', color: Colors.blue),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SyncStatusWidget(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─── Doctor Dashboard tab ─────────────────────────────────────────────────────

class DoctorDashboardTab extends StatelessWidget {
  final dynamic         user;
  final void Function(int) onNavigate;

  const DoctorDashboardTab({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kPrimaryGreen,
      onRefresh: () async {
        context.read<DashboardBloc>().add(
          RefreshDashboardEvent(user.facilityId as String),
        );
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardHeaderCard(
              name:      user.name as String,
              facility:  user.facilityName as String,
              roleLabel: 'PHYSICIAN',
              roleColor: Colors.blue,
            ),
            const SizedBox(height: 20),

            // Stats row
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (_, s) {
                final p = s is DashboardLoaded ? '${s.stats.totalPatients}'    : '—';
                final t = s is DashboardLoaded ? '${s.stats.todayVisits}'       : '—';
                final r = s is DashboardLoaded ? '${s.stats.pendingReferrals}' : '—';
                return Row(children: [
                  StatCard(label: 'Patients',  value: p, icon: Icons.people_rounded,    color: Colors.blue),
                  const SizedBox(width: 12),
                  StatCard(label: 'Today',     value: t, icon: Icons.today_rounded,      color: Colors.teal),
                  const SizedBox(width: 12),
                  StatCard(label: 'Referrals', value: r, icon: Icons.swap_horiz_rounded, color: Colors.orange),
                ]);
              },
            ),
            const SizedBox(height: 24),

            const SectionLabel('Clinical Actions'),
            const SizedBox(height: 12),
            ActionRow(
              icon: Icons.person_add_rounded, color: Colors.teal,
              title: 'Register Patient', subtitle: 'Add new patient record',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PatientRegistrationPage())),
            ),
            ActionRow(
              icon: Icons.medical_services_rounded, color: Colors.blue,
              title: 'New Encounter', subtitle: 'Document a clinical visit',
              onTap: () => onNavigate(1),
            ),
            ActionRow(
              icon: Icons.send_rounded, color: Colors.orange,
              title: 'Create Referral', subtitle: 'Transfer to another facility',
              onTap: () => onNavigate(3),
            ),
            ActionRow(
              icon: Icons.travel_explore_rounded, color: Colors.indigo,
              title: 'Cross-Facility Lookup', subtitle: 'Search AfyaNet patient index',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NupiLookupPage())),
            ),
            ActionRow(
              icon: Icons.manage_search_rounded, color: kPrimaryGreen,
              title: 'Search Patients', subtitle: 'Find by name, NUPI or ID',
              onTap: () => onNavigate(1),
            ),
            ActionRow(
              icon: Icons.medical_services_outlined, color: Colors.green,
              title: 'Disease Programs', subtitle: 'Manage disease program enrollments',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => sl<ProgramBloc>(),
                    child: ProgramDashboardPage(facilityId: user.facilityId as String),
                  ))),
            ),
            const SizedBox(height: 24),

            // Today's encounters
            _TodayEncountersSection(),
          ],
        ),
      ),
    );
  }
}

class _TodayEncountersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (_, state) {
        if (state is! DashboardLoaded || state.todayEncounters.isEmpty) {
          return const SizedBox();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel("Today's Encounters"),
                Text(DateFormat('dd MMM').format(DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 12),
            ...state.todayEncounters.map((e) => _EncounterMiniCard(e)),
          ],
        );
      },
    );
  }
}

class _EncounterMiniCard extends StatelessWidget {
  final Map<String, dynamic> encounter;
  const _EncounterMiniCard(this.encounter);

  @override
  Widget build(BuildContext context) {
    final date = encounter['encounter_date'] is Timestamp
        ? (encounter['encounter_date'] as Timestamp).toDate()
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: kPrimaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(encounter['patient_name'] ?? 'Unknown',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  encounter['chief_complaint'] ??
                      encounter['type'] ??
                      'Consultation',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(DateFormat('HH:mm').format(date),
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

// ─── Encounters tab ───────────────────────────────────────────────────────────

class DoctorEncountersTab extends StatelessWidget {
  final String facilityId;
  const DoctorEncountersTab({super.key, required this.facilityId});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('encounters')
      .where('facility_id', isEqualTo: facilityId)
      .orderBy('encounter_date', descending: true)
      .limit(50)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
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
                Icon(Icons.medical_services_outlined,
                    size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No encounters yet',
                    style: TextStyle(
                        color: Colors.grey[500], fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Open a patient to document a clinical visit',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data     = docs[i].data() as Map<String, dynamic>;
            final rawDate  = data['encounter_date'];
            final date     = rawDate is Timestamp
                ? rawDate.toDate()
                : rawDate is String
                    ? DateTime.tryParse(rawDate) ?? DateTime.now()
                    : DateTime.now();
            final type        = data['encounter_type'] as String? ?? 'visit';
            final complaint   = data['chief_complaint'] as String?;
            final patientName = data['patient_name'] as String?;
            final nupi        = data['patient_nupi'] as String? ?? '';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                        color: kPrimaryGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName ?? 'NUPI: $nupi',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          complaint ?? type,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat('dd MMM').format(date),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                      Text(DateFormat('HH:mm').format(date),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFCBD5E1))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}