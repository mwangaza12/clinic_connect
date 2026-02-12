import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/pages/patient_list_page.dart';
import '../../../patient/presentation/pages/patient_registration_page.dart';
import '../../../../injection_container.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final Color primaryDark = const Color(0xFF1B4332);
  final Color accentGreen = const Color(0xFF2D6A4F);
  final Color lightBg = const Color(0xFFF8FAFC);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
          _buildSyncStatus(),
          const SizedBox(width: 8),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: primaryDark.withOpacity(0.1),
              child: Icon(Icons.person_outline, color: primaryDark, size: 20),
            ),
            onPressed: () => _showLogoutDialog(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is Authenticated) {
            return _buildMainContent(state);
          }
          return const Center(child: CircularProgressIndicator.adaptive());
        },
      ),
      bottomNavigationBar: _buildAnimatedBottomNav(),
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_tethering_rounded,
              size: 14, color: Color(0xFF166534)),
          SizedBox(width: 6),
          Text(
            "OFFLINE-READY",
            style: TextStyle(
              color: Color(0xFF166534),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(Authenticated state) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) => setState(() => _currentIndex = index),
      children: [
        // Tab 1: Dashboard
        _DashboardTab(state: state, primaryColor: primaryDark),

        // Tab 2: Patients - full patient list
        BlocProvider(
          create: (_) => sl<PatientBloc>()..add(const LoadPatientsEvent()),
          child: const PatientListView(),
        ),

        // Tab 3: Referrals
        const _ReferralsTab(),

        // Tab 4: Profile/Settings
        _ProfileTab(state: state, primaryColor: primaryDark),
      ],
    );
  }

  Widget _buildAnimatedBottomNav() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.dashboard_rounded, "Home", 0),
          _navItem(Icons.groups_rounded, "Patients", 1),
          _navItem(Icons.swap_horizontal_circle_rounded, "Referrals", 2),
          _navItem(Icons.person_rounded, "Profile", 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryDark.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryDark : Colors.grey[400],
              size: 26,
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isSelected ? 1 : 0,
              child: Text(
                label,
                style: TextStyle(
                  color: primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Confirm Logout'),
        content: const Text('End your current clinical session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
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

  const _DashboardTab({required this.state, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Stats Card
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniStat('14', 'Waitlist'),
                    _miniStat('82%', 'Sync Rate'),
                    _miniStat('5', 'Referrals'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Quick Clinical Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),

          _buildActionRow(
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
          _buildActionRow(
            context,
            Icons.history_edu_rounded,
            'Visit Documentation',
            'Comprehensive Clinical Records',
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon!')),
            ),
          ),
          _buildActionRow(
            context,
            Icons.send_rounded,
            'Inter-facility Referral',
            'FHIR R4 Compliant Transfer',
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon!')),
            ),
          ),
          _buildActionRow(
            context,
            Icons.search_rounded,
            'Search Patient',
            'Find by NUPI, name or phone',
            () {
              // Navigate to patients tab
              final homeState = context.findAncestorStateOfType<_HomePageState>();
              homeState?._pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
              homeState?.setState(() => homeState._currentIndex = 1);
            },
          ),

          const SizedBox(height: 32),
          const Text(
            'Disease Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _programChip('HIV/ART', Colors.red),
                _programChip('NCD/Diabetes', Colors.blue),
                _programChip('Hypertension', Colors.orange),
                _programChip('Malaria', Colors.green),
                _programChip('TB', Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 100),
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
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionRow(
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
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }

  Widget _programChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.swap_horizontal_circle_outlined,
              size: 64,
              color: Color(0xFF2D6A4F),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Referral Hub',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inter-facility FHIR R4 referrals\ncoming soon',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final Authenticated state;
  final Color primaryColor;

  const _ProfileTab({required this.state, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: primaryColor,
            child: Text(
              state.user.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            state.user.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              state.user.role.toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Info
          _infoCard(Icons.local_hospital_outlined, 'Facility', state.user.facilityName),
          const SizedBox(height: 12),
          _infoCard(Icons.email_outlined, 'Email', state.user.email),
          const SizedBox(height: 12),
          _infoCard(Icons.badge_outlined, 'Facility ID', state.user.facilityId),
          const SizedBox(height: 32),

          // Menu Options
          _menuOption(
            context,
            Icons.settings_outlined,
            'Settings',
            () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming soon!'))),
          ),
          const SizedBox(height: 12),
          _menuOption(
            context,
            Icons.help_outline_rounded,
            'Help & Support',
            () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming soon!'))),
          ),
          const SizedBox(height: 12),
          _menuOption(
            context,
            Icons.info_outline_rounded,
            'About ClinicConnect v1.0.0',
            () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('ClinicConnect v1.0.0'))),
          ),
          const SizedBox(height: 32),

          // Logout
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Confirm Logout'),
                    content: const Text('End your current clinical session?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<AuthBloc>().add(LogoutRequested());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F2),
                foregroundColor: const Color(0xFFE11D48),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2D6A4F), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuOption(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF475569).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF475569), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}