// lib/features/home/presentation/pages/admin_shell_page.dart
//
// Admin shell — 5 tabs:
//   0 Dashboard   → analytics + quick actions
//   1 Patients    → PatientListView (existing)
//   2 Staff       → Firestore-backed staff list + add sheet
//   3 Referrals   → ReferralsPage (existing)
//   4 Profile     → ProfilePage (existing)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/facility_info.dart';
import '../../../../core/sync/widgets/sync_status_widget.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../disease_program/presentation/bloc/program_bloc.dart';
import '../../../disease_program/presentation/pages/program_dashboard_page.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
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

            // Stats
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (_, s) {
                final p = s is DashboardLoaded ? '${s.stats.totalPatients}'    : '—';
                final t = s is DashboardLoaded ? '${s.stats.todayVisits}'       : '—';
                final r = s is DashboardLoaded ? '${s.stats.pendingReferrals}' : '—';
                return Column(children: [
                  Row(children: [
                    StatCard(label: 'Total Patients',    value: p, icon: Icons.people_rounded,    color: Colors.blue),
                    const SizedBox(width: 12),
                    StatCard(label: "Today's Visits",    value: t, icon: Icons.today_rounded,      color: Colors.teal),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    StatCard(label: 'Pending Referrals', value: r, icon: Icons.swap_horiz_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    StatCard(label: 'Active Staff',      value: '—', icon: Icons.badge_rounded,   color: const Color(0xFF7C3AED)),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: 24),

            const SectionLabel('Administration'),
            const SizedBox(height: 12),
            ActionRow(
              icon: Icons.person_add_rounded, color: const Color(0xFF7C3AED),
              title: 'Add Staff Member', subtitle: 'Create doctor or nurse accounts',
              onTap: () => onNavigate(2),
            ),
            ActionRow(
              icon: Icons.bar_chart_rounded, color: Colors.blue,
              title: 'Analytics & Reports', subtitle: 'Facility performance stats',
              onTap: () => onNavigate(2),
            ),
            ActionRow(
              icon: Icons.person_add_alt_1_rounded, color: Colors.teal,
              title: 'Register Patient', subtitle: 'Add new patient to the system',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PatientRegistrationPage())),
            ),
            ActionRow(
              icon: Icons.travel_explore_rounded, color: Colors.indigo,
              title: 'Cross-Facility Lookup', subtitle: 'Search shared AfyaNet index',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NupiLookupPage())),
            ),
            ActionRow(
              icon: Icons.medical_services_rounded, color: Colors.green,
              title: 'Disease Programs', subtitle: 'Manage enrollments and tracking',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => sl<ProgramBloc>(),
                    child: ProgramDashboardPage(facilityId: user.facilityId as String),
                  ))),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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

  Stream<QuerySnapshot> get _stream {
    final fid = FacilityInfo().facilityId;
    var q = FirebaseFirestore.instance
        .collection('users')
        .where('facility_id', isEqualTo: fid);
    if (_filter != 'all') q = q.where('role', isEqualTo: _filter);
    return q.orderBy('name').snapshots();
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
                onTap: () => setState(() => _filter = r),
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
            stream: _stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }
              final docs = snap.data?.docs ?? [];
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  // Last item is always the Add button
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
    final role   = data['role'] as String? ?? 'staff';
    final active = data['is_active'] as bool? ?? true;
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
                Text(data['name'] as String? ?? '—',
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
  final _formKey  = GlobalKey<FormState>();
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  String  _role   = 'doctor';
  bool    _busy   = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'name':          _name.text.trim(),
        'email':         _email.text.trim().toLowerCase(),
        'role':          _role,
        'facility_id':   FacilityInfo().facilityId,
        'facility_name': FacilityInfo().facilityName,
        'is_active':     true,
        'created_at':    FieldValue.serverTimestamp(),
        'updated_at':    FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
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
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Staff Member',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _field(_name, 'Full Name', Icons.person_outline),
            const SizedBox(height: 12),
            _field(_email, 'Email', Icons.email_outlined,
                type: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_password, 'Temporary Password', Icons.lock_outline,
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
      controller: c,
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