// lib/features/home/presentation/pages/analytics_page.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/schema.dart';
import '../../../../core/sync/connectivity_manager.dart';
import 'shell_widgets.dart';

const _kStaffCacheKey = 'analytics_staff_cache';

// ── Palette — matches app green theme ────────────────────────────
const _green      = Color(0xFF1B4332);
const _greenLight = Color(0xFF2D6A4F);
const _bg         = Color(0xFFF1F5F9);
const _white      = Colors.white;
const _border     = Color(0xFFE2E8F0);
const _textMain   = Color(0xFF1E293B);
const _textSub    = Color(0xFF64748B);
const _blue       = Color(0xFF3B82F6);
const _indigo     = Color(0xFF6366F1);
const _amber      = Color(0xFFF59E0B);
const _red        = Color(0xFFEF4444);
const _teal       = Color(0xFF0D9488);

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {
  TabController?       _tabController;
  AnimationController? _fadeCtrl;
  Animation<double>?   _fadeAnim;

  // Period in months — drives all queries
  int _months = 1;

  DateTimeRange get _dateRange {
    final end = DateTime.now();
    final start = _months == 0
        ? DateTime(2020)  // All time
        : DateTime(end.year, end.month - _months + 1, 1);
    return DateTimeRange(start: start, end: end);
  }

  static const _periodOptions = [
    (label: '1M',  months: 1),
    (label: '3M',  months: 3),
    (label: '6M',  months: 6),
    (label: '1Y',  months: 12),
    (label: 'All', months: 0),
  ];

  final _db           = DatabaseHelper();
  final _facilityInfo = FacilityInfo();

  Map<String, dynamic> _stats       = {};
  bool _loading        = true;
  bool _staffFromCache = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl!, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _fadeCtrl?.dispose();
    super.dispose();
  }

  // ── Load ─────────────────────────────────────────────────────────
  // Strategy:
  //   Online  → Firestore (source of truth — has all seeded + app data)
  //   Offline → SQLite   (local records created on this device)

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    _fadeCtrl?.reset();
    try {
      final online = await ConnectivityManager().checkConnectivity();
      final fid    = _facilityInfo.facilityId;
      debugPrint('[Analytics] fid=$fid  online=$online');

      if (fid.isEmpty) {
        debugPrint('[Analytics] facilityId empty — cannot load stats');
        return;
      }

      if (online) {
        await _loadFromFirestore(fid);
      } else {
        await _loadFromSQLite(fid);
      }
      await _loadStaff();
    } catch (e, st) {
      debugPrint('[Analytics] load error: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _fadeCtrl?.forward();
      }
    }
  }

  // ── Firestore path (online) ───────────────────────────────────────

  Future<void> _loadFromFirestore(String fid) async {
    final fs = FirebaseConfig.facilityDb;

    // ── Patients — backend writes 'facilityId' (camelCase) ────────
    final patSnap = await fs.collection('patients')
        .where('facilityId', isEqualTo: fid).get();
    final allPats = patSnap.docs.map((d) => d.data()).toList();

    int totalPat = allPats.length, malePat = 0, femPat = 0;
    final ageBuckets = <String, int>{'0-17': 0, '18-35': 0, '36-50': 0, '51+': 0};
    final now = DateTime.now();
    for (final p in allPats) {
      final gender = (p['gender'] as String? ?? '').toLowerCase();
      if (gender == 'male') malePat++;
      if (gender == 'female') femPat++;
      try {
        // backend writes 'dateOfBirth' (camelCase)
        final dobStr = p['dateOfBirth'] as String? ?? p['date_of_birth'] as String? ?? '';
        if (dobStr.isNotEmpty) {
          final dob = DateTime.parse(dobStr);
          final age = now.year - dob.year -
              ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
          if (age <= 17)      ageBuckets['0-17']  = ageBuckets['0-17']!  + 1;
          else if (age <= 35) ageBuckets['18-35'] = ageBuckets['18-35']! + 1;
          else if (age <= 50) ageBuckets['36-50'] = ageBuckets['36-50']! + 1;
          else                ageBuckets['51+']   = ageBuckets['51+']!   + 1;
        }
      } catch (_) {}
    }

    // ── Encounters — backend writes 'facility_id' (snake_case) ────
    final encSnap = await fs.collection('encounters')
        .where('facility_id', isEqualTo: fid).get();
    final allEncs = encSnap.docs.map((d) => d.data()).toList();

    final startStr = DateFormat('yyyy-MM-dd').format(_dateRange.start);
    final endStr   = DateFormat('yyyy-MM-dd').format(_dateRange.end);

    final trendsMap = <String, int>{};
    final typesMap  = <String, int>{};
    for (final e in allEncs) {
      String? dateStr;
      final rawDate = e['encounter_date'];
      if (rawDate is Timestamp) {
        dateStr = DateFormat('yyyy-MM-dd').format(rawDate.toDate());
      } else if (rawDate is String && rawDate.isNotEmpty) {
        dateStr = rawDate.substring(0, 10);
      }

      if (dateStr != null && dateStr.compareTo(startStr) >= 0 && dateStr.compareTo(endStr) <= 0) {
        trendsMap[dateStr] = (trendsMap[dateStr] ?? 0) + 1;
      }

      // backend writes 'type' but also 'encounter_type'
      final type = (e['type'] ?? e['encounter_type'] ?? 'outpatient') as String;
      typesMap[type] = (typesMap[type] ?? 0) + 1;
    }

    final sortedTrends = trendsMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedTypes = typesMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Referrals — Flutter app writes 'from_facility_id' ─────────
    final refSnap = await fs.collection('referrals')
        .where('from_facility_id', isEqualTo: fid).get();
    final allRefs = refSnap.docs.map((d) => d.data()).toList();
    int totalRef = allRefs.length, pendingRef = 0, acceptRef = 0,
        doneRef = 0, rejectRef = 0, urgentRef = 0;
    for (final r in allRefs) {
      final s = (r['status']   as String? ?? '').toLowerCase();
      final p = (r['priority'] as String? ?? '').toLowerCase();
      if (s == 'pending')   pendingRef++;
      if (s == 'accepted')  acceptRef++;
      if (s == 'completed') doneRef++;
      if (s == 'rejected')  rejectRef++;
      if (p == 'urgent')    urgentRef++;
    }

    // ── Program enrollments — seed writes 'facilityId' (camelCase) ─
    int totalProg = 0, activeProg = 0;
    final progMap = <String, int>{};
    try {
      // Try camelCase first (seed), then snake_case (app)
      var progSnap = await fs.collection('program_enrollments')
          .where('facilityId', isEqualTo: fid).get();
      if (progSnap.docs.isEmpty) {
        progSnap = await fs.collection('program_enrollments')
            .where('facility_id', isEqualTo: fid).get();
      }
      totalProg = progSnap.docs.length;
      for (final d in progSnap.docs) {
        final data    = d.data();
        final status  = (data['status']  as String? ?? '').toLowerCase();
        final program = (data['program'] as String? ?? '');
        if (status == 'active') activeProg++;
        if (program.isNotEmpty) progMap[program] = (progMap[program] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('[Analytics] program_enrollments: $e');
    }

    final sortedProgs = progMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    debugPrint('[Analytics] Firestore ✅ pat=$totalPat enc=${allEncs.length} ref=$totalRef prog=$totalProg');

    if (!mounted) return;
    setState(() {
      _stats = {
        ..._stats,
        'source':          'firestore',
        'totalPatients':   totalPat,
        'malePatients':    malePat,
        'femalePatients':  femPat,
        'ageGroups':       ageBuckets,
        'totalEncounters': allEncs.length,
        'encounterTrends': sortedTrends
            .map((e) => {'date': e.key, 'count': e.value}).toList(),
        'encounterTypes':  sortedTypes
            .map((e) => {'type': e.key, 'count': e.value}).toList(),
        'totalReferrals':     totalRef,
        'pendingReferrals':   pendingRef,
        'acceptedReferrals':  acceptRef,
        'completedReferrals': doneRef,
        'rejectedReferrals':  rejectRef,
        'urgentReferrals':    urgentRef,
        'totalPrograms':  totalProg,
        'activePrograms': activeProg,
        'programRows':    sortedProgs
            .map((e) => {'program': e.key, 'count': e.value}).toList(),
      };
    });
  }

  // ── SQLite path (offline) ─────────────────────────────────────────

  Future<void> _loadFromSQLite(String fid) async {
    final db = await _db.database;

    // Patients
    final totalPat = _q(await db.rawQuery(
        'SELECT COUNT(*) AS c FROM ${Tbl.patients} WHERE ${Col.facilityId}=?', [fid]));
    final malePat  = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.patients} WHERE ${Col.facilityId}=? AND ${Col.gender}='male'", [fid]));
    final femPat   = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.patients} WHERE ${Col.facilityId}=? AND ${Col.gender}='female'", [fid]));

    final ageBuckets = <String, int>{'0-17': 0, '18-35': 0, '36-50': 0, '51+': 0};
    final patients = await db.rawQuery(
        'SELECT ${Col.dateOfBirth} FROM ${Tbl.patients} WHERE ${Col.facilityId}=?', [fid]);
    final now = DateTime.now();
    for (final row in patients) {
      try {
        final dob = DateTime.parse(row[Col.dateOfBirth] as String);
        final age = now.year - dob.year -
            ((now.month < dob.month ||
                (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
        if (age <= 17)      ageBuckets['0-17']  = ageBuckets['0-17']!  + 1;
        else if (age <= 35) ageBuckets['18-35'] = ageBuckets['18-35']! + 1;
        else if (age <= 50) ageBuckets['36-50'] = ageBuckets['36-50']! + 1;
        else                ageBuckets['51+']   = ageBuckets['51+']!   + 1;
      } catch (_) {}
    }

    // Encounters
    final totalEnc = _q(await db.rawQuery(
        'SELECT COUNT(*) AS c FROM ${Tbl.encounters} WHERE ${Col.facilityId}=?', [fid]));
    final startStr = DateFormat('yyyy-MM-dd').format(_dateRange.start);
    final endStr   = '${DateFormat('yyyy-MM-dd').format(_dateRange.end)}T23:59:59';
    final trends = await db.rawQuery('''
      SELECT DATE(${Col.encounterDate}) AS d, COUNT(*) AS c
      FROM ${Tbl.encounters}
      WHERE ${Col.facilityId}=?
        AND ${Col.encounterDate} >= ?
        AND ${Col.encounterDate} <= ?
      GROUP BY DATE(${Col.encounterDate})
      ORDER BY d ASC LIMIT 31
    ''', [fid, startStr, endStr]);
    final typeRows = await db.rawQuery('''
      SELECT ${Col.type}, COUNT(*) AS c
      FROM ${Tbl.encounters}
      WHERE ${Col.facilityId}=?
      GROUP BY ${Col.type} ORDER BY c DESC
    ''', [fid]);

    // Referrals
    final totalRef   = _q(await db.rawQuery(
        'SELECT COUNT(*) AS c FROM ${Tbl.referrals} WHERE ${Col.fromFacilityId}=?', [fid]));
    final pendingRef = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.referrals} WHERE ${Col.fromFacilityId}=? AND ${Col.status}='pending'", [fid]));
    final acceptRef  = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.referrals} WHERE ${Col.fromFacilityId}=? AND ${Col.status}='accepted'", [fid]));
    final doneRef    = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.referrals} WHERE ${Col.fromFacilityId}=? AND ${Col.status}='completed'", [fid]));
    final rejectRef  = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.referrals} WHERE ${Col.fromFacilityId}=? AND ${Col.status}='rejected'", [fid]));
    final urgentRef  = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.referrals} WHERE ${Col.fromFacilityId}=? AND ${Col.priority}='urgent'", [fid]));

    // Programs
    final totalProg  = _q(await db.rawQuery(
        'SELECT COUNT(*) AS c FROM ${Tbl.programEnrollments} WHERE ${Col.facilityId}=?', [fid]));
    final activeProg = _q(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${Tbl.programEnrollments} WHERE ${Col.facilityId}=? AND ${Col.status}='active'", [fid]));
    final progRows = await db.rawQuery('''
      SELECT ${Col.program}, COUNT(*) AS c
      FROM ${Tbl.programEnrollments}
      WHERE ${Col.facilityId}=?
      GROUP BY ${Col.program} ORDER BY c DESC
    ''', [fid]);

    debugPrint('[Analytics] SQLite: pat=$totalPat enc=$totalEnc ref=$totalRef prog=$totalProg');

    if (!mounted) return;
    setState(() {
      _stats = {
        ..._stats,
        'source':          'sqlite',
        'totalPatients':   totalPat,
        'malePatients':    malePat,
        'femalePatients':  femPat,
        'ageGroups':       ageBuckets,
        'totalEncounters': totalEnc,
        'encounterTrends': trends
            .map((r) => {'date': r['d'] as String, 'count': _int(r['c'])}).toList(),
        'encounterTypes':  typeRows
            .map((r) => {'type': r[Col.type] as String? ?? 'visit', 'count': _int(r['c'])}).toList(),
        'totalReferrals':     totalRef,
        'pendingReferrals':   pendingRef,
        'acceptedReferrals':  acceptRef,
        'completedReferrals': doneRef,
        'rejectedReferrals':  rejectRef,
        'urgentReferrals':    urgentRef,
        'totalPrograms':  totalProg,
        'activePrograms': activeProg,
        'programRows': progRows
            .map((r) => {'program': r[Col.program] as String? ?? '', 'count': _int(r['c'])}).toList(),
      };
    });
  }

  Future<void> _loadStaff() async {
    final fid = _facilityInfo.facilityId;
    if (fid.isEmpty) return;

    final cached = await _readStaffCache(fid);
    if (cached != null && mounted) {
      setState(() { _stats['staffStats'] = cached; _staffFromCache = true; });
    }

    final online = await ConnectivityManager().checkConnectivity();
    if (!online) {
      if (cached == null && mounted) {
        setState(() { _stats['staffStats'] = _emptyStaff(); _staffFromCache = true; });
      }
      return;
    }
    try {
      final snap = await FirebaseConfig.facilityDb
          .collection('users').where('facility_id', isEqualTo: fid).get();
      int total = snap.docs.length, doctors = 0, nurses = 0, admins = 0, active = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final role = data['role'] as String? ?? '';
        if (data['is_active'] as bool? ?? true) active++;
        if (role == 'doctor') doctors++;
        else if (role == 'nurse') nurses++;
        else if (role == 'admin') admins++;
      }
      final fresh = {
        'total': total, 'doctors': doctors, 'nurses': nurses,
        'admins': admins, 'active': active, 'inactive': total - active,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await _writeStaffCache(fid, fresh);
      if (mounted) setState(() { _stats['staffStats'] = fresh; _staffFromCache = false; });
    } catch (e) { debugPrint('[Analytics] staff: $e'); }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  int _q(List<Map<String, Object?>> rows) =>
      _int(rows.isNotEmpty ? rows.first.values.first : 0);

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> _emptyStaff() =>
      {'total': 0, 'doctors': 0, 'nurses': 0, 'admins': 0, 'active': 0, 'inactive': 0};

  Future<Map<String, dynamic>?> _readStaffCache(String fid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_kStaffCacheKey}_$fid');
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) { return null; }
  }

  Future<void> _writeStaffCache(String fid, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_kStaffCacheKey}_$fid', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _share() async {
    final ss = _stats['staffStats'] as Map? ?? {};
    final label = _months == 0 ? 'All time' : '$_months month${_months > 1 ? 's' : ''}';
    await Share.share('''
ClinicConnect Analytics Report
${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}
Period: $label

Patients:    ${_stats['totalPatients'] ?? 0}
Encounters:  ${_stats['totalEncounters'] ?? 0}
Referrals:   ${_stats['totalReferrals'] ?? 0}
Programs:    ${_stats['totalPrograms'] ?? 0}
Staff:       ${ss['total'] ?? 0}
''', subject: 'ClinicConnect Analytics Report');
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tc = _tabController;
    if (tc == null) return const SizedBox();

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(tc),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : FadeTransition(
              opacity: _fadeAnim ?? const AlwaysStoppedAnimation(1.0),
              child: TabBarView(
                controller: tc,
                children: [
                  _OverviewTab(stats: _stats, dateRange: _dateRange, toInt: _int),
                  _PatientsTab(stats: _stats, toInt: _int),
                  _EncountersTab(stats: _stats, toInt: _int),
                  _StaffReferralsTab(stats: _stats, fromCache: _staffFromCache, toInt: _int),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(TabController tc) {
    final sourceTag = _stats['source'] as String?;

    return AppBar(
      backgroundColor: _white,
      elevation: 0,
      iconTheme: const IconThemeData(color: _green),
      title: Row(
        children: [
          const Text('Analytics',
              style: TextStyle(color: _textMain, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(width: 8),
          if (sourceTag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: sourceTag == 'firestore'
                    ? _green.withOpacity(0.1) : _amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sourceTag == 'firestore' ? '● live' : '● offline',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: sourceTag == 'firestore' ? _green : _amber,
                ),
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Column(
          children: [
            // Period selector chips
            Container(
              color: _white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: _periodOptions.map((opt) {
                  final selected = _months == opt.months;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (_months != opt.months) {
                          setState(() => _months = opt.months);
                          _load();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? _green : _green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? _green : _green.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? _white : _green,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Tab bar
            TabBar(
              controller: tc,
              indicatorColor: _green,
              indicatorWeight: 3,
              labelColor: _green,
              unselectedLabelColor: _textSub,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Patients'),
                Tab(text: 'Encounters'),
                Tab(text: 'Staff & Ref'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        IconButton(icon: const Icon(Icons.ios_share_rounded), onPressed: _share),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final DateTimeRange dateRange;
  final int Function(dynamic) toInt;
  const _OverviewTab({required this.stats, required this.dateRange, required this.toInt});

  @override
  Widget build(BuildContext context) {
    final ss     = stats['staffStats'] as Map? ?? {};
    final trends = (stats['encounterTrends'] as List? ?? []).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _KpiCard(label: 'Patients',   value: '${stats['totalPatients'] ?? 0}',
                icon: Icons.people_rounded,               color: _blue),
            _KpiCard(label: 'Encounters', value: '${stats['totalEncounters'] ?? 0}',
                icon: Icons.medical_services_rounded,     color: _green),
            _KpiCard(label: 'Referrals',  value: '${stats['totalReferrals'] ?? 0}',
                icon: Icons.swap_horiz_rounded,           color: _amber),
            _KpiCard(label: 'Programs',   value: '${stats['totalPrograms'] ?? 0}',
                icon: Icons.assignment_turned_in_rounded, color: _teal),
          ],
        ),
        const SizedBox(height: 20),

        _SectionHeader('Encounter Trend',
            sub: dateRange.end.difference(dateRange.start).inDays > 365
                ? 'All time'
                : '${DateFormat('MMM yyyy').format(dateRange.start)} – ${DateFormat('MMM yyyy').format(dateRange.end)}'),
        const SizedBox(height: 10),
        _Card(child: SizedBox(
          height: 170,
          child: trends.isEmpty
              ? const _EmptyState('No encounter data in this range')
              : _TrendChart(data: trends, toInt: toInt),
        )),
        const SizedBox(height: 20),

        _SectionHeader('Quick Stats'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StripCard(label: 'Staff',    value: toInt(ss['total']),             color: _indigo)),
          const SizedBox(width: 10),
          Expanded(child: _StripCard(label: 'Active',   value: toInt(ss['active']),            color: _green)),
          const SizedBox(width: 10),
          Expanded(child: _StripCard(label: 'Urgent',   value: stats['urgentReferrals'] ?? 0,  color: _red)),
          const SizedBox(width: 10),
          Expanded(child: _StripCard(label: 'Pending',  value: stats['pendingReferrals'] ?? 0, color: _amber)),
        ]),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PATIENTS TAB
// ═══════════════════════════════════════════════════════════════════

class _PatientsTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int Function(dynamic) toInt;
  const _PatientsTab({required this.stats, required this.toInt});

  @override
  Widget build(BuildContext context) {
    final total  = toInt(stats['totalPatients']);
    final male   = toInt(stats['malePatients']);
    final female = toInt(stats['femalePatients']);
    final ages   = (stats['ageGroups'] as Map<String, int>?) ?? {};

    if (total == 0) return const _EmptyPage('No patient records yet');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _Card(child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.people_rounded, color: _blue, size: 26),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$total', style: const TextStyle(
                color: _textMain, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const Text('Total Patients', style: TextStyle(color: _textSub, fontSize: 13)),
          ]),
        ])),
        const SizedBox(height: 16),

        _SectionHeader('Gender Split'),
        const SizedBox(height: 10),
        _Card(child: Row(children: [
          Expanded(child: _GenderBar(label: 'Male',   count: male,   total: total, color: _blue)),
          Container(width: 1, height: 60, color: _border,
              margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(child: _GenderBar(label: 'Female', count: female, total: total,
              color: const Color(0xFFEC4899))),
        ])),
        const SizedBox(height: 16),

        _SectionHeader('Age Distribution'),
        const SizedBox(height: 10),
        _Card(child: Column(children: ages.entries.map((e) {
          final pct   = total > 0 ? e.value / total : 0.0;
          final colors = [_blue, _green, _amber, _red];
          final color  = colors[ages.keys.toList().indexOf(e.key) % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.key, style: const TextStyle(
                    color: _textMain, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${e.value}  •  ${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: pct, minHeight: 8,
                  backgroundColor: _border,
                  valueColor: AlwaysStoppedAnimation<Color>(color)),
              ),
            ]),
          );
        }).toList())),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ENCOUNTERS TAB
// ═══════════════════════════════════════════════════════════════════

class _EncountersTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int Function(dynamic) toInt;
  const _EncountersTab({required this.stats, required this.toInt});

  Color _typeColor(String t) {
    switch (t) {
      case 'emergency':  return _red;
      case 'inpatient':  return _indigo;
      case 'outpatient': return _green;
      case 'referral':   return _amber;
      case 'follow-up':  return _teal;
      default:           return _textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total  = toInt(stats['totalEncounters']);
    final trends = (stats['encounterTrends'] as List? ?? []).cast<Map<String, dynamic>>();
    final types  = (stats['encounterTypes']  as List? ?? []).cast<Map<String, dynamic>>();

    if (total == 0) return const _EmptyPage('No encounter records yet');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _Card(child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.medical_services_rounded, color: _green, size: 26),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$total', style: const TextStyle(
                color: _textMain, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const Text('Total Encounters', style: TextStyle(color: _textSub, fontSize: 13)),
          ]),
        ])),
        const SizedBox(height: 16),

        _SectionHeader('Daily Trend'),
        const SizedBox(height: 10),
        _Card(child: SizedBox(
          height: 170,
          child: trends.isEmpty
              ? const _EmptyState('No data in selected range')
              : _TrendChart(data: trends, toInt: toInt),
        )),
        const SizedBox(height: 16),

        if (types.isNotEmpty) ...[
          _SectionHeader('By Type'),
          const SizedBox(height: 10),
          _Card(child: Column(children: types.map((t) {
            final type  = t['type'] as String;
            final count = toInt(t['count']);
            final pct   = total > 0 ? count / total : 0.0;
            final color = _typeColor(type);
            final label = type[0].toUpperCase() + type.substring(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(label, style: const TextStyle(
                        color: _textMain, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  Text('$count  •  ${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: pct, minHeight: 8,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation<Color>(color)),
                ),
              ]),
            );
          }).toList())),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STAFF & REFERRALS TAB
// ═══════════════════════════════════════════════════════════════════

class _StaffReferralsTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool fromCache;
  final int Function(dynamic) toInt;
  const _StaffReferralsTab(
      {required this.stats, required this.fromCache, required this.toInt});

  @override
  Widget build(BuildContext context) {
    final ss          = (stats['staffStats'] as Map<String, dynamic>?) ?? {};
    final totalStaff  = toInt(ss['total']);
    final totalRef    = toInt(stats['totalReferrals']);
    final pendingRef  = toInt(stats['pendingReferrals']);
    final acceptRef   = toInt(stats['acceptedReferrals']);
    final doneRef     = toInt(stats['completedReferrals']);
    final rejectRef   = toInt(stats['rejectedReferrals']);
    final urgentRef   = toInt(stats['urgentReferrals']);
    final progRows    = (stats['programRows'] as List? ?? []).cast<Map<String, dynamic>>();
    final totalProg   = toInt(stats['totalPrograms']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (fromCache)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: _amber, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(
                ss['cachedAt'] != null
                    ? 'Staff data cached ${DateFormat('dd MMM HH:mm').format(DateTime.parse(ss['cachedAt'] as String))}'
                    : 'Staff data unavailable — connect to load',
                style: const TextStyle(color: _amber, fontSize: 11),
              )),
            ]),
          ),

        // Staff
        _SectionHeader('Staff'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StripCard(label: 'Total',    value: totalStaff,            color: _indigo)),
          const SizedBox(width: 10),
          Expanded(child: _StripCard(label: 'Active',   value: toInt(ss['active']),   color: _green)),
          const SizedBox(width: 10),
          Expanded(child: _StripCard(label: 'Inactive', value: toInt(ss['inactive']), color: _textSub)),
        ]),
        if (totalStaff > 0) ...[
          const SizedBox(height: 12),
          _Card(child: Column(children: [
            _ProgressRow('Doctors', toInt(ss['doctors']), totalStaff, _blue),
            const SizedBox(height: 12),
            _ProgressRow('Nurses',  toInt(ss['nurses']),  totalStaff, _teal),
            const SizedBox(height: 12),
            _ProgressRow('Admins',  toInt(ss['admins']),  totalStaff, _indigo),
          ])),
        ],
        const SizedBox(height: 20),

        // Referrals
        _SectionHeader('Referrals'),
        const SizedBox(height: 10),
        if (totalRef == 0)
          const _Card(child: _EmptyState('No referrals yet'))
        else ...[
          Row(children: [
            Expanded(child: _StripCard(label: 'Total',   value: totalRef,   color: _amber)),
            const SizedBox(width: 10),
            Expanded(child: _StripCard(label: 'Urgent',  value: urgentRef,  color: _red)),
            const SizedBox(width: 10),
            Expanded(child: _StripCard(label: 'Pending', value: pendingRef, color: _blue)),
          ]),
          const SizedBox(height: 12),
          _Card(child: Column(children: [
            _ProgressRow('Accepted',  acceptRef,  totalRef, _green),
            const SizedBox(height: 12),
            _ProgressRow('Completed', doneRef,    totalRef, _teal),
            const SizedBox(height: 12),
            _ProgressRow('Pending',   pendingRef, totalRef, _amber),
            const SizedBox(height: 12),
            _ProgressRow('Rejected',  rejectRef,  totalRef, _red),
          ])),
        ],
        const SizedBox(height: 20),

        if (progRows.isNotEmpty) ...[
          _SectionHeader('Disease Programs'),
          const SizedBox(height: 10),
          _Card(child: Column(children: progRows.map((r) {
            final prog  = r['program'] as String;
            final count = toInt(r['count']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProgressRow(_progLabel(prog), count, totalProg, _green),
            );
          }).toList())),
        ],
      ],
    );
  }

  String _progLabel(String key) => const {
    'hivArt':       'HIV/ART',
    'hypertension': 'Hypertension',
    'mch':          'MCH',
    'ncdDiabetes':  'Diabetes',
    'tb':           'Tuberculosis',
    'malaria':      'Malaria',
  }[key] ?? key;
}

// ═══════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? sub;
  const _SectionHeader(this.title, {this.sub});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(
          color: _textMain, fontSize: 15, fontWeight: FontWeight.w700)),
      if (sub != null)
        Text(sub!, style: const TextStyle(color: _textSub, fontSize: 11)),
    ],
  );
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: const TextStyle(
              color: _textMain, fontSize: 22, fontWeight: FontWeight.w900,
              letterSpacing: -0.5)),
          Text(label, style: const TextStyle(color: _textSub, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]),
  );
}

class _StripCard extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;
  const _StripCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2))),
    child: Column(children: [
      Text('$value', style: TextStyle(
          color: color, fontSize: 20, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: _textSub, fontSize: 10)),
    ]),
  );
}

class _GenderBar extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _GenderBar({required this.label, required this.count,
      required this.total, required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(
            color: _textMain, fontSize: 13, fontWeight: FontWeight.w600)),
        Text('$count', style: TextStyle(
            color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 4),
      Text('${(pct * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: pct, minHeight: 8,
          backgroundColor: _border,
          valueColor: AlwaysStoppedAnimation<Color>(color)),
      ),
    ]);
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _ProgressRow(this.label, this.count, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(children: [
      SizedBox(width: 86,
          child: Text(label, style: const TextStyle(color: _textSub, fontSize: 12))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: pct, minHeight: 8,
          backgroundColor: _border,
          valueColor: AlwaysStoppedAnimation<Color>(color)),
      )),
      const SizedBox(width: 10),
      SizedBox(width: 28,
          child: Text('$count', textAlign: TextAlign.right,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final int Function(dynamic) toInt;
  const _TrendChart({required this.data, required this.toInt});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), toInt(e.value['count']).toDouble()))
        .toList();
    final maxY = spots.map((s) => s.y).fold(0.0, math.max) * 1.25;

    return LineChart(LineChartData(
      minY: 0, maxY: maxY < 2 ? 5 : maxY,
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1),
        drawVerticalLine: false,
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) => Text('${v.toInt()}',
              style: const TextStyle(color: _textSub, fontSize: 9)),
        )),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20,
          interval: math.max(1, (data.length / 5).ceilToDouble()),
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= data.length) return const Text('');
            try {
              return Text(DateFormat('d/M').format(DateTime.parse(data[i]['date'] as String)),
                  style: const TextStyle(color: _textSub, fontSize: 9));
            } catch (_) { return const Text(''); }
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [LineChartBarData(
        spots: spots,
        isCurved: true, curveSmoothness: 0.3,
        color: _green, barWidth: 2.5,
        dotData: FlDotData(show: spots.length <= 12),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [_green.withOpacity(0.15), _green.withOpacity(0)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
      )],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: _green,
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
            '${s.y.toInt()}',
            const TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 12),
          )).toList(),
        ),
      ),
    ));
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(msg, style: const TextStyle(color: _textSub, fontSize: 13)));
}

class _EmptyPage extends StatelessWidget {
  final String msg;
  const _EmptyPage(this.msg);
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.inbox_rounded, color: _border, size: 52),
      const SizedBox(height: 14),
      Text(msg, style: const TextStyle(color: _textSub, fontSize: 15)),
    ]),
  );
}