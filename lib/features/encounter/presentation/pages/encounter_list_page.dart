// lib/features/encounter/presentation/pages/encounter_list_page.dart
//
// Facility encounter list — loads from Firestore (source of truth) and
// falls back to / merges with local SQLite so it works fully offline.
// Never touches the HIE gateway — clinical data stays in the facility.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/schema.dart';
import '../../../../injection_container.dart';
import 'encounter_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _EncounterRow {
  final String id;
  final String patientName;
  final String patientNupi;
  final String type;
  final String? chiefComplaint;
  final String? clinicianName;
  final DateTime encounterDate;
  final String source; // 'firestore' | 'local'
  final Map<String, dynamic> raw;

  const _EncounterRow({
    required this.id,
    required this.patientName,
    required this.patientNupi,
    required this.type,
    this.chiefComplaint,
    this.clinicianName,
    required this.encounterDate,
    required this.source,
    required this.raw,
  });

  /// From a Firestore document. Handles snake_case (Flutter app writes)
  /// and camelCase (Node.js backend writes).
  factory _EncounterRow.fromFirestore(Map<String, dynamic> d) {
    T? r<T>(String snake, String camel) => (d[snake] ?? d[camel]) as T?;

    final rawDate = d['encounter_date'] ?? d['encounterDate'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is String && rawDate.isNotEmpty
            ? DateTime.tryParse(rawDate) ?? DateTime.now()
            : DateTime.now();

    final nupi = r<String>('patient_nupi', 'patientNupi') ?? '';
    final name = r<String>('patient_name', 'patientName') ?? '';

    return _EncounterRow(
      id:            d['id'] as String? ?? '',
      patientName:   name.isNotEmpty ? name : (nupi.isNotEmpty ? 'NUPI: $nupi' : 'Unknown'),
      patientNupi:   nupi,
      type:          r<String>('type', 'type') ??
                     r<String>('encounter_type', 'encounterType') ??
                     'visit',
      chiefComplaint: r<String>('chief_complaint', 'chiefComplaint'),
      clinicianName:  r<String>('clinician_name',    'clinicianName') ??
                      r<String>('practitioner_name', 'practitionerName'),
      encounterDate:  date,
      source:         'firestore',
      raw:            d,
    );
  }

  /// From a SQLite row.
  factory _EncounterRow.fromSqlite(Map<String, dynamic> d) {
    return _EncounterRow(
      id:            d[Col.id]          as String? ?? '',
      patientName:   d[Col.patientName] as String? ?? 'Unknown',
      patientNupi:   d[Col.patientNupi] as String? ?? '',
      type:          d[Col.type]        as String? ?? 'visit',
      chiefComplaint: d[Col.chiefComplaint] as String?,
      clinicianName:  d[Col.clinicianName]  as String?,
      encounterDate:  DateTime.tryParse(d[Col.encounterDate] as String? ?? '') ??
                      DateTime.now(),
      source:         'local',
      raw:            Map<String, dynamic>.from(d),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class EncounterListPage extends StatefulWidget {
  final String? facilityId;
  const EncounterListPage({super.key, this.facilityId});

  @override
  State<EncounterListPage> createState() => _EncounterListPageState();
}

class _EncounterListPageState extends State<EncounterListPage> {
  static const _primary = Color(0xFF1B4332);
  static const _bg      = Color(0xFFF1F5F9);

  String get _facilityId =>
      (widget.facilityId ?? FacilityInfo().facilityId).trim();

  bool   _loading   = true;
  String? _error;
  List<_EncounterRow> _encounters = [];
  String _search    = '';
  String _filter    = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _fetchMerged();
      if (mounted) setState(() { _encounters = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Firestore first, SQLite fills any gaps (offline / pending sync rows).
  Future<List<_EncounterRow>> _fetchMerged() async {
    final seen = <String>{};
    final rows = <_EncounterRow>[];

    // 1. Firestore ────────────────────────────────────────────────────
    try {
      final snap = await FirebaseConfig.facilityDb
          .collection('encounters')
          .where('facility_id', isEqualTo: _facilityId)
          .orderBy('encounter_date', descending: true)
          .limit(100)
          .get(const GetOptions(source: Source.serverAndCache));

      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final row = _EncounterRow.fromFirestore(data);
        if (row.id.isNotEmpty && seen.add(row.id)) rows.add(row);
      }
      debugPrint('[EncounterList] Firestore: ${rows.length} encounters');
    } catch (e) {
      debugPrint('[EncounterList] Firestore failed: $e');
    }

    // 2. SQLite — adds pending/offline rows not yet in Firestore ─────
    try {
      final db = await sl<DatabaseHelper>().database;
      final sqlRows = await db.query(
        Tbl.encounters,
        where:     '${Col.facilityId} = ?',
        whereArgs: [_facilityId],
        orderBy:   '${Col.encounterDate} DESC',
        limit:     100,
      );
      for (final row in sqlRows) {
        final r = _EncounterRow.fromSqlite(row);
        if (r.id.isNotEmpty && seen.add(r.id)) rows.add(r);
      }
      debugPrint('[EncounterList] SQLite added: ${sqlRows.length} rows');
    } catch (e) {
      debugPrint('[EncounterList] SQLite failed: $e');
    }

    rows.sort((a, b) => b.encounterDate.compareTo(a.encounterDate));
    return rows;
  }

  // ── Filtering ─────────────────────────────────────────────────────

  List<_EncounterRow> get _filtered {
    var list = _encounters;
    if (_filter != 'all') {
      list = list.where((e) => e.type == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
        e.patientName.toLowerCase().contains(q) ||
        e.patientNupi.toLowerCase().contains(q) ||
        (e.chiefComplaint?.toLowerCase().contains(q) ?? false) ||
        e.type.toLowerCase().contains(q),
      ).toList();
    }
    return list;
  }

  Set<String> get _types => _encounters.map((e) => e.type).toSet();

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_types.length > 1) _buildTypeFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Encounters',
            style: TextStyle(
              color: _primary, fontWeight: FontWeight.w900, fontSize: 20,
            ),
          ),
          Text(
            '${_filtered.length} record${_filtered.length == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
      actions: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _primary),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search by patient, NUPI or complaint...',
          prefixIcon: const Icon(Icons.search_rounded, color: _primary, size: 20),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          filled: true,
          fillColor: _bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    final types = ['all', ..._types.toList()..sort()];
    return Container(
      color: Colors.white,
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t        = types[i];
          final selected = _filter == t;
          return GestureDetector(
            onTap: () => setState(() => _filter = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? _primary : _bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t == 'all' ? 'All' : _typeLabel(t),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _encounters.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null && _encounters.isEmpty) {
      return _buildError();
    }
    final list = _filtered;
    if (list.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) => _EncounterCard(
          row:   list[i],
          onTap: () => _openDetail(list[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final hasFilter = _search.isNotEmpty || _filter != 'all';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilter
                  ? Icons.search_off_rounded
                  : Icons.medical_services_outlined,
              size: 56, color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'No matching encounters' : 'No encounters yet',
              style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? 'Try clearing the search or filter'
                  : 'Open a patient and document a clinical visit',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() { _search = ''; _filter = 'all'; });
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 52, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Could not load encounters',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(_EncounterRow row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EncounterDetailPage(
          encounter:   row.raw,
          patientName: row.patientName,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'outpatient': return 'Outpatient';
      case 'inpatient':  return 'Inpatient';
      case 'emergency':  return 'Emergency';
      case 'referral':   return 'Referral';
      case 'check-in':   return 'Check-in';
      case 'follow-up':  return 'Follow-up';
      default:
        return type.isNotEmpty
            ? type[0].toUpperCase() + type.substring(1)
            : 'Visit';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Encounter card
// ─────────────────────────────────────────────────────────────────────────────

class _EncounterCard extends StatelessWidget {
  final _EncounterRow row;
  final VoidCallback  onTap;

  const _EncounterCard({required this.row, required this.onTap});

  static const _primary = Color(0xFF1B4332);

  Color get _typeColor {
    switch (row.type) {
      case 'emergency': return Colors.red;
      case 'inpatient': return Colors.indigo;
      case 'referral':  return Colors.orange;
      case 'follow-up': return Colors.teal;
      default:          return _primary;
    }
  }

  IconData get _typeIcon {
    switch (row.type) {
      case 'emergency': return Icons.emergency_rounded;
      case 'inpatient': return Icons.hotel_rounded;
      case 'referral':  return Icons.swap_horiz_rounded;
      default:          return Icons.medical_services_rounded;
    }
  }

  String _chip(String type) {
    switch (type) {
      case 'outpatient': return 'OPD';
      case 'inpatient':  return 'IPD';
      case 'emergency':  return 'EMRG';
      case 'referral':   return 'REF';
      case 'check-in':   return 'CHK';
      case 'follow-up':  return 'F/U';
      default:
        return type.toUpperCase().substring(0, type.length.clamp(0, 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Type icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        row.chiefComplaint ?? _chip(row.type),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (row.clinicianName != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.person_outline_rounded,
                              size: 11, color: Colors.grey[400]),
                          const SizedBox(width: 3),
                          Text(
                            row.clinicianName!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right: date + chip + offline indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('dd MMM').format(row.encounterDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(row.encounterDate),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _chip(row.type),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _typeColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (row.source == 'local') ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 9, color: Colors.orange[300]),
                          const SizedBox(width: 2),
                          Text('pending',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.orange[300])),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}