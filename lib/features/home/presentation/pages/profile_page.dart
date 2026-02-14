import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../seed/seed_demo_data.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class ProfilePage extends StatelessWidget {
  final Authenticated state;
  final Color primaryColor;

  const ProfilePage({
    super.key,
    required this.state,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Background Gradient Header
        Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),

        // 2. Main Content
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 100),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildFloatingProfile(),
                      const SizedBox(height: 16),

                      _buildSectionTitle(
                          'CLINICAL IDENTITY'),
                      _buildModernItem(
                          Icons.domain_rounded,
                          'Facility',
                          state.user.facilityName),
                      _buildModernItem(
                          Icons.alternate_email_rounded,
                          'Email Address',
                          state.user.email),
                      _buildModernItem(
                          Icons.badge_outlined,
                          'Credential ID',
                          state.user.facilityId),

                      const SizedBox(height: 24),
                      _buildSectionTitle(
                          'SYSTEM PREFERENCES'),
                      _buildActionItem(
                          Icons.security_rounded,
                          'Security & PIN',
                          () {}),
                      _buildActionItem(
                          Icons.language_rounded,
                          'Language Settings',
                          () {}),
                      _buildActionItem(
                          Icons.help_center_outlined,
                          'Clinical Support',
                          () {}),

                      const SizedBox(height: 24),

                      // ✅ Seed Demo Data section
                      _buildSectionTitle(
                          'THESIS DEMO'),
                      _buildSeedButton(context),

                      const SizedBox(height: 48),
                      _buildEnhancedLogout(context),

                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'ClinicConnect v1.2.0 • Build 2026.02',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Seed button — matches your design language
  Widget _buildSeedButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _runSeed(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.science_rounded,
                  size: 20,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seed Demo Data',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const Text(
                      '12 patients • 5 encounters • 4 referrals',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: primaryColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSeed(BuildContext context) async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Seed Demo Data',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This will add 12 patients, 5 encounters and '
          '4 referrals to Firebase.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style:
                  TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4332),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('SEED'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Show progress
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('🌱 Seeding demo data...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      await seedFacilities();
      final patients = await seedPatients();
      await seedEncounters(patients);
      await seedReferrals(patients);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Demo data seeded successfully!'),
            backgroundColor: Color(0xFF2D6A4F),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Seed failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Widget _buildFloatingProfile() {
    return Transform.translate(
      offset: const Offset(0, -45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: primaryColor,
              child: Text(
                state.user.name
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Padding(
            padding:
                const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.user.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  state.user.role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(left: 4, bottom: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildModernItem(
      IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon,
                size: 20,
                color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
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

  Widget _buildActionItem(
      IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon,
                  size: 22,
                  color: const Color(0xFF334155)),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedLogout(BuildContext context) {
    return InkWell(
      onTap: () => _confirmLogout(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded,
                color: Color(0xFFE11D48)),
            SizedBox(width: 12),
            Text(
              'END CLINICAL SESSION',
              style: TextStyle(
                color: Color(0xFFE11D48),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Log out of ClinicConnect? Make sure your '
          'patient records are synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style:
                  TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<AuthBloc>()
                  .add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );
  }
}