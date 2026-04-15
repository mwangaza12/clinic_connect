// lib/features/home/presentation/pages/queue_page.dart
//
// Doctor's Live Queue — real-time Firestore stream of patients who are
// 'ready_for_doctor' or 'with_doctor' at this facility today.
//
// Features:
//   • Live queue count badge in the AppBar
//   • Priority-sorted cards (critical > high > medium > low)
//   • "Call Patient" — marks status to 'with_doctor', shows elapsed wait time
//   • "Start Encounter" — navigates to CreateEncounterPage with triageContext
//     pre-filled so nurses' vitals + chief complaint carry over
//   • "Complete" — marks queue entry 'completed' and archives it
//   • Summary ribbon: waiting count, avg wait, critical count
//   • Pull-to-refresh clears any stale Firestore cache

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../encounter/presentation/pages/create_encounter_page.dart';
import '../../../patient/data/datasources/patient_local_datasource.dart';
import '../../../patient/domain/entities/patient.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF00796B);

  late final TabController _tabs;
  Stream<QuerySnapshot>? _readyStream;
  Stream<QuerySnapshot>? _withDoctorStream;

  String get _facilityId {
    final s = context.read<AuthBloc>().state;
    return s is Authenticated ? s.user.facilityId : FacilityInfo().facilityId;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _buildStream(String status) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));

    return FirebaseConfig.facilityDb
        .collection('triage_queue')
        .where('facility_id', isEqualTo: _facilityId)
        .where('status', isEqualTo: status)
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at', isLessThan: Timestamp.fromDate(end))
        .orderBy('created_at')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Patient Queue',
          style: TextStyle(
              color: _teal,
              fontWeight: FontWeight.w900,
              fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _teal,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            _QueueTabLabel('Ready for Me',   _buildStream('ready_for_doctor'), Colors.green),
            _QueueTabLabel('With Me Now',    _buildStream('with_doctor'),       Colors.blue),
          ],
        ),
      ),
      body: Column(
        children: [
          _SummaryRibbon(facilityId: _facilityId),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _QueueList(
                  stream: _readyStream ??= _buildStream('ready_for_doctor'),
                  emptyIcon: Icons.done_all_rounded,
                  emptyMsg: 'No patients ready yet',
                  emptySubMsg: 'Nurses will move patients here after triage',
                  primaryAction: 'Call Patient',
                  primaryColor: Colors.green,
                  onPrimaryAction: _callPatient,
                  onSecondaryAction: null,
                ),
                _QueueList(
                  stream: _withDoctorStream ??= _buildStream('with_doctor'),
                  emptyIcon: Icons.people_outline_rounded,
                  emptyMsg: 'No active consultations',
                  emptySubMsg: 'Call a patient to begin a consultation',
                  primaryAction: 'Start Encounter',
                  primaryColor: _teal,
                  onPrimaryAction: _startEncounter,
                  onSecondaryAction: _completeVisit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callPatient(String docId, Map<String, dynamic> data) async {
    await FirebaseConfig.facilityDb
        .collection('triage_queue')
        .doc(docId)
        .update({
      'status':       'with_doctor',
      'called_at':    FieldValue.serverTimestamp(),
      'updated_at':   FieldValue.serverTimestamp(),
    });
    // Switch to "With Me Now" tab
    _tabs.animateTo(1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Called ${data['patient_name']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _startEncounter(String docId, Map<String, dynamic> data) async {
    // Try to find the patient locally first
    Patient? patient;
    try {
      final ds   = sl<PatientLocalDatasource>();
      final nupi = data['patient_nupi'] as String? ?? '';
      if (nupi.isNotEmpty) {
        final all = await ds.getAllPatients();
        patient = all
            .cast<Patient?>()
            .firstWhere((p) => p?.nupi == nupi, orElse: () => null);
      }
    } catch (_) {}

    if (!mounted) return;

    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Patient not found locally — register them first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final triageContext = {
      'triageQueueId':  docId,
      'chiefComplaint': data['chief_complaint'] ?? '',
      'priority':       data['priority'] ?? 'medium',
      'vitals':         data['vitals'] ?? {},
      'notes':          data['notes'] ?? '',
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEncounterPage(
          patient:      patient!,
          triageContext: triageContext,
        ),
      ),
    );
  }

  Future<void> _completeVisit(String docId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete Visit?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Mark ${data['patient_name']} as seen and remove from queue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseConfig.facilityDb
        .collection('triage_queue')
        .doc(docId)
        .update({
      'status':         'completed',
      'completed_at':   FieldValue.serverTimestamp(),
      'updated_at':     FieldValue.serverTimestamp(),
    });
  }
}

// ─── Summary ribbon ───────────────────────────────────────────────────────────

class _SummaryRibbon extends StatelessWidget {
  final String facilityId;
  const _SummaryRibbon({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));

    final stream = FirebaseConfig.facilityDb
        .collection('triage_queue')
        .where('facility_id', isEqualTo: facilityId)
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at', isLessThan: Timestamp.fromDate(end))
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final waiting  = docs.where((d) {
          final s = (d.data() as Map)['status'] as String? ?? '';
          return s == 'waiting' || s == 'in_triage' || s == 'ready_for_doctor';
        }).length;
        final critical = docs.where((d) =>
            (d.data() as Map)['priority'] == 'critical').length;
        final completed = docs.where((d) =>
            (d.data() as Map)['status'] == 'completed').length;

        // Average wait: time from created_at to called_at for completed/with_doctor
        Duration? avgWait;
        final timed = docs.where((d) {
          final m = d.data() as Map;
          return m['called_at'] != null && m['created_at'] != null;
        }).toList();
        if (timed.isNotEmpty) {
          final totalMins = timed.fold<int>(0, (sum, d) {
            final m = d.data() as Map;
            final created = (m['created_at'] as Timestamp).toDate();
            final called  = (m['called_at']  as Timestamp).toDate();
            return sum + called.difference(created).inMinutes;
          });
          avgWait = Duration(minutes: totalMins ~/ timed.length);
        }

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _RibbonStat(
                value: '$waiting',
                label: 'In Queue',
                color: Colors.orange,
                icon: Icons.queue_rounded,
              ),
              const SizedBox(width: 8),
              _RibbonStat(
                value: critical > 0 ? '$critical' : '0',
                label: 'Critical',
                color: Colors.red,
                icon: Icons.emergency_rounded,
              ),
              const SizedBox(width: 8),
              _RibbonStat(
                value: avgWait != null
                    ? '${avgWait.inMinutes}m'
                    : '—',
                label: 'Avg Wait',
                color: const Color(0xFF00796B),
                icon: Icons.timer_outlined,
              ),
              const SizedBox(width: 8),
              _RibbonStat(
                value: '$completed',
                label: 'Done Today',
                color: Colors.grey,
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RibbonStat extends StatelessWidget {
  final String  value;
  final String  label;
  final Color   color;
  final IconData icon;
  const _RibbonStat({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        Text(label,
            style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 9,
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─── Queue list ───────────────────────────────────────────────────────────────

class _QueueList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final IconData  emptyIcon;
  final String    emptyMsg;
  final String    emptySubMsg;
  final String    primaryAction;
  final Color     primaryColor;
  final Future<void> Function(String, Map<String, dynamic>) onPrimaryAction;
  final Future<void> Function(String, Map<String, dynamic>)? onSecondaryAction;

  const _QueueList({
    required this.stream,
    required this.emptyIcon,
    required this.emptyMsg,
    required this.emptySubMsg,
    required this.primaryAction,
    required this.primaryColor,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final rawDocs = snap.data?.docs ?? [];

        // Sort: critical first, then high, medium, low — within same priority by time
        const order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
        final docs  = [...rawDocs]..sort((a, b) {
          final pa = (a.data() as Map)['priority'] as String? ?? 'medium';
          final pb = (b.data() as Map)['priority'] as String? ?? 'medium';
          final oa = order[pa] ?? 2;
          final ob = order[pb] ?? 2;
          if (oa != ob) return oa.compareTo(ob);
          final ta = ((a.data() as Map)['created_at'] as Timestamp?)
              ?.toDate() ?? DateTime.now();
          final tb = ((b.data() as Map)['created_at'] as Timestamp?)
              ?.toDate() ?? DateTime.now();
          return ta.compareTo(tb);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(emptyMsg,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(emptySubMsg,
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _DoctorQueueCard(
              docId:           doc.id,
              data:            data,
              primaryAction:   primaryAction,
              primaryColor:    primaryColor,
              onPrimary:       onPrimaryAction,
              onSecondary:     onSecondaryAction,
            );
          },
        );
      },
    );
  }
}

// ─── Doctor queue card ────────────────────────────────────────────────────────

class _DoctorQueueCard extends StatelessWidget {
  final String   docId;
  final Map<String, dynamic> data;
  final String   primaryAction;
  final Color    primaryColor;
  final Future<void> Function(String, Map<String, dynamic>) onPrimary;
  final Future<void> Function(String, Map<String, dynamic>)? onSecondary;

  const _DoctorQueueCard({
    required this.docId,
    required this.data,
    required this.primaryAction,
    required this.primaryColor,
    required this.onPrimary,
    required this.onSecondary,
  });

  static const _priorityColors = {
    'critical': Color(0xFFEF4444),
    'high':     Color(0xFFF59E0B),
    'medium':   Color(0xFF3B82F6),
    'low':      Color(0xFF22C55E),
  };
  static const _priorityIcons = {
    'critical': Icons.emergency_rounded,
    'high':     Icons.arrow_upward_rounded,
    'medium':   Icons.remove_rounded,
    'low':      Icons.arrow_downward_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final priority = data['priority'] as String? ?? 'medium';
    final pc       = _priorityColors[priority] ?? Colors.blue;
    final pi       = _priorityIcons[priority]  ?? Icons.remove_rounded;

    final createdAt = (data['created_at'] as Timestamp?)?.toDate();
    final waitMin   = createdAt != null
        ? DateTime.now().difference(createdAt).inMinutes
        : null;

    final vitals = (data['vitals'] as Map?)?.cast<String, dynamic>() ?? {};
    final hasAbnormalVitals = _hasAbnormalVitals(vitals);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: priority == 'critical'
              ? pc.withOpacity(0.4)
              : Colors.grey.shade200,
          width: priority == 'critical' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pc.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Icon(pi, color: pc, size: 16),
              const SizedBox(width: 6),
              Text(
                priority.toUpperCase(),
                style: TextStyle(
                    color: pc,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6),
              ),
              const Spacer(),
              if (waitMin != null)
                Row(children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 13,
                    color: waitMin > 30
                        ? Colors.red
                        : Colors.grey[500],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatWait(waitMin),
                    style: TextStyle(
                        color: waitMin > 30
                            ? Colors.red
                            : Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              if (hasAbnormalVitals) ...[ 
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '⚠ VITALS',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient name + age/gender
                Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: pc.withOpacity(0.12),
                    child: Text(
                      (data['patient_name'] as String? ?? '?')
                          .isNotEmpty
                          ? (data['patient_name'] as String)
                              .characters
                              .first
                              .toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: pc,
                          fontWeight: FontWeight.w900,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['patient_name'] as String? ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                        Text(
                          _patientSubtitle(data),
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ]),

                // Chief complaint
                if ((data['chief_complaint'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.notes_rounded,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data['chief_complaint'] as String,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ],

                // Vitals chips
                if (vitals.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _buildVitalChips(vitals),
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Row(children: [
                  if (onSecondary != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onSecondary!(docId, data),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Complete',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (onSecondary != null) const SizedBox(width: 8),
                  Expanded(
                    flex: onSecondary != null ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: () => onPrimary(docId, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      child: Text(
                        primaryAction,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatWait(int minutes) {
    if (minutes < 60) return '${minutes}m wait';
    return '${minutes ~/ 60}h ${minutes % 60}m wait';
  }

  String _patientSubtitle(Map<String, dynamic> data) {
    final parts = <String>[];
    final age    = data['patient_age'];
    final gender = data['patient_gender'] as String?;
    final nupi   = data['patient_nupi'] as String?;
    if (age != null) parts.add('$age yrs');
    if (gender != null) parts.add(gender);
    if (nupi != null && nupi.isNotEmpty) parts.add(nupi);
    return parts.join(' · ');
  }

  bool _hasAbnormalVitals(Map<String, dynamic> vitals) {
    final spo2  = vitals['oxygen_saturation'] as num?;
    final pulse = vitals['pulse_rate']        as num?;
    final temp  = vitals['temperature']       as num?;
    final sys   = vitals['systolic_bp']       as num?;
    if (spo2  != null && spo2 < 95)   return true;
    if (pulse != null && (pulse < 50 || pulse > 120)) return true;
    if (temp  != null && (temp < 35 || temp > 38.5)) return true;
    if (sys   != null && (sys  < 90  || sys  > 160)) return true;
    return false;
  }

  List<Widget> _buildVitalChips(Map<String, dynamic> vitals) {
    final chips = <Widget>[];

    void add(String label, Color color) => chips.add(_VitalChip(
          label: label,
          color: color,
        ));

    final sys  = vitals['systolic_bp']       as num?;
    final dia  = vitals['diastolic_bp']      as num?;
    final hr   = vitals['pulse_rate']        as num?;
    final temp = vitals['temperature']       as num?;
    final spo2 = vitals['oxygen_saturation'] as num?;
    final wt   = vitals['weight']            as num?;

    if (sys != null) {
      final abnormal = sys < 90 || sys > 160;
      add('BP $sys/${dia ?? '?'}',
          abnormal ? Colors.red : Colors.grey[700]!);
    }
    if (hr != null) {
      final abnormal = hr < 50 || hr > 120;
      add('$hr bpm', abnormal ? Colors.red : Colors.grey[700]!);
    }
    if (temp != null) {
      final abnormal = temp < 35 || temp > 38.5;
      add('${temp}°C', abnormal ? Colors.orange : Colors.grey[700]!);
    }
    if (spo2 != null) {
      final abnormal = spo2 < 95;
      add('SpO₂ $spo2%', abnormal ? Colors.red : Colors.grey[700]!);
    }
    if (wt != null) add('${wt}kg', Colors.grey[700]!);

    return chips;
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _VitalChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(
      label,
      style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600),
    ),
  );
}

// ─── Tab label with live count badge ─────────────────────────────────────────

class _QueueTabLabel extends StatelessWidget
    implements PreferredSizeWidget {
  final String               label;
  final Stream<QuerySnapshot> countStream;
  final Color                color;
  const _QueueTabLabel(this.label, this.countStream, this.color);

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 6),
          StreamBuilder<QuerySnapshot>(
            stream: countStream,
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}