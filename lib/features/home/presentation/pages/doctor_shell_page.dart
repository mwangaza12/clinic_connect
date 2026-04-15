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

import '../../../../core/config/firebase_config.dart';
import '../../../../core/sync/widgets/sync_status_widget.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../disease_program/presentation/bloc/program_bloc.dart';
import '../../../disease_program/presentation/pages/program_dashboard_page.dart';
import '../../../patient/data/datasources/patient_local_datasource.dart';
import '../../../patient/data/models/patient_model.dart' as pm;
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/pages/nupi_lookup_page.dart';
import '../../../patient/presentation/pages/patient_detail_page.dart';
import '../../../patient/presentation/pages/patient_list_page.dart';
import '../../../patient/presentation/pages/patient_registration_page.dart';
import '../../../referral/presentation/pages/referrals_page.dart';
import '../../../encounter/presentation/pages/encounter_detail_page.dart';
import '../../../encounter/presentation/pages/encounter_list_page.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import 'profile_page.dart';
import 'shell_widgets.dart';
import 'queue_page.dart';


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
    ShellNavItem(Icons.queue_rounded,            Icons.queue_outlined,             'Queue'),    // NEW
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
          appBar: _buildAppBar(user.facilityName, user.facilityId),
          body: BlocProvider.value(
            value: _dashBloc..add(LoadDashboardEvent(user.facilityId)),
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                DoctorDashboardTab(user: user, onNavigate: _goTo),
                const QueuePage(),
                BlocProvider(
                  create: (_) =>
                      sl<PatientBloc>()..add(const LoadPatientsByFacilityEvent()),
                  child: const PatientListView(),
                ),
                EncounterListPage(facilityId: user.facilityId),
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

  PreferredSizeWidget _buildAppBar(String facilityName, String facilityId) {
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
        _QueueBadge(facilityId: facilityId, onTap: () => _goTo(1)),

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
                  MaterialPageRoute(builder: (_) => const PatientRegistrationPage()))
                .then((_) {
                  // Navigate to the Patients tab and reload after registration
                  onNavigate(2);
                }),
            ),
            ActionRow(
              icon: Icons.medical_services_rounded, color: Colors.blue,
              title: 'New Encounter', subtitle: 'Document a clinical visit',
              onTap: () => onNavigate(2),
            ),
            ActionRow(
              icon: Icons.send_rounded, color: Colors.orange,
              title: 'Create Referral', subtitle: 'Transfer to another facility',
              onTap: () => onNavigate(4),
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
              onTap: () => onNavigate(2),
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

            // Triage queue — patients waiting to be seen
            _TriageQueueSection(facilityId: user.facilityId as String),
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

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EncounterDetailPage(
            encounter: encounter,
            patientName: encounter['patient_name'] as String?,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
          Row(
            children: [
              Text(DateFormat('HH:mm').format(date),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8))),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 16, color: Color(0xFFCBD5E1)),
            ],
          ),
        ],
      ),
    ), // InkWell child
    ); // InkWell
  }
}

// ─── Encounters tab ───────────────────────────────────────────────────────────

// ─── Triage Queue Section (doctor dashboard) ─────────────────────────────────

class _TriageQueueSection extends StatefulWidget {
  final String facilityId;
  const _TriageQueueSection({required this.facilityId});
  @override
  State<_TriageQueueSection> createState() => _TriageQueueSectionState();
}

class _TriageQueueSectionState extends State<_TriageQueueSection> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));
    _stream = FirebaseConfig.facilityDb
        .collection('triage_queue')
        .where('facility_id', isEqualTo: widget.facilityId)
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at', isLessThan: Timestamp.fromDate(end))
        .where('status', whereIn: ['waiting', 'in_triage', 'ready_for_doctor'])
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox();

        // Sort: ready_for_doctor first, then in_triage, then waiting
        final sorted = [...docs]..sort((a, b) {
          const order = {'ready_for_doctor': 0, 'in_triage': 1, 'waiting': 2};
          final sa = (a.data() as Map)['status'] as String? ?? 'waiting';
          final sb = (b.data() as Map)['status'] as String? ?? 'waiting';
          return (order[sa] ?? 3).compareTo(order[sb] ?? 3);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel('Triage Queue'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${docs.length} waiting',
                    style: const TextStyle(
                        color: Colors.teal, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...sorted.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _DoctorTriageCard(id: doc.id, data: data);
            }),
          ],
        );
      },
    );
  }
}

// _DoctorTriageCard navigates to PatientDetailPage on "See Patient"
// and passes triage context (vitals, chief complaint) for pre-population.
class _DoctorTriageCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const _DoctorTriageCard({required this.id, required this.data});

  @override
  State<_DoctorTriageCard> createState() => _DoctorTriageCardState();
}

class _DoctorTriageCardState extends State<_DoctorTriageCard> {
  bool _navigating = false;

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical': return const Color(0xFFEF4444);
      case 'high':     return const Color(0xFFF59E0B);
      case 'medium':   return const Color(0xFF3B82F6);
      default:         return const Color(0xFF22C55E);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ready_for_doctor': return Colors.green;
      case 'in_triage':        return Colors.blue;
      case 'waiting':          return Colors.orange;
      default:                 return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'ready_for_doctor': return 'Ready';
      case 'in_triage':        return 'In Triage';
      case 'waiting':          return 'Waiting';
      default:                 return s;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseConfig.facilityDb
        .collection('triage_queue')
        .doc(widget.id)
        .update({
      'status':     newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Mark with_doctor + navigate directly to the patient record.
  // Triage context (vitals, complaint) is passed so the encounter
  // form can pre-populate without the doctor re-entering anything.
  Future<void> _seePatient() async {
    if (_navigating) return;
    if (!mounted) return;
    setState(() => _navigating = true);

    // Fire-and-forget — do NOT await _updateStatus here.
    // Awaiting causes the Firestore stream to rebuild the triage list
    // immediately, which disposes this widget mid-flight and crashes
    // on the subsequent setState / Navigator calls.
    _updateStatus('with_doctor').catchError((_) {});

    final nupi = widget.data['patient_nupi'] as String? ?? '';
    if (nupi.isEmpty) {
      if (mounted) setState(() => _navigating = false);
      return;
    }

    // Look up in SQLite first (fast, offline-safe), then Firestore.
    final ds = sl<PatientLocalDatasource>();
    var patient = await ds.getPatientByNupi(nupi);

    if (patient == null) {
      try {
        final snap = await FirebaseConfig.facilityDb
            .collection('patients')
            .where('nupi', isEqualTo: nupi)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final model = _patientFromFirestore(
              snap.docs.first.data(), snap.docs.first.id);
          await ds.cachePatient(model);
          patient = model;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _navigating = false);

    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Patient record not found for NUPI $nupi'),
        backgroundColor: Colors.orange[700],
      ));
      return;
    }

    final triageContext = <String, dynamic>{
      'triageQueueId':  widget.id,
      'chiefComplaint': widget.data['chief_complaint'] ?? '',
      'priority':       widget.data['priority'] ?? 'medium',
      'vitals':         widget.data['vitals'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailPage(
          patient:       patient!,
          triageContext: triageContext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name      = widget.data['patient_name'] as String? ?? 'Unknown';
    final priority  = widget.data['priority']     as String? ?? 'medium';
    final status    = widget.data['status']       as String? ?? 'waiting';
    final age       = widget.data['patient_age'];
    final complaint = widget.data['chief_complaint'] as String? ?? '';
    final vitals    = widget.data['vitals'] as Map<String, dynamic>?;
    final pc = _priorityColor(priority);
    final sc = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'ready_for_doctor'
              ? Colors.green.withOpacity(0.4)
              : const Color(0xFFE2E8F0),
          width: status == 'ready_for_doctor' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: pc, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statusLabel(status),
                  style: TextStyle(
                      color: sc, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (age != null) ...[
            const SizedBox(height: 2),
            Text('$age yrs  •  ${priority.toUpperCase()}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
          if (complaint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(complaint,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF475569))),
          ],
          if (vitals != null && vitals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: [
                if (vitals['systolic_bp'] != null)
                  _VitalChip(
                      'BP ${vitals['systolic_bp']}/${vitals['diastolic_bp'] ?? '?'}',
                      Icons.favorite_rounded, Colors.red),
                if (vitals['pulse_rate'] != null)
                  _VitalChip('${vitals['pulse_rate']} bpm',
                      Icons.timeline_rounded, Colors.blue),
                if (vitals['temperature'] != null)
                  _VitalChip('${vitals['temperature']}°C',
                      Icons.thermostat_rounded, Colors.orange),
                if (vitals['oxygen_saturation'] != null)
                  _VitalChip('SpO₂ ${vitals['oxygen_saturation']}%',
                      Icons.air_rounded, Colors.teal),
              ],
            ),
          ],
          if (status == 'ready_for_doctor') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _navigating ? null : _seePatient,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _navigating
                        ? kPrimaryGreen.withOpacity(0.6)
                        : kPrimaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _navigating
                      ? const Center(
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medical_services_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('See Patient',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
            ),
          ],
          if (status == 'with_doctor') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => _updateStatus('done'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Mark Done',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// Top-level helper — converts a raw Firestore patient document into a
// PatientModel without going through the full repository stack.
// Used in _DoctorTriageCardState._seePatient() for the Firestore fallback.
pm.PatientModel _patientFromFirestore(
    Map<String, dynamic> data, String docId) {
  DateTime parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  List<String> parseList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  return pm.PatientModel(
    id:                    docId,
    nupi:                  data['nupi']                                      as String? ?? '',
    firstName:             (data['first_name']  ?? data['firstName']  ?? '') as String,
    middleName:            (data['middle_name'] ?? data['middleName'] ?? '') as String,
    lastName:              (data['last_name']   ?? data['lastName']   ?? '') as String,
    gender:                data['gender']                                     as String? ?? 'unknown',
    dateOfBirth:           parseDate(data['date_of_birth']  ?? data['dateOfBirth']),
    phoneNumber:           (data['phone_number'] ?? data['phoneNumber'] ?? '') as String,
    email:                 data['email']                                      as String?,
    county:                data['county']                                     as String? ?? '',
    subCounty:             (data['sub_county']  ?? data['subCounty']  ?? '') as String,
    ward:                  data['ward']                                       as String? ?? '',
    village:               data['village']                                    as String? ?? '',
    bloodGroup:            (data['blood_group'] ?? data['bloodGroup'])        as String?,
    facilityId:            (data['facility_id'] ?? data['facilityId'] ?? '') as String,
    allergies:             parseList(data['allergies']),
    chronicConditions:     parseList(data['chronic_conditions'] ?? data['chronicConditions']),
    nextOfKinName:         (data['next_of_kin_name']         ?? data['nextOfKinName'])         as String?,
    nextOfKinPhone:        (data['next_of_kin_phone']        ?? data['nextOfKinPhone'])        as String?,
    nextOfKinRelationship: (data['next_of_kin_relationship'] ?? data['nextOfKinRelationship']) as String?,
    createdAt:             parseDate(data['created_at'] ?? data['createdAt']),
    updatedAt:             parseDate(data['updated_at'] ?? data['updatedAt']),
  );
}

class _VitalChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _VitalChip(this.text, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(
          fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _QueueBadge extends StatelessWidget {
  final String facilityId;
  final VoidCallback onTap;
  const _QueueBadge({required this.facilityId, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));
 
    final stream = FirebaseConfig.facilityDb
        .collection('triage_queue')
        .where('facility_id',  isEqualTo: facilityId)
        .where('status',       isEqualTo: 'ready_for_doctor')
        .where('created_at',   isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at',   isLessThan: Timestamp.fromDate(end))
        .snapshots();
 
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.queue_rounded,
                    color: kPrimaryGreen, size: 22),
              ),
              if (count > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}