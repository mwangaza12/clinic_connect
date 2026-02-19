import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/sync/widgets/sync_status_widget.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  late final DashboardBloc _dashboardBloc;

  final Color primaryDark = const Color(0xFF1B4332);
  final Color lightBg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _dashboardBloc = sl<DashboardBloc>();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dashboardBloc.close();
    super.dispose();
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: _buildAppBar(context),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is Authenticated) {
            return BlocProvider.value(
              value: _dashboardBloc
                ..add(LoadDashboardEvent(state.user.facilityId)),
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  _DashboardTab(
                    state: state,
                    primaryColor: primaryDark,
                    onNavigate: _navigateToTab,
                  ),
                  BlocProvider(
                    create: (_) =>
                        sl<PatientBloc>()..add(const LoadPatientsEvent()),
                    child: const PatientListView(),
                  ),
                  const _ReferralsTab(),
                  ProfilePage(
                    state: state,
                    primaryColor: primaryDark,
                  ),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator.adaptive());
        },
      ),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
              color: Color(0xFF1B4332),
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -1,
            ),
          ),
          Text(
            'Interoperable EHR System',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SyncStatusWidget(),
        ),
        const SizedBox(width: 8),
        // ✅ Notification bell instead of profile icon
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: primaryDark.withOpacity(0.1),
                child: Icon(
                  Icons.notifications_outlined,
                  color: primaryDark,
                  size: 20,
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () => _navigateToTab(2),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ✅ Modern floating bottom navigation
  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _modernNavItem(Icons.dashboard_rounded, 0),
            _modernNavItem(Icons.people_rounded, 1),
            _modernNavItem(Icons.swap_horiz_rounded, 2),
            _modernNavItem(Icons.person_rounded, 3),
          ],
        ),
      ),
    );
  }

  Widget _modernNavItem(IconData icon, int index) {
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _navigateToTab(index),
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryDark.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? primaryDark : Colors.grey[400],
                  size: isSelected ? 28 : 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSelected ? 6 : 0,
                height: 6,
                decoration: BoxDecoration(
                  color: primaryDark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Dashboard Tab
// ─────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  final Authenticated state;
  final Color primaryColor;
  final Function(int) onNavigate;

  const _DashboardTab({
    required this.state,
    required this.primaryColor,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardContent(
      state: state,
      primaryColor: primaryColor,
      onNavigate: onNavigate,
    );
  }
}

// ─────────────────────────────────────────
// Dashboard Content
// ─────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final Authenticated state;
  final Color primaryColor;
  final Function(int) onNavigate;

  const _DashboardContent({
    required this.state,
    required this.primaryColor,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () async {
        context
            .read<DashboardBloc>()
            .add(RefreshDashboardEvent(state.user.facilityId));
        await Future.delayed(const Duration(milliseconds: 800));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Card ───────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.user.facilityName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.user.role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<DashboardBloc, DashboardState>(
                    builder: (context, dashState) {
                      if (dashState is DashboardLoaded) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _miniStat(
                              '${dashState.stats.totalPatients}',
                              'Patients',
                            ),
                            _miniStat(
                              '${dashState.stats.todayVisits}',
                              'Today',
                            ),
                            _miniStat(
                              '${dashState.stats.pendingReferrals}',
                              'Referrals',
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _miniStat('...', 'Patients'),
                          _miniStat('...', 'Today'),
                          _miniStat('...', 'Referrals'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── Quick Actions ─────────────────────
            const Text(
              'Quick Clinical Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            _actionRow(
              context,
              Icons.person_add_rounded,
              'New Registration',
              'Capture NUPI Identification',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PatientRegistrationPage(),
                ),
              ),
            ),
            _actionRow(
              context,
              Icons.history_edu_rounded,
              'Visit Documentation',
              'Comprehensive Clinical Records',
              () => onNavigate(1),
            ),
            _actionRow(
              context,
              Icons.send_rounded,
              'Inter-facility Referral',
              'FHIR R4 Compliant Transfer',
              () => onNavigate(2),
            ),
            _actionRow(
              context,
              Icons.manage_search_rounded,
              'Search Local Patients',
              'Find by Name or NUPI',
              () => onNavigate(1),
            ),
            _actionRow(
              context,
              Icons.travel_explore_rounded,
              'Cross-Facility Lookup',
              'Search Shared Patient Index',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NupiLookupPage(),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ─── Today's Encounters ────────────────
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, dashState) {
                if (dashState is! DashboardLoaded ||
                    dashState.todayEncounters.isEmpty) {
                  return const SizedBox();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Encounters",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...dashState.todayEncounters
                        .map((e) => _buildEncounterCard(e)),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // ─── Programs ──────────────────────────
            const Text(
              'Disease Programs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('HIV/ART', Colors.red),
                  _chip('NCD/Diabetes', Colors.blue),
                  _chip('Hypertension', Colors.orange),
                  _chip('Malaria', Colors.green),
                  _chip('TB', Colors.purple),
                  _chip('MCH', Colors.pink),
                ],
              ),
            ),
            const SizedBox(height: 120), // Extra padding for floating nav
          ],
        ),
      ),
    );
  }

  Widget _buildEncounterCard(Map<String, dynamic> encounter) {
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
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medical_services_rounded,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  encounter['patient_name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  encounter['chief_complaint'] ??
                      encounter['type'] ??
                      'Consultation',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(date),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _actionRow(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 12,
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Referrals Tab
// ─────────────────────────────────────────
class _ReferralsTab extends StatelessWidget {
  const _ReferralsTab();

  @override
  Widget build(BuildContext context) {
    return const ReferralsPage();
  }
}