// lib/features/home/presentation/pages/analytics_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/schema.dart';
import 'shell_widgets.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;
  final DatabaseHelper _db = DatabaseHelper();
  
  Map<String, dynamic> _localStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      await _loadLocalData();
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocalData() async {
    final db = await _db.database;
    
    final localStats = <String, dynamic>{};
    
    localStats['patientStats'] = await _getPatientDemographics(db);
    
    final encounterTrends = await _getEncounterTrends(db);
    localStats['encounterTrends'] = encounterTrends;
    
    localStats['referralStats'] = await _getReferralStats(db);
    
    localStats['programStats'] = await _getProgramStats(db);
    
    if (mounted) {
      setState(() => _localStats = localStats);
    }
  }

  Future<Map<String, dynamic>> _getPatientDemographics(database) async {
    final result = await database.rawQuery('SELECT COUNT(*) as count FROM ${Tbl.patients}');
    final total = result.first['count'] as int? ?? 0;

    final now = DateTime.now();
    final ageGroups = {
      '0-17': 0,
      '18-35': 0,
      '36-50': 0,
      '51+': 0,
    };

    final patients = await database.query(Tbl.patients);
    for (var patient in patients) {
      final dob = DateTime.parse(patient[Col.dateOfBirth] as String);
      final age = now.year - dob.year;
      if (age <= 17) ageGroups['0-17'] = ageGroups['0-17']! + 1;
      else if (age <= 35) ageGroups['18-35'] = ageGroups['18-35']! + 1;
      else if (age <= 50) ageGroups['36-50'] = ageGroups['36-50']! + 1;
      else ageGroups['51+'] = ageGroups['51+']! + 1;
    }

    final maleResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.patients} WHERE ${Col.gender} = 'male'"
    );
    final femaleResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.patients} WHERE ${Col.gender} = 'female'"
    );
    
    final male = maleResult.first['count'] as int? ?? 0;
    final female = femaleResult.first['count'] as int? ?? 0;

    return {
      'total': total,
      'ageGroups': ageGroups,
      'male': male,
      'female': female,
    };
  }

  Future<List<Map<String, dynamic>>> _getEncounterTrends(database) async {
    final startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);

    final results = await database.rawQuery('''
      SELECT 
        DATE(${Col.encounterDate}) as date,
        COUNT(*) as count
      FROM ${Tbl.encounters}
      WHERE ${Col.encounterDate} BETWEEN ? AND ?
      GROUP BY DATE(${Col.encounterDate})
      ORDER BY date ASC
      LIMIT 30
    ''', [startDate, endDate]);

    return results.map((row) {
      return {
        'date': row['date'] as String,
        'count': row['count'] as int,
      };
    }).toList().cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _getReferralStats(database) async {
    final totalResult = await database.rawQuery('SELECT COUNT(*) as count FROM ${Tbl.referrals}');
    final total = totalResult.first['count'] as int? ?? 0;

    final pendingResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.referrals} WHERE ${Col.status} = 'pending'"
    );
    final acceptedResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.referrals} WHERE ${Col.status} = 'accepted'"
    );
    final completedResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.referrals} WHERE ${Col.status} = 'completed'"
    );
    final rejectedResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.referrals} WHERE ${Col.status} = 'rejected'"
    );

    final urgentResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.referrals} WHERE ${Col.priority} = 'urgent'"
    );

    final destinations = await database.rawQuery('''
      SELECT 
        ${Col.toFacilityName},
        COUNT(*) as count
      FROM ${Tbl.referrals}
      GROUP BY ${Col.toFacilityName}
      ORDER BY count DESC
      LIMIT 5
    ''');

    return {
      'total': total,
      'pending': pendingResult.first['count'] as int? ?? 0,
      'accepted': acceptedResult.first['count'] as int? ?? 0,
      'completed': completedResult.first['count'] as int? ?? 0,
      'rejected': rejectedResult.first['count'] as int? ?? 0,
      'urgent': urgentResult.first['count'] as int? ?? 0,
      'destinations': destinations,
    };
  }

  Future<Map<String, dynamic>> _getProgramStats(database) async {
    final totalResult = await database.rawQuery('SELECT COUNT(*) as count FROM ${Tbl.programEnrollments}');
    final total = totalResult.first['count'] as int? ?? 0;

    final activeResult = await database.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tbl.programEnrollments} WHERE ${Col.status} = 'active'"
    );

    final programs = await database.rawQuery('''
      SELECT 
        ${Col.program},
        COUNT(*) as count
      FROM ${Tbl.programEnrollments}
      GROUP BY ${Col.program}
      ORDER BY count DESC
    ''');

    return {
      'total': total,
      'active': activeResult.first['count'] as int? ?? 0,
      'programs': programs,
    };
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadAnalyticsData();
    }
  }

  Future<void> _shareReport() async {
    final text = '''
ClinicConnect Analytics Report
Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}
Range: ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}

Key Metrics:
• Total Patients: ${_localStats['patientStats']?['total'] ?? 0}
• Total Encounters: ${(_localStats['encounterTrends'] as List?)?.fold<int>(0, (sum, item) => sum + (item['count'] as int? ?? 0)) ?? 0}
• Total Referrals: ${_localStats['referralStats']?['total'] ?? 0}
• Program Enrollments: ${_localStats['programStats']?['total'] ?? 0}
''';

    await Share.share(text, subject: 'ClinicConnect Analytics Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgSlate,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Analytics & Reports',
          style: TextStyle(
            color: Color(0xFF1A2E35),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kPrimaryGreen,
          labelColor: kPrimaryGreen,
          unselectedLabelColor: Colors.grey[600],
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Patients'),
            Tab(text: 'Referrals'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: kPrimaryGreen),
            onPressed: _shareReport,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, color: kPrimaryGreen),
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kPrimaryGreen),
            onPressed: _loadAnalyticsData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator.adaptive())
        : TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(
                dateRange: _selectedDateRange!,
                stats: _localStats,
              ),
              _PatientsAnalyticsTab(
                stats: _localStats,
              ),
              _ReferralsAnalyticsTab(
                stats: _localStats,
              ),
            ],
          ),
    );
  }
}

// ─── Overview Tab ───────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final DateTimeRange dateRange;
  final Map<String, dynamic> stats;

  const _OverviewTab({
    required this.dateRange,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final patientStats = stats['patientStats'] as Map<String, dynamic>? ?? {};
    final encounterTrends = stats['encounterTrends'] as List<Map<String, dynamic>>? ?? [];
    final referralStats = stats['referralStats'] as Map<String, dynamic>? ?? {};
    final programStats = stats['programStats'] as Map<String, dynamic>? ?? {};

    final totalEncounters = encounterTrends.fold<int>(
      0, 
      (sum, item) => sum + (item['count'] as int? ?? 0)
    );

    return RefreshIndicator(
      color: kPrimaryGreen,
      onRefresh: () async {
        // Refresh handled by parent
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: kPrimaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(dateRange.start)} - ${DateFormat('dd MMM yyyy').format(dateRange.end)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metric Cards
            Row(
              children: [
                Expanded(child: _MetricCard(
                  label: 'Patients',
                  value: patientStats['total'] ?? 0,
                  icon: Icons.people_rounded,
                  color: Colors.blue,
                )),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(
                  label: 'Encounters',
                  value: totalEncounters,
                  icon: Icons.medical_services_rounded,
                  color: Colors.teal,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCard(
                  label: 'Referrals',
                  value: referralStats['total'] ?? 0,
                  icon: Icons.swap_horiz_rounded,
                  color: Colors.orange,
                )),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(
                  label: 'Programs',
                  value: programStats['total'] ?? 0,
                  icon: Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF7C3AED),
                )),
              ],
            ),
            const SizedBox(height: 24),

            // Line Chart
            const Text('Encounter Trends', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: encounterTrends.isEmpty
                ? const Center(child: Text('No data'))
                : _LineChart(data: encounterTrends),
            ),
            const SizedBox(height: 24),

            // Gender Pie Chart
            const Text('Gender Distribution', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _GenderPieChart(
                male: patientStats['male'] ?? 0,
                female: patientStats['female'] ?? 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Simple Line Chart ─────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _LineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  final date = DateTime.parse(data[value.toInt()]['date']);
                  return Text(
                    DateFormat('dd').format(date),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['count'].toDouble())).toList(),
            isCurved: true,
            color: kPrimaryGreen,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

// ─── Simple Pie Chart ──────────────────────────────────────────────────────

class _GenderPieChart extends StatelessWidget {
  final int male;
  final int female;

  const _GenderPieChart({required this.male, required this.female});

  @override
  Widget build(BuildContext context) {
    final total = male + female;
    if (total == 0) return const Center(child: Text('No data'));

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: male.toDouble(),
            title: 'Male\n$male',
            color: Colors.blue,
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          PieChartSectionData(
            value: female.toDouble(),
            title: 'Female\n$female',
            color: Colors.pink,
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
        sectionsSpace: 0,
        centerSpaceRadius: 40,
      ),
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Patients Tab ─────────────────────────────────────────────────────────

class _PatientsAnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _PatientsAnalyticsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final patientStats = stats['patientStats'] as Map<String, dynamic>? ?? {};
    final ageGroups = patientStats['ageGroups'] as Map<String, int>? ?? {};
    final total = patientStats['total'] ?? 0;

    if (total == 0) {
      return const Center(child: Text('No patient data'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: ageGroups.entries.map((e) {
                final percentage = (e.value / total) * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(width: 50, child: Text(e.key)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(_getColor(e.key)),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${percentage.toStringAsFixed(1)}%'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  label: 'Male',
                  count: patientStats['male'] ?? 0,
                  total: total,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderCard(
                  label: 'Female',
                  count: patientStats['female'] ?? 0,
                  total: total,
                  color: Colors.pink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColor(String group) {
    switch (group) {
      case '0-17': return Colors.blue;
      case '18-35': return Colors.teal;
      case '36-50': return Colors.orange;
      case '51+': return const Color(0xFF7C3AED);
      default: return kPrimaryGreen;
    }
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _GenderCard({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 8,
                ),
              ),
              Column(
                children: [
                  Text('${percentage.toStringAsFixed(1)}%'),
                  Text(count.toString(), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Referrals Tab ────────────────────────────────────────────────────────

class _ReferralsAnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _ReferralsAnalyticsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final referralStats = stats['referralStats'] as Map<String, dynamic>? ?? {};
    final total = referralStats['total'] ?? 0;

    if (total == 0) {
      return const Center(child: Text('No referral data'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PriorityCard(
                  label: 'Urgent',
                  count: referralStats['urgent'] ?? 0,
                  total: total,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PriorityCard(
                  label: 'Normal',
                  count: (total - (referralStats['urgent'] ?? 0)),
                  total: total,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildStatusRow('Pending', referralStats['pending'] ?? 0, total, Colors.orange),
                const SizedBox(height: 12),
                _buildStatusRow('Accepted', referralStats['accepted'] ?? 0, total, Colors.green),
                const SizedBox(height: 12),
                _buildStatusRow('Completed', referralStats['completed'] ?? 0, total, Colors.blue),
                const SizedBox(height: 12),
                _buildStatusRow('Rejected', referralStats['rejected'] ?? 0, total, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) * 100 : 0;
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text('$count'),
        const SizedBox(width: 12),
        SizedBox(width: 50, child: Text('${percentage.toStringAsFixed(1)}%', textAlign: TextAlign.right)),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PriorityCard({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(label == 'Urgent' ? Icons.priority_high_rounded : Icons.check_circle_rounded, color: color),
          const SizedBox(height: 8),
          Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}