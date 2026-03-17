// lib/features/home/presentation/pages/admin_shell_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';
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
              color: kPrimaryGreen,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            facilityName,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
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
  final dynamic user;
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
              name: user.name as String,
              facility: user.facilityName as String,
              roleLabel: 'FACILITY ADMINISTRATOR',
              roleColor: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 20),

            // Quick Stats
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (_, s) {
                final todayVisits = s is DashboardLoaded ? s.stats.todayVisits : 0;
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
  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

// ─── Staff Management tab (just shows list) ─────────────────────────────────────

class AdminStaffTab extends StatefulWidget {
  const AdminStaffTab({super.key});

  @override
  State<AdminStaffTab> createState() => _AdminStaffTabState();
}

class _AdminStaffTabState extends State<AdminStaffTab> {
  String _filter = 'all';
  late Stream<QuerySnapshot> _stream;

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

  void _refreshStream() {
    _buildStream();
    setState(() {});
  }

  void _setFilter(String f) {
    if (_filter == f) return;
    setState(() {
      _filter = f;
      _buildStream();
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
            key: ValueKey(_filter),
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
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Error loading staff',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
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
                      ).then((refresh) {
                        if (refresh == true) {
                          _refreshStream();
                        }
                      }),
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add Staff Member'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryGreen,
                        side: BorderSide(color: kPrimaryGreen.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _StaffListItem(
                    data: data,
                    documentId: docs[i].id,
                    onRefresh: _refreshStream,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Staff List Item (just shows basic info, tap to go to details) ───────────

class _StaffListItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String documentId;
  final VoidCallback onRefresh;

  const _StaffListItem({
    required this.data,
    required this.documentId,
    required this.onRefresh,
  });

  Color _roleColor(String role) {
    switch (role) {
      case 'doctor': return Colors.blue;
      case 'nurse': return Colors.teal;
      case 'admin': return const Color(0xFF7C3AED);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = data['role'] as String? ?? 'staff';
    final active = data['is_active'] as bool? ?? true;
    final color = _roleColor(role);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () async {
          final shouldRefresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => StaffDetailPage(
                data: data,
                documentId: documentId,
                onRefresh: onRefresh,
              ),
            ),
          );
          
          if (shouldRefresh == true && context.mounted) {
            onRefresh();
          }
        },
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Text(
            (data['name'] as String? ?? '?')[0].toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          data['name'] as String? ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Text(
          data['email'] as String? ?? '—',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── Staff Detail Page (with icon buttons on top and confirmation dialogs) ───

class StaffDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String documentId;
  final VoidCallback onRefresh;

  const StaffDetailPage({
    super.key,
    required this.data,
    required this.documentId,
    required this.onRefresh,
  });

  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage> {
  late Map<String, dynamic> _staffData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _staffData = Map.from(widget.data);
  }

  Future<void> _refreshData() async {
    try {
      final doc = await FirebaseConfig.facilityDb
          .collection('users')
          .doc(widget.documentId)
          .get();
      
      if (doc.exists && mounted) {
        setState(() {
          _staffData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing staff data: $e');
    }
  }

  Future<void> _toggleStatus() async {
    final currentStatus = _staffData['is_active'] as bool? ?? true;
    final action = currentStatus ? 'deactivate' : 'activate';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action == 'activate' ? 'Activate' : 'Deactivate'} Staff Member'),
        content: Text(
          'Are you sure you want to ${action} ${_staffData['name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: action == 'activate' ? Colors.green : Colors.orange,
            ),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    
    try {
      await FirebaseConfig.facilityDb
          .collection('users')
          .doc(widget.documentId)
          .update({
        'is_active': !currentStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      await _refreshData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Staff ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRefresh();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStaff() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff Member'),
        content: Text(
          'Are you sure you want to delete ${_staffData['name']}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseConfig.facilityDb
          .collection('users')
          .doc(widget.documentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRefresh();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditStaffSheet(
        staffData: _staffData,
        documentId: widget.documentId,
        onComplete: () async {
          await _refreshData();
          if (mounted) {
            widget.onRefresh();
            Navigator.pop(context, true);
          }
        },
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'doctor': return Colors.blue;
      case 'nurse': return Colors.teal;
      case 'admin': return const Color(0xFF7C3AED);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _staffData['role'] as String? ?? 'staff';
    final active = _staffData['is_active'] as bool? ?? true;
    final color = _roleColor(role);

    return Scaffold(
      backgroundColor: kBgSlate,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Staff Details',
          style: TextStyle(
            color: Color(0xFF1A2E35),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
            onPressed: _showEditSheet,
            tooltip: 'Edit Staff',
          ),
          IconButton(
            icon: Icon(
              active ? Icons.block_outlined : Icons.check_circle_outlined,
              color: active ? Colors.orange : Colors.green,
            ),
            onPressed: _toggleStatus,
            tooltip: active ? 'Deactivate' : 'Activate',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: _deleteStaff,
            tooltip: 'Delete Staff',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: color.withOpacity(0.12),
                          child: Text(
                            (_staffData['name'] as String? ?? '?')[0]
                                .toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _staffData['name'] as String? ?? '—',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: active ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: active ? Colors.green[700] : Colors.red[400],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Contact information
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _staffData['email'] as String? ?? '—',
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Employee ID',
                          value: widget.documentId,
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Joined',
                          value: _staffData['created_at'] != null
                              ? DateFormat('dd MMM yyyy').format(
                                  (_staffData['created_at'] as Timestamp).toDate())
                              : '—',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kPrimaryGreen, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Edit Staff Sheet ───────────────────────────────────────────────────────

class EditStaffSheet extends StatefulWidget {
  final Map<String, dynamic> staffData;
  final String documentId;
  final VoidCallback onComplete;

  const EditStaffSheet({
    super.key,
    required this.staffData,
    required this.documentId,
    required this.onComplete,
  });

  @override
  State<EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<EditStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late String _role;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.staffData['name'] ?? '');
    _emailController =
        TextEditingController(text: widget.staffData['email'] ?? '');
    _role = widget.staffData['role'] ?? 'doctor';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseConfig.facilityDb
          .collection('users')
          .doc(widget.documentId)
          .update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'role': _role,
        'updated_at': FieldValue.serverTimestamp(),
      });

      widget.onComplete();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
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
              const Text('Edit Staff Member',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              _buildField(_nameController, 'Full Name', Icons.person_outline),
              const SizedBox(height: 12),
              _buildField(_emailController, 'Email', Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: _buildDecoration('Role', Icons.badge_outlined),
                items: const [
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
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
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      decoration: _buildDecoration(label, icon),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _buildDecoration(String label, IconData icon) {
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

// ─── Add staff bottom sheet ───────────────────────────────────────────────────

class AddStaffSheet extends StatefulWidget {
  const AddStaffSheet({super.key});

  @override
  State<AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  String _role = 'doctor';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final adminEmail = FirebaseConfig.auth.currentUser?.email ?? '';
    final adminPassword = _adminPasswordController.text.trim();

    try {
      final credential = await FirebaseConfig.auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );
      final uid = credential.user!.uid;

      await FirebaseConfig.facilityDb.collection('users').doc(uid).set({
        'id': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'role': _role,
        'facility_id': FacilityInfo().facilityId,
        'facility_name': FacilityInfo().facilityName,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (adminEmail.isNotEmpty && adminPassword.isNotEmpty) {
        await FirebaseConfig.auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
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
      setState(() {
        _error = msg;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
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
              _buildField(_nameController, 'Full Name', Icons.person_outline),
              const SizedBox(height: 12),
              _buildField(_emailController, 'Staff Email', Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildField(_passwordController, 'Temporary Password',
                  Icons.lock_outline,
                  obscure: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: _buildDecoration('Role', Icons.badge_outlined),
                items: const [
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
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
              _buildField(_adminPasswordController, 'Your Password',
                  Icons.admin_panel_settings_outlined,
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
                          height: 18,
                          width: 18,
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

  Widget _buildField(
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
      decoration: _buildDecoration(label, icon),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _buildDecoration(String label, IconData icon) {
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