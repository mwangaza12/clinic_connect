// lib/features/home/presentation/pages/analytics_page.dart
//
// OFFLINE-FIRST ANALYTICS:
//
//   Patient / Encounter / Referral / Program stats:
//     Always read from SQLite — immediately available offline.
//
//   Staff stats:
//     Online  → Firestore → cache result in SharedPreferences
//     Offline → SharedPreferences cache (last known values)
//     If never synced → show zeros with an offline indicator
//
// This matches the rest of the app's offline-first architecture.

import 'dart:convert';
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

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;
  final DatabaseHelper _db = DatabaseHelper();
  final FacilityInfo _facilityInfo = FacilityInfo();

  Map<String, dynamic> _localStats = {};
  bool _isLoading       = true;
  bool _staffFromCache  = false; // true when showing cached/offline staff data

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Main loader ────────────────────────────────────────────────

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      // SQLite data — always available, no network needed
      await _loadLocalData();
      // Staff data — online fetch → cache; offline → cache fallback
      await _loadStaffData();
    } catch (e) {
      debugPrint('[Analytics] Error loading: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocalData() async {
    final db = await _db.database;
    final localStats = <String, dynamic>{};
    localStats['patientStats']   = await _getPatientDemographics(db);
    localStats['encounterTrends'] = await _getEncounterTrends(db);
    localStats['referralStats']  = await _getReferralStats(db);
    localStats['programStats']   = await _getProgramStats(db);
    if (mounted) setState(() => _localStats = {..._localStats, ...localStats});
  }

  // ── Staff data — offline-first ─────────────────────────────────
  //
  // Flow:
  //   1. Check SharedPreferences for a cached result (always fast)
  //   2. If online, fetch from Firestore and update the cache
  //   3. If offline (or Firestore fails), show the cached result
  //   4. Flag _staffFromCache so the UI can show an indicator

  Future<void> _loadStaffData() async {
    final facilityId = _facilityInfo.facilityId;
    if (facilityId.isEmpty) return;

    // Step 1 — load cache immediately so UI has something to show
    final cached = await _readStaffCache(facilityId);
    if (cached != null && mounted) {
      setState(() {
        _localStats['staffStats'] = cached;
        _staffFromCache = true;
      });
    }

    // Step 2 — try live Firestore if online
    final online = await ConnectivityManager().checkConnectivity();
    if (!online) {
      // Offline — cached data (or zeros) is all we have
      if (cached == null && mounted) {
        setState(() {
          _localStats['staffStats'] = _emptyStaffStats();
          _staffFromCache = true;
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseConfig.facilityDb
          .collection('users')
          .where('facility_id', isEqualTo: facilityId)
          .get();

      int total = snapshot.docs.length;
      int doctors = 0, nurses = 0, admins = 0, active = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final role     = data['role']      as String? ?? '';
        final isActive = data['is_active'] as bool?   ?? true;
        if (isActive) active++;
        if (role == 'doctor') doctors++;
        else if (role == 'nurse') nurses++;
        else if (role == 'admin') admins++;
      }

      final fresh = {
        'total':    total,
        'doctors':  doctors,
        'nurses':   nurses,
        'admins':   admins,
        'active':   active,
        'inactive': total - active,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      // Save to cache for next offline load
      await _writeStaffCache(facilityId, fresh);

      if (mounted) {
        setState(() {
          _localStats['staffStats'] = fresh;
          _staffFromCache = false;
        });
      }
    } catch (e) {
      debugPrint('[Analytics] Firestore staff fetch failed: $e');
      // Cache already applied in step 1 — nothing more to do
    }
  }

  // ── Cache helpers ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> _readStaffCache(String facilityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('${_kStaffCacheKey}_$facilityId');
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeStaffCache(
      String facilityId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_kStaffCacheKey}_$facilityId', jsonEncode(data));
    } catch (_) {}
  }

  Map<String, dynamic> _emptyStaffStats() => {
    'total': 0, 'doctors': 0, 'nurses': 0,
    'admins': 0, 'active': 0, 'inactive': 0,
  };

  // ── SQLite queries ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _getPatientDemographics(db) async {
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${Tbl.patients}');
    final total = _toInt(result.first['count']);

    final now = DateTime.now();
    final ageGroups = {'0-17': 0, '18-35': 0, '36-50': 0, '51+': 0};

    final patients = await db.query(Tbl.patients);
    for (final patient in patients) {
      try {
        final dob = DateTime.parse(patient[Col.dateOfBirth] as String);
        final age = now.year - dob.year;
        if (age <= 17)      ageGroups['0-17']  = ageGroups['0-17']!  + 1;
        else if (age <= 35) ageGroups['18-35'] = ageGroups['18-35']! + 1;
        else if (age <= 50) ageGroups['36-50'] = ageGroups['36-50']! + 1;
        else                ageGroups['51+']   = ageGroups['51+']!   + 1;
      } catch (_) {}
    }

    final maleResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM ${Tbl.patients} WHERE ${Col.gender}='male'");
    final femaleResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM ${Tbl.patients} WHERE ${Col.gender}='female'");
    
    final male = _toInt(maleResult.first['count']);
    final female = _toInt(femaleResult.first['count']);

    return {'total': total, 'ageGroups': ageGroups, 'male': male, 'female': female};
  }

  Future<List<Map<String, dynamic>>> _getEncounterTrends(db) async {
    final startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
    final endDate   = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);

    final results = await db.rawQuery('''
      SELECT DATE(${Col.encounterDate}) as date, COUNT(*) as count
      FROM ${Tbl.encounters}
      WHERE ${Col.encounterDate} BETWEEN ? AND ?
      GROUP BY DATE(${Col.encounterDate})
      ORDER BY date ASC
      LIMIT 30
    ''', [startDate, endDate]);

    return results
        .map((r) => {
          'date': r['date'] as String, 
          'count': _toInt(r['count'])
        })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _getReferralStats(db) async {
    final totalResult = await db.rawQuery('SELECT COUNT(*) FROM ${Tbl.referrals}');
    final total = _toInt(totalResult.first.values.first);

    final pendingResult = await db.rawQuery(
        "SELECT COUNT(*) FROM ${Tbl.referrals} WHERE ${Col.status}='pending'");
    final pending = _toInt(pendingResult.first.values.first);

    final acceptedResult = await db.rawQuery(
        "SELECT COUNT(*) FROM ${Tbl.referrals} WHERE ${Col.status}='accepted'");
    final accepted = _toInt(acceptedResult.first.values.first);

    final completedResult = await db.rawQuery(
        "SELECT COUNT(*) FROM ${Tbl.referrals} WHERE ${Col.status}='completed'");
    final completed = _toInt(completedResult.first.values.first);

    final rejectedResult = await db.rawQuery(
        "SELECT COUNT(*) FROM ${Tbl.referrals} WHERE ${Col.status}='rejected'");
    final rejected = _toInt(rejectedResult.first.values.first);

    final urgentResult = await db.rawQuery(
        "SELECT COUNT(*) FROM ${Tbl.referrals} WHERE ${Col.priority}='urgent'");
    final urgent = _toInt(urgentResult.first.values.first);

    final destinations = await db.rawQuery('''
      SELECT ${Col.toFacilityName}, COUNT(*) as count
      FROM ${Tbl.referrals}
      GROUP BY ${Col.toFacilityName}
      ORDER BY count DESC LIMIT 5
    ''');

    return {
      'total': total, 'pending': pending, 'accepted': accepted,
      'completed': completed, 'rejected': rejected,
      'urgent': urgent, 'destinations': destinations,
    };
  }

  Future<Map<String, dynamic>> _getProgramStats(db) async {
    final totalResult = await db.rawQuery('SELECT COUNT(*) FROM ${Tbl.programEnrollments}');
    final total = _toInt(totalResult.first.values.first);

    final activeResult = await db.rawQuery(
        "SELECT COUNT(*) FROM ${Tbl.programEnrollments} WHERE ${Col.status}='active'");
    final active = _toInt(activeResult.first.values.first);

    final programs = await db.rawQuery('''
      SELECT ${Col.program}, COUNT(*) as count
      FROM ${Tbl.programEnrollments}
      GROUP BY ${Col.program} ORDER BY count DESC
    ''');

    return {'total': total, 'active': active, 'programs': programs};
  }

  // Helper to safely convert any number type to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ── Date picker ─────────────────────────────────────────────────

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kPrimaryGreen, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadAnalyticsData();
    }
  }

  // ── Share ────────────────────────────────────────────────────────

  Future<void> _shareReport() async {
    final ps  = _localStats['patientStats']   as Map? ?? {};
    final ss  = _localStats['staffStats']     as Map? ?? {};
    final rs  = _localStats['referralStats']  as Map? ?? {};
    final prs = _localStats['programStats']   as Map? ?? {};
    final et  = _localStats['encounterTrends'] as List? ?? [];
    final totalEnc = et.fold<int>(0, (s, i) => s + _toInt(i['count']));
    final cached = _staffFromCache ? ' (cached)' : '';

    await Share.share('''
ClinicConnect Analytics Report
Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}
Range: ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}

📊 KEY METRICS
• Total Patients: ${ps['total'] ?? 0}
• Total Encounters: $totalEnc
• Total Referrals: ${rs['total'] ?? 0}
• Program Enrollments: ${prs['total'] ?? 0}

👥 STAFF SUMMARY$cached
• Total Staff: ${ss['total'] ?? 0}
• Active: ${ss['active'] ?? 0}
• Doctors: ${ss['doctors'] ?? 0}
• Nurses: ${ss['nurses'] ?? 0}
• Admins: ${ss['admins'] ?? 0}

📈 REFERRAL STATUS
• Pending: ${rs['pending'] ?? 0}
• Accepted: ${rs['accepted'] ?? 0}
• Completed: ${rs['completed'] ?? 0}
• Rejected: ${rs['rejected'] ?? 0}
''', subject: 'ClinicConnect Analytics Report');
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgSlate,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analytics & Reports',
                style: TextStyle(
                    color: Color(0xFF1A2E35),
                    fontWeight: FontWeight.w700, fontSize: 18)),
            if (_staffFromCache)
              const Text('Staff data from cache (offline)',
                  style: TextStyle(fontSize: 10, color: Colors.orange)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kPrimaryGreen,
          labelColor: kPrimaryGreen,
          unselectedLabelColor: Colors.grey[600],
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Patients'),
            Tab(text: 'Staff'),
            Tab(text: 'Referrals'),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.share_rounded, color: kPrimaryGreen),
              onPressed: _shareReport),
          IconButton(
              icon: const Icon(Icons.calendar_today_rounded, color: kPrimaryGreen),
              onPressed: () => _selectDateRange(context)),
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: kPrimaryGreen),
              onPressed: _loadAnalyticsData),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                    dateRange: _selectedDateRange!, stats: _localStats),
                _PatientsAnalyticsTab(stats: _localStats),
                _StaffAnalyticsTab(
                    stats: _localStats, fromCache: _staffFromCache),
                _ReferralsAnalyticsTab(stats: _localStats),
              ],
            ),
    );
  }
}


// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final DateTimeRange dateRange;
  final Map<String, dynamic> stats;

  const _OverviewTab({required this.dateRange, required this.stats});

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final ps  = stats['patientStats']    as Map<String, dynamic>? ?? {};
    final ss  = stats['staffStats']      as Map<String, dynamic>? ?? {};
    final et  = stats['encounterTrends'] as List<Map<String, dynamic>>? ?? [];
    final rs  = stats['referralStats']   as Map<String, dynamic>? ?? {};
    final prs = stats['programStats']    as Map<String, dynamic>? ?? {};
    final totalEnc = et.fold<int>(0, (s, i) => s + _toInt(i['count']));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: kPrimaryGreen),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('dd MMM yyyy').format(dateRange.start)} — ${DateFormat('dd MMM yyyy').format(dateRange.end)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _MetricCard(label: 'Patients',  value: _toInt(ps['total']), icon: Icons.people_rounded, color: Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(label: 'Staff',     value: _toInt(ss['total']), icon: Icons.badge_rounded,  color: const Color(0xFF7C3AED))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _MetricCard(label: 'Encounters', value: totalEnc,              icon: Icons.medical_services_rounded, color: Colors.teal)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(label: 'Referrals',  value: _toInt(rs['total']),      icon: Icons.swap_horiz_rounded,       color: Colors.orange)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _MetricCard(label: 'Programs',    value: _toInt(prs['total']),  icon: Icons.assignment_turned_in_rounded, color: Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(label: 'Active Staff', value: _toInt(ss['active']), icon: Icons.check_circle_rounded,          color: Colors.green)),
          ]),
          const SizedBox(height: 24),
          const Text('Encounter Trends',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: et.isEmpty
                ? const Center(child: Text('No encounter data'))
                : _LineChart(data: et),
          ),
          const SizedBox(height: 24),
          const Text('Gender Distribution',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: _GenderPieChart(
                male: _toInt(ps['male']), female: _toInt(ps['female'])),
          ),
        ],
      ),
    );
  }
}

// ─── Staff Analytics Tab ──────────────────────────────────────────────────────

class _StaffAnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool fromCache;

  const _StaffAnalyticsTab({required this.stats, required this.fromCache});

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final ss    = stats['staffStats'] as Map<String, dynamic>? ?? {};
    final total = _toInt(ss['total']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline cache banner
          if (fromCache)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ss['cachedAt'] != null
                        ? 'Offline — showing data from ${DateFormat('dd MMM, HH:mm').format(DateTime.parse(ss['cachedAt'] as String))}'
                        : 'Offline — no cached staff data available yet. Connect to load.',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ]),
            ),

          if (total == 0 && !fromCache)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('No staff data available'),
            ))
          else ...[
            Row(children: [
              Expanded(child: _StaffSummaryCard(label: 'Total Staff', value: _toInt(ss['total']),    icon: Icons.people_rounded,          color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StaffSummaryCard(label: 'Active',      value: _toInt(ss['active']),   icon: Icons.check_circle_rounded,     color: Colors.green)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StaffSummaryCard(label: 'Inactive', value: _toInt(ss['inactive']), icon: Icons.block_rounded,            color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _StaffSummaryCard(label: 'Doctors',  value: _toInt(ss['doctors']),  icon: Icons.medical_services_rounded, color: Colors.blue)),
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Staff by Role',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildRoleProgress('Doctors', _toInt(ss['doctors']), total, Colors.blue),
                  const SizedBox(height: 16),
                  _buildRoleProgress('Nurses',  _toInt(ss['nurses']),  total, Colors.teal),
                  const SizedBox(height: 16),
                  _buildRoleProgress('Admins',  _toInt(ss['admins']),  total, const Color(0xFF7C3AED)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                const Text('Staff Status',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _StaffStatusPieChart(
                      active:   _toInt(ss['active']),
                      inactive: _toInt(ss['inactive'])),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleProgress(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('$count (${(pct * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: pct,
        backgroundColor: Colors.grey[200],
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 10,
        borderRadius: BorderRadius.circular(5),
      ),
    ]);
  }
}

// ── Reusable widgets ────────────────────────────────────────────────

class _StaffSummaryCard extends StatelessWidget {
  final String label; final int value; final IconData icon; final Color color;
  const _StaffSummaryCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 12),
      Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
    ]),
  );
}

class _StaffStatusPieChart extends StatelessWidget {
  final int active; final int inactive;
  const _StaffStatusPieChart({required this.active, required this.inactive});
  @override
  Widget build(BuildContext context) {
    if (active + inactive == 0) return const Center(child: Text('No data'));
    return PieChart(PieChartData(sections: [
      PieChartSectionData(value: active.toDouble(),   title: 'Active\n$active',   color: Colors.green,  radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: inactive.toDouble(), title: 'Inactive\n$inactive', color: Colors.orange, radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
    ], sectionsSpace: 2, centerSpaceRadius: 30));
  }
}

class _LineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _LineChart({required this.data});
  
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }
  
  @override
  Widget build(BuildContext context) => LineChart(LineChartData(
    gridData: FlGridData(show: false),
    titlesData: FlTitlesData(
      leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
      rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
        getTitlesWidget: (v, _) {
          final i = v.toInt();
          if (i < 0 || i >= data.length) return const Text('');
          return Text(DateFormat('dd').format(DateTime.parse(data[i]['date'])),
              style: const TextStyle(fontSize: 10));
        })),
    ),
    borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
    lineBarsData: [LineChartBarData(
      spots: data.asMap().entries.map((e) => 
        FlSpot(e.key.toDouble(), _toInt(e.value['count']).toDouble())).toList(),
      isCurved: true, color: kPrimaryGreen, barWidth: 3,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    )],
  ));
}

class _GenderPieChart extends StatelessWidget {
  final int male; final int female;
  const _GenderPieChart({required this.male, required this.female});
  @override
  Widget build(BuildContext context) {
    if (male + female == 0) return const Center(child: Text('No data'));
    return PieChart(PieChartData(sections: [
      PieChartSectionData(value: male.toDouble(),   title: 'Male\n$male',     color: Colors.blue, radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: female.toDouble(), title: 'Female\n$female', color: Colors.pink, radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
    ], sectionsSpace: 2, centerSpaceRadius: 30));
  }
}

class _MetricCard extends StatelessWidget {
  final String label; final int value; final IconData icon; final Color color;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 12),
      Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
    ]),
  );
}

// ─── Patients Tab ─────────────────────────────────────────────────────────────

class _PatientsAnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _PatientsAnalyticsTab({required this.stats});

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  Color _colorFor(String g) {
    switch (g) {
      case '0-17':  return Colors.blue;
      case '18-35': return Colors.teal;
      case '36-50': return Colors.orange;
      default:      return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ps        = stats['patientStats'] as Map<String, dynamic>? ?? {};
    final ageGroups = ps['ageGroups'] as Map<String, int>? ?? {};
    final total     = _toInt(ps['total']);

    if (total == 0) return const Center(child: Text('No patient data'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: ageGroups.entries.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                SizedBox(width: 50, child: Text(e.key)),
                Expanded(child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(_colorFor(e.key)),
                  minHeight: 8, borderRadius: BorderRadius.circular(4),
                )),
                const SizedBox(width: 12),
                Text('${(pct * 100).toStringAsFixed(1)}%'),
              ]),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _GenderCard(label: 'Male',   count: _toInt(ps['male']),   total: total, color: Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _GenderCard(label: 'Female', count: _toInt(ps['female']), total: total, color: Colors.pink)),
        ]),
      ]),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label; final int count; final int total; final Color color;
  const _GenderCard({required this.label, required this.count, required this.total, required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 80, height: 80,
            child: CircularProgressIndicator(
              value: pct, backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color), strokeWidth: 8)),
          Column(children: [
            Text('${(pct * 100).toStringAsFixed(1)}%'),
            Text(count.toString(), style: const TextStyle(fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Referrals Tab ────────────────────────────────────────────────────────────

class _ReferralsAnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ReferralsAnalyticsTab({required this.stats});

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  Widget _statusRow(String label, dynamic countValue, int total, Color color) {
    final count = _toInt(countValue);
    final pct = total > 0 ? count / total : 0.0;
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      Text('$count'),
      const SizedBox(width: 12),
      SizedBox(width: 50, child: Text('${(pct * 100).toStringAsFixed(1)}%', textAlign: TextAlign.right)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final rs    = stats['referralStats'] as Map<String, dynamic>? ?? {};
    final total = _toInt(rs['total']);
    final urgent = _toInt(rs['urgent']);

    if (total == 0) return const Center(child: Text('No referral data'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _PriorityCard(
            label: 'Urgent', 
            count: urgent, 
            total: total, 
            color: Colors.red
          )),
          const SizedBox(width: 12),
          Expanded(child: _PriorityCard(
            label: 'Normal', 
            count: total - urgent,  // Both are now int
            total: total, 
            color: Colors.green
          )),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            _statusRow('Pending',   rs['pending'],   total, Colors.orange),
            const SizedBox(height: 12),
            _statusRow('Accepted',  rs['accepted'],  total, Colors.green),
            const SizedBox(height: 12),
            _statusRow('Completed', rs['completed'], total, Colors.blue),
            const SizedBox(height: 12),
            _statusRow('Rejected',  rs['rejected'],  total, Colors.red),
          ]),
        ),
      ]),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final String label; final int count; final int total; final Color color;
  const _PriorityCard({required this.label, required this.count, required this.total, required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(label == 'Urgent' ? Icons.priority_high_rounded : Icons.check_circle_rounded, color: color),
        const SizedBox(height: 8),
        Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: pct, backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6),
      ]),
    );
  }
}