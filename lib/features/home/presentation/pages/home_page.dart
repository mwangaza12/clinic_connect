import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/pages/patient_list_page.dart';
import '../../../patient/presentation/pages/patient_registration_page.dart';
import '../../../../injection_container.dart';
import 'profile_page.dart';
import '../../../referral/presentation/pages/referrals_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final Color primaryDark = const Color(0xFF1B4332);
  final Color lightBg = const Color(0xFFF8FAFC);

  @override
  void dispose() {
    _pageController.dispose();
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
            return PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              children: [
                _DashboardTab(
                  state: state, 
                  primaryColor: primaryDark, 
                  onSearchClick: () => _navigateToTab(1)
                ),
                BlocProvider(
                  create: (_) => sl<PatientBloc>()..add(const LoadPatientsEvent()),
                  child: const PatientListView(),
                ),
                const _ReferralsTab(),
                ProfilePage(state: state, primaryColor: primaryDark),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator.adaptive());
        },
      ),
      bottomNavigationBar: _buildAnimatedBottomNav(),
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
          const Text('ClinicConnect',
              style: TextStyle(color: Color(0xFF1B4332), fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1)),
          Text('Interoperable EHR System',
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
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
          onPressed: () => _navigateToTab(3), // Go to Profile
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(30)),
      child: const Row(
        children: [
          Icon(Icons.wifi_tethering_rounded, size: 14, color: Color(0xFF166534)),
          SizedBox(width: 6),
          Text("OFFLINE-READY", style: TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAnimatedBottomNav() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
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
      onTap: () => _navigateToTab(index),
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
            Icon(icon, color: isSelected ? primaryDark : Colors.grey[400], size: 26),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isSelected ? 1 : 0,
              child: Text(label, style: TextStyle(color: primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final Authenticated state;
  final Color primaryColor;
  final VoidCallback onSearchClick;

  const _DashboardTab({required this.state, required this.primaryColor, required this.onSearchClick});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.user.facilityName.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(state.user.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(state.user.role.toUpperCase(),
                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
          const Text('Quick Clinical Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          _actionRow(context, Icons.person_add_rounded, 'New Registration', 'Capture NUPI Identification', 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientRegistrationPage()))),
          _actionRow(context, Icons.history_edu_rounded, 'Visit Documentation', 'Clinical Records', () {}),
          _actionRow(context, Icons.search_rounded, 'Search Patient', 'Find by NUPI or Name', onSearchClick),
          const SizedBox(height: 32),
          const Text('Programs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('HIV/ART', Colors.red),
                _chip('NCD/Diabetes', Colors.blue),
                _chip('Hypertension', Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
    ]);
  }

  Widget _actionRow(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primaryColor)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Center(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
    );
  }
}

class _ReferralsTab extends StatelessWidget {
  const _ReferralsTab();
  @override
  Widget build(BuildContext context) {
    return const ReferralsPage();
  }
}