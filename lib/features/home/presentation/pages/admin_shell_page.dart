// lib/features/home/presentation/pages/admin_shell_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';          // ← ADDED
import '../../../../core/sync/widgets/sync_status_widget.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/pages/patient_list_page.dart';
import '../../../referral/presentation/pages/referrals_page.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import 'analytics_page.dart';
import 'profile_page.dart';
import 'shell_widgets.dart';

class AdminShellPage extends StatefulWidget {
  const AdminShellPage({super.key});

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  int _tab = 0;
  final _pageController = PageController();
  late final DashboardBloc _dashBloc;

  static const _navItems = [
    ShellNavItem(Icons.dashboard_rounded,        Icons.dashboard_outlined,       'Dashboard'),
    ShellNavItem(Icons.people_rounded,           Icons.people_outline_rounded,   'Patients'),
    ShellNavItem(Icons.manage_accounts_rounded,  Icons.manage_accounts_outlined, 'Staff'),
    ShellNavItem(Icons.swap_horiz_rounded,       Icons.swap_horiz_outlined,      'Referrals'),
    ShellNavItem(Icons.person_rounded,           Icons.person_outline_rounded,   'Profile'),
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
                AdminDashboardTab(user: user, onNavigate: _goTo),
                BlocProvider(
                  create: (_) =>
                      sl<PatientBloc>()..add(const LoadPatientsByFacilityEvent()),
                  child: const PatientListView(),
                ),
                const AdminStaffTab(),
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
    final authState  = context.read<AuthBloc>().state;
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
        const RoleBadge(label: 'ADMIN', color: Color(0xFF7C3AED)),
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

// ─── Admin Dashboard tab ──────────────────────────────────────────────────────

class AdminDashboardTab extends StatelessWidget {
  final dynamic         user;
  final void Function(int) onNavigate;

  const AdminDashboardTab({
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
              roleLabel: 'FACILITY ADMINISTRATOR',
              roleColor: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 20),

            // Quick Stats
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (_, s) {
                final todayVisits      = s is DashboardLoaded ? s.stats.todayVisits      : 0;
                final pendingReferrals = s is DashboardLoaded ? s.stats.pendingReferrals : 0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickStatItem(
                        label: "Today's Visits",
                        value: '$todayVisits',
                        icon: Icons.today_rounded,
                        color: Colors.teal,
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      _QuickStatItem(
                        label: 'Pending Referrals',
                        value: '$pendingReferrals',
                        icon: Icons.swap_horiz_rounded,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            const SectionLabel('Quick Actions'),
            const SizedBox(height: 12),

            ActionRow(
              icon: Icons.bar_chart_rounded,
              color: Colors.blue,
              title: 'Analytics & Reports',
              subtitle: 'View detailed facility statistics',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsPage()),
              ),
            ),

            ActionRow(
              icon: Icons.person_add_rounded,
              color: const Color(0xFF7C3AED),
              title: 'Manage Staff',
              subtitle: 'Add or update doctor/nurse accounts',
              onTap: () => onNavigate(2),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _QuickStatItem extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final Color   color;

  const _QuickStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}

// ─── Staff Management tab ─────────────────────────────────────────────────────

class AdminStaffTab extends StatefulWidget {
  const AdminStaffTab({super.key});

  @override
  State<AdminStaffTab> createState() => _AdminStaffTabState();
}

class _AdminStaffTabState extends State<AdminStaffTab> {
  String _filter = 'all';
  late Stream<QuerySnapshot> _stream;  // Initialize in initState

  @override
  void initState() {
    super.initState();
    _buildStream();
  }

  void _buildStream() {
    final fid = FacilityInfo().facilityId;
    var q = FirebaseConfig.facilityDb
        .collection('users')
        .where('facility_id', isEqualTo: fid);
    if (_filter != 'all') q = q.where('role', isEqualTo: _filter);
    _stream = q.orderBy('name').snapshots();
  }

  void _setFilter(String f) {
    if (_filter == f) return;
    setState(() {
      _filter = f;
      _buildStream();  // Rebuild the stream with new filter
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: ['all', 'doctor', 'nurse', 'admin'].map((r) {
              final selected = _filter == r;
              return GestureDetector(
                onTap: () => _setFilter(r),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? kPrimaryGreen : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r == 'all' ? 'All' : r[0].toUpperCase() + r.substring(1),
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            key: ValueKey(_filter), // Add key to force rebuild when filter changes
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 12),
                      Text(
                        'Error loading staff',
                        style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == docs.length) {
                    return OutlinedButton.icon(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddStaffSheet(),
                      ),
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add Staff Member'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryGreen,
                        side: BorderSide(color: kPrimaryGreen.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                  final data = docs[i].data() as Map<String, dynamic>;
                  return StaffCard(data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
// ─── Staff card ───────────────────────────────────────────────────────────────

class StaffCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const StaffCard({super.key, required this.data});

  Color _roleColor(String role) {
    switch (role) {
      case 'doctor': return Colors.blue;
      case 'nurse':  return Colors.teal;
      case 'admin':  return const Color(0xFF7C3AED);
      default:       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role   = data['role']      as String? ?? 'staff';
    final active = data['is_active'] as bool?   ?? true;
    final color  = _roleColor(role);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Text(
              (data['name'] as String? ?? '?')[0].toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name']  as String? ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(data['email'] as String? ?? '—',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(role.toUpperCase(),
                    style: TextStyle(
                        color: color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text(
                active ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: active ? Colors.green[700] : Colors.red[400],
                  fontSize: 11, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add staff bottom sheet ───────────────────────────────────────────────────

class AddStaffSheet extends StatefulWidget {
  const AddStaffSheet({super.key});

  @override
  State<AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<AddStaffSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _name         = TextEditingController();
  final _email        = TextEditingController();
  final _password     = TextEditingController();
  final _adminPassword = TextEditingController(); // to re-sign-in admin after creating user
  String  _role       = 'doctor';
  bool    _busy       = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _adminPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });

    // Save admin credentials before creating the new user —
    // Firebase Auth's createUserWithEmailAndPassword signs you IN as
    // the new user, which would log the admin out. We re-sign in after.
    final adminEmail    = FirebaseConfig.auth.currentUser?.email ?? '';
    final adminPassword = _adminPassword.text.trim();

    try {
      // 1. Create Firebase Auth account for the new staff member
      final credential = await FirebaseConfig.auth
          .createUserWithEmailAndPassword(
        email:    _email.text.trim().toLowerCase(),
        password: _password.text.trim(),
      );
      final uid = credential.user!.uid;

      // 2. Write Firestore profile using the Auth UID as document ID
      //    Login reads: facilityDb.collection('users').doc(uid).get()
      //    so the document ID MUST be the UID.
      await FirebaseConfig.facilityDb
          .collection('users')
          .doc(uid)
          .set({
        'id':            uid,
        'name':          _name.text.trim(),
        'email':         _email.text.trim().toLowerCase(),
        'role':          _role,
        'facility_id':   FacilityInfo().facilityId,
        'facility_name': FacilityInfo().facilityName,
        'is_active':     true,
        'created_at':    FieldValue.serverTimestamp(),
        'updated_at':    FieldValue.serverTimestamp(),
      });

      // 3. Sign back in as the admin so they stay logged in
      if (adminEmail.isNotEmpty && adminPassword.isNotEmpty) {
        await FirebaseConfig.auth.signInWithEmailAndPassword(
          email:    adminEmail,
          password: adminPassword,
        );
      }

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'An account with this email already exists.';
          break;
        case 'weak-password':
          msg = 'Password must be at least 6 characters.';
          break;
        case 'invalid-email':
          msg = 'Please enter a valid email address.';
          break;
        default:
          msg = e.message ?? 'Failed to create account.';
      }
      setState(() { _error = msg; _busy = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Staff Member',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'A login account will be created for this staff member.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              _field(_name,     'Full Name',               Icons.person_outline),
              const SizedBox(height: 12),
              _field(_email,    'Staff Email',              Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(_password, 'Temporary Password',       Icons.lock_outline,
                  obscure: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: _deco('Role', Icons.badge_outlined),
                items: const [
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'nurse',  child: Text('Nurse')),
                  DropdownMenuItem(value: 'admin',  child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Your password (to stay logged in after creating the account)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              _field(_adminPassword, 'Your Password', Icons.admin_panel_settings_outlined,
                  obscure: true),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    bool obscure = false,
  }) {
    return TextFormField(
      controller:  c,
      obscureText: obscure,
      keyboardType: type,
      decoration: _deco(label, icon),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kPrimaryGreen),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryGreen, width: 2),
      ),
    );
  }
}