import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/encounter.dart';
import '../../../../core/services/backend_api_service.dart';
import 'edit_encounter_page.dart';

extension MapExtension on Map<String, dynamic> {
  dynamic safeGet(List<String> keys, {dynamic defaultValue}) {
    dynamic value = this;
    for (final key in keys) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else {
        return defaultValue;
      }
    }
    return value;
  }
}

class EncounterDetailPage extends StatefulWidget {
  final dynamic encounter; // Either local Encounter entity or FHIR Map
  final String? patientName;
  final String? accessToken;
  final bool isFederated;

  const EncounterDetailPage({
    super.key,
    required this.encounter,
    this.patientName,
    this.accessToken,
    this.isFederated = false,
  });

  @override
  State<EncounterDetailPage> createState() => _EncounterDetailPageState();
}

class _EncounterDetailPageState extends State<EncounterDetailPage> {
  static const Color _primary = Color(0xFF1B4332);

  /// True when the encounter passed in is a raw FHIR map (not a local entity).
  bool get _isFhirMap => widget.encounter is Map<String, dynamic>;

  /// The resolved full encounter — starts as the passed-in map,
  /// then gets replaced with the full fetch result.
  Map<String, dynamic>? _fullEncounter;
  bool _fetching = false;
  String? _fetchError;

  /// Local (non-FHIR) encounter — starts as the passed-in entity,
  /// gets replaced when the user saves edits.
  late Encounter? _localEncounter;

  @override
  void initState() {
    super.initState();
    _localEncounter = _isFhirMap ? null : widget.encounter as Encounter;
    if (_isFhirMap) {
      _fullEncounter = widget.encounter as Map<String, dynamic>;
      // Federated (cross-facility) encounters: the map passed from the
      // patient lookup page is already fully populated from the $everything
      // bundle — no extra network call needed or possible (the backend has
      // no single-encounter-by-ID route for other facilities' data).
      // Only attempt enrichment for non-federated FHIR maps.
      if (!widget.isFederated) {
        _fetchFullEncounter();
      }
    }
  }

  Future<void> _fetchFullEncounter() async {
    final enc = widget.encounter as Map<String, dynamic>;
    final encounterId = enc['id']?.toString();
    final facilityId  = enc['meta']?['source']?.toString();

    if (encounterId == null || encounterId.isEmpty) return;

    setState(() { _fetching = true; _fetchError = null; });

    try {
      debugPrint('📋 Fetching full encounter: $encounterId from $facilityId');

      final backend = await BackendApiService.instanceAsync;
      final result  = await backend.getFhirEncounter(
        encounterId: encounterId,
        facilityId:  facilityId,
      );

      if (!mounted) return;

      if (result.success && result.data != null) {
        final body = result.data!;
        if (body['resourceType'] == 'Bundle') {
          final entries = body['entry'] as List? ?? [];
          if (entries.isNotEmpty) {
            final resource = entries.first['resource'] as Map<String, dynamic>?;
            if (resource != null) {
              setState(() => _fullEncounter = resource);
              debugPrint('✅ Got full encounter from bundle');
              return;
            }
          }
        }
        if (body['resourceType'] == 'Encounter') {
          setState(() => _fullEncounter = body);
          debugPrint('✅ Got full encounter');
        }
      } else {
        debugPrint('⚠️ Could not fetch full encounter: ${result.error}');
        // Non-fatal — the original map already has enough to display
      }
    } catch (e) {
      debugPrint('⚠️ Encounter fetch failed (using passed map): $e');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // Show Edit FAB only for local (non-FHIR) encounters
      floatingActionButton: !_isFhirMap
          ? FloatingActionButton.extended(
              onPressed: () async {
                final enc = _localEncounter ?? (widget.encounter as Encounter);
                final updated = await Navigator.push<Encounter>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditEncounterPage(encounter: enc),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() => _localEncounter = updated);
                }
              },
              backgroundColor: const Color(0xFF1B4332),
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              label: const Text('Edit',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_fetching) _buildFetchingBanner(),
                if (_fetchError != null && !_fetching)
                  _buildPartialDataBanner(),
                const SizedBox(height: 8),
                if (_isFhirMap)
                  _isFirestoreMap(
                          _fullEncounter ??
                              (widget.encounter as Map<String, dynamic>))
                      ? _buildFirestoreContent(widget.encounter
                          as Map<String, dynamic>)
                      : _buildFhirContent(_fullEncounter ??
                          (widget.encounter as Map<String, dynamic>))
                else
                  _buildLocalContent(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    String title = 'Encounter Details';
    String date = '';
    String clinician = '';
    String subtitle = '';

    if (_isFhirMap) {
      final enc =
          (_fullEncounter ?? widget.encounter) as Map<String, dynamic>;

      // BUG FIX: enc['type'] from Firestore is a plain String (e.g. "outpatient"),
      // not a FHIR List. Indexing a String with [0] returns a character code (int),
      // then ['text'] tries to use that int as a map key →
      // "type 'String' is not a subtype of type 'int' of 'index'" crash.
      //
      // Safe resolution order:
      //   1. FHIR class.display
      //   2. FHIR type[0].text  (only when type is actually a List)
      //   3. Firestore 'encounter_type' / 'type' plain string
      //   4. Fallback label
      String rawTitle;
      final typeField = enc['type'];
      if (enc['class'] is Map &&
          (enc['class'] as Map)['display'] != null) {
        rawTitle = enc['class']['display'].toString();
      } else if (typeField is List && typeField.isNotEmpty) {
        rawTitle = typeField[0]?['text']?.toString() ?? 'Clinical Encounter';
      } else if (typeField is String && typeField.isNotEmpty) {
        rawTitle = typeField;
      } else {
        rawTitle = enc['encounter_type']?.toString() ?? 'Clinical Encounter';
      }
      title = rawTitle.isNotEmpty
          ? rawTitle[0].toUpperCase() + rawTitle.substring(1).toLowerCase()
          : 'Clinical Encounter';

      // Date: try FHIR period.start first, then Firestore encounter_date
      final period = enc['period'] is Map ? enc['period'] as Map : null;
      final rawDate = period?['start'] ?? enc['encounter_date'];
      if (rawDate != null) {
        try {
          final dt = rawDate is String
              ? DateTime.parse(rawDate)
              : (rawDate as dynamic).toDate(); // Firestore Timestamp
          date = DateFormat('dd MMM yyyy, HH:mm').format(dt);
        } catch (_) {
          date = rawDate.toString();
        }
      }

      // Clinician: FHIR participant[0] or Firestore clinician_name
      final participants = enc['participant'];
      if (participants is List && participants.isNotEmpty) {
        clinician = participants[0]?['individual']?['display']?.toString() ?? '';
      }
      if (clinician.isEmpty) {
        clinician = enc['clinician_name']?.toString() ?? '';
      }

      // Subtitle: facility name
      final sourceName = enc['meta']?['sourceName']?.toString() ??
          enc['serviceProvider']?['display']?.toString() ??
          enc['facility_name']?.toString() ??
          '';
      subtitle = sourceName.isNotEmpty ? 'at $sourceName' : '';
    } else {
      final localEnc = widget.encounter as Encounter;
      final typeName = localEnc.type.name;
      title =
          '${typeName[0].toUpperCase()}${typeName.substring(1)} Encounter';
      date =
          DateFormat('dd MMM yyyy, HH:mm').format(localEnc.encounterDate);
      clinician = localEnc.clinicianName;
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: 170,
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (date.isNotEmpty)
                    Text(date,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  if (clinician.isNotEmpty)
                    Text('By $clinician',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Status banners ───────────────────────────────────────────────────────

  Widget _buildFetchingBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primary.withOpacity(0.15)),
        ),
        child: const Row(children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF1B4332)),
          ),
          SizedBox(width: 12),
          Text('Loading full encounter details...',
              style: TextStyle(fontSize: 13, color: Color(0xFF1B4332))),
        ]),
      );

  Widget _buildPartialDataBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline,
              color: Color(0xFFD97706), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Showing summary — full record could not be loaded.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _fetchError = null);
              _fetchFullEncounter();
            },
            child: const Text('Retry',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  // ── Firestore map detection ───────────────────────────────────────────────
  // Firestore encounter maps use snake_case keys (chief_complaint, patient_name,
  // encounter_date, etc.). FHIR maps use camelCase with 'resourceType' present.
  bool _isFirestoreMap(Map<String, dynamic> enc) =>
      enc.containsKey('chief_complaint') ||
      enc.containsKey('encounter_date') ||
      enc.containsKey('patient_nupi') ||
      !enc.containsKey('resourceType');

  // ── Firestore encounter content ───────────────────────────────────────────
  Widget _buildFirestoreContent(Map<String, dynamic> enc) {
    String _s(String key) => enc[key]?.toString() ?? '';
    String _orDash(String v) => v.trim().isEmpty ? '—' : v;

    // Parse vitals JSON if stored as a string
    Map<String, dynamic> vitals = {};
    final rawVitals = enc['vitals'];
    if (rawVitals is Map) {
      vitals = Map<String, dynamic>.from(rawVitals);
    } else if (rawVitals is String && rawVitals.isNotEmpty) {
      try {
        vitals = Map<String, dynamic>.from(
            (rawVitals as dynamic) == null ? {} : {}); // safe fallback
      } catch (_) {}
    }

    // Parse diagnoses list
    List<dynamic> diagnoses = [];
    final rawDx = enc['diagnoses'];
    if (rawDx is List) diagnoses = rawDx;

    Widget section(String title, IconData icon, List<Widget> rows) {
      if (rows.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: _primary),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      );
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Text(_orDash(value),
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patient & encounter info
        section('Encounter Info', Icons.info_outline, [
          row('Patient', _orDash(_s('patient_name'))),
          row('NUPI', _orDash(_s('patient_nupi'))),
          row('Type', _orDash(_s('encounter_type') == '' ? _s('type') : _s('encounter_type'))),
          row('Status', _orDash(_s('status'))),
          row('Facility', _orDash(_s('facility_name'))),
          row('Clinician', _orDash(_s('clinician_name'))),
          row('Disposition', _orDash(_s('disposition'))),
        ]),

        // Chief complaint & history
        if (_s('chief_complaint').isNotEmpty || _s('history').isNotEmpty)
          section('Presenting Complaint', Icons.chat_bubble_outline, [
            if (_s('chief_complaint').isNotEmpty)
              row('Chief Complaint', _s('chief_complaint')),
            if (_s('history').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('History',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(_s('history'),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF0F172A), height: 1.5)),
                  ],
                ),
              ),
          ]),

        // Vitals
        if (vitals.isNotEmpty)
          section('Vitals', Icons.monitor_heart_outlined, [
            if (vitals['temperature'] != null)
              row('Temperature', '${vitals['temperature']} °C'),
            if (vitals['pulse'] != null)
              row('Pulse', '${vitals['pulse']} bpm'),
            if (vitals['systolic'] != null && vitals['diastolic'] != null)
              row('Blood Pressure',
                  '${vitals['systolic']}/${vitals['diastolic']} mmHg'),
            if (vitals['oxygen_saturation'] != null)
              row('SpO₂', '${vitals['oxygen_saturation']}%'),
            if (vitals['respiratory_rate'] != null)
              row('Resp. Rate', '${vitals['respiratory_rate']} /min'),
            if (vitals['weight'] != null)
              row('Weight', '${vitals['weight']} kg'),
            if (vitals['height'] != null)
              row('Height', '${vitals['height']} cm'),
          ]),

        // Examination
        if (_s('examination').isNotEmpty)
          section('Examination Findings', Icons.search_outlined, [
            Text(_s('examination'),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF0F172A), height: 1.5)),
          ]),

        // Diagnoses
        if (diagnoses.isNotEmpty)
          section('Diagnoses', Icons.local_hospital_outlined,
              diagnoses.asMap().entries.map((e) {
            final d = e.value;
            final name = d is Map
                ? (d['name']?.toString() ??
                    d['description']?.toString() ??
                    d.toString())
                : d.toString();
            final isPrimary = d is Map && d['isPrimary'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPrimary ? Icons.star_rounded : Icons.circle,
                    size: isPrimary ? 14 : 8,
                    color: isPrimary ? _primary : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                            fontWeight: isPrimary
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ),
                ],
              ),
            );
          }).toList()),

        // Treatment plan & clinical notes
        if (_s('treatment_plan').isNotEmpty)
          section('Treatment Plan', Icons.medication_outlined, [
            Text(_s('treatment_plan'),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF0F172A), height: 1.5)),
          ]),
        if (_s('clinical_notes').isNotEmpty)
          section('Clinical Notes', Icons.notes_outlined, [
            Text(_s('clinical_notes'),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF0F172A), height: 1.5)),
          ]),
      ],
    );
  }

  // ── FHIR content ─────────────────────────────────────────────────────────

  Widget _buildFhirContent(Map<String, dynamic> enc) {
    final reasonCode     = enc['reasonCode']   as List? ?? [];
    final diagnosis      = enc['diagnosis']    as List? ?? [];
    final location       = enc['location']     as List? ?? [];
    final hospitalization = enc['hospitalization'] as Map?;
    final period         = enc['period']       as Map?;
    final participants   = enc['participant']  as List? ?? [];
    final serviceType    = enc['serviceType'];
    final contained      = enc['contained']    as List? ?? [];
    final notes          = enc['note']         as List? ?? [];

    // _clinicalData is a non-FHIR convenience field added by the backend
    // so the Flutter app doesn't have to parse FHIR extensions.
    final cd = enc['_clinicalData'] as Map<String, dynamic>?;

    // Extract vitals — either from _clinicalData or FHIR extensions
    Map<String, dynamic>? vitals;
    if (cd?['vitals'] is Map) {
      vitals = Map<String, dynamic>.from(cd!['vitals'] as Map);
    }

    // Extract diagnoses from _clinicalData (richer than FHIR diagnosis backbone)
    final cdDiagnoses = (cd?['diagnoses'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();

    final chiefComplaint = cd?['chiefComplaint'] as String?
        ?? (reasonCode.isNotEmpty ? reasonCode[0]['text']?.toString() : null);
    final history     = cd?['history']      as String?;
    final examination = cd?['examination']  as String?;
    final treatment   = cd?['treatmentPlan'] as String?;
    final clinNotes   = cd?['clinicalNotes'] as String?
        ?? (notes.isNotEmpty ? notes[0]['text']?.toString() : null);
    final disposition = cd?['disposition'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFacilityCard(enc),
        const SizedBox(height: 12),
        _buildDateCard(period),
        const SizedBox(height: 12),

        // ── Chief Complaint ─────────────────────────────────────
        if (chiefComplaint != null && chiefComplaint.isNotEmpty) ...[
          _infoCard('Chief Complaint', Icons.chat_bubble_outline,
              chiefComplaint),
          const SizedBox(height: 12),
        ],

        // ── Vitals ──────────────────────────────────────────────
        if (vitals != null && vitals.values.any((v) => v != null)) ...[
          _buildFhirVitalsCard(vitals),
          const SizedBox(height: 12),
        ],

        // ── History of Presenting Illness ───────────────────────
        if (history != null && history.isNotEmpty) ...[
          _infoCard('History of Presenting Illness',
              Icons.history_edu_outlined, history),
          const SizedBox(height: 12),
        ],

        // ── Examination Findings ────────────────────────────────
        if (examination != null && examination.isNotEmpty) ...[
          _infoCard('Examination Findings', Icons.search_outlined,
              examination),
          const SizedBox(height: 12),
        ],

        // ── Diagnoses ───────────────────────────────────────────
        if (cdDiagnoses.isNotEmpty) ...[
          _buildCdDiagnosesCard(cdDiagnoses),
          const SizedBox(height: 12),
        ] else if (diagnosis.isNotEmpty) ...[
          _buildFhirDiagnosesCard(diagnosis),
          const SizedBox(height: 12),
        ],

        // ── Treatment Plan ──────────────────────────────────────
        if (treatment != null && treatment.isNotEmpty) ...[
          _infoCard('Treatment Plan',
              Icons.medical_information_outlined, treatment),
          const SizedBox(height: 12),
        ],

        // ── Clinical Notes ──────────────────────────────────────
        if (clinNotes != null && clinNotes.isNotEmpty) ...[
          _infoCard('Clinical Notes', Icons.notes_outlined, clinNotes),
          const SizedBox(height: 12),
        ],

        // ── Disposition ─────────────────────────────────────────
        if (disposition != null && disposition.isNotEmpty) ...[
          _infoCard('Disposition', Icons.exit_to_app_outlined,
              disposition[0].toUpperCase() + disposition.substring(1)),
          const SizedBox(height: 12),
        ],

        // ── Clinician ───────────────────────────────────────────
        if (participants.isNotEmpty) ...[
          _buildParticipantsCard(participants),
          const SizedBox(height: 12),
        ],

        if (serviceType != null) ...[
          _infoCard(
            'Service Type', Icons.medical_services_outlined,
            serviceType['text']?.toString() ??
                serviceType['coding']?[0]?['display']?.toString() ?? '',
          ),
          const SizedBox(height: 12),
        ],

        if (hospitalization != null) ...[
          _buildHospitalizationCard(hospitalization),
          const SizedBox(height: 12),
        ],

        if (location.isNotEmpty) ...[
          _buildLocationCard(location),
          const SizedBox(height: 12),
        ],

        if (contained.isNotEmpty) ...[
          _buildContainedCard(contained),
          const SizedBox(height: 12),
        ],

        _buildMetaCard(enc),
      ],
    );
  }

  /// Vitals card for FHIR encounters (keys use camelCase from _clinicalData)
  Widget _buildFhirVitalsCard(Map<String, dynamic> v) {
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
      ]),
    );

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeader('Vital Signs', Icons.monitor_heart_outlined),
        const SizedBox(height: 12),
        if (v['temperature']      != null) row('Temperature',    '${v['temperature']} °C'),
        if (v['pulseRate']        != null) row('Pulse Rate',     '${v['pulseRate']} bpm'),
        if (v['systolicBP']       != null && v['diastolicBP'] != null)
          row('Blood Pressure', '${v['systolicBP']}/${v['diastolicBP']} mmHg'),
        if (v['oxygenSaturation'] != null) row('SpO₂',           '${v['oxygenSaturation']}%'),
        if (v['respiratoryRate']  != null) row('Resp. Rate',     '${v['respiratoryRate']} /min'),
        if (v['weight']           != null) row('Weight',         '${v['weight']} kg'),
        if (v['height']           != null) row('Height',         '${v['height']} cm'),
        if (v['bloodGlucose']     != null) row('Blood Glucose',  '${v['bloodGlucose']} mmol/L'),
        if (v['muac']             != null) row('MUAC',           '${v['muac']} cm'),
      ],
    ));
  }

  /// Diagnoses card built from _clinicalData.diagnoses list
  Widget _buildCdDiagnosesCard(List<Map<String, dynamic>> diagnoses) {
    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeader('Diagnoses', Icons.biotech_outlined),
        const SizedBox(height: 12),
        ...diagnoses.map((d) {
          final isPrimary = d['isPrimary'] == true;
          final code      = d['code'] as String? ?? '';
          final desc      = d['description'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 3, right: 10),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPrimary
                      ? const Color(0xFF1B4332)
                      : const Color(0xFF94A3B8),
                ),
              ),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (code.isNotEmpty)
                    Text(code,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A))),
                  if (isPrimary)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B4332).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Primary',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1B4332),
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              )),
            ]),
          );
        }),
      ],
    ));
  }

  Widget _cardHeader(String title, IconData icon) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFF2D6A4F)),
    const SizedBox(width: 8),
    Text(title,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B4332))),
  ]);

  // ── Local content ────────────────────────────────────────────────────────

  Widget _buildLocalContent() {
    final localEnc = (_localEncounter ?? widget.encounter) as Encounter;
    return Column(children: [
      if (localEnc.vitals != null) ...[
        _buildVitalsCard(localEnc.vitals!),
        const SizedBox(height: 12),
      ],
      if (localEnc.chiefComplaint != null) ...[
        _infoCard('Chief Complaint', Icons.chat_bubble_outline,
            localEnc.chiefComplaint!),
        const SizedBox(height: 12),
      ],
      if (localEnc.historyOfPresentingIllness != null) ...[
        _infoCard('History of Presenting Illness',
            Icons.history_edu_outlined,
            localEnc.historyOfPresentingIllness!),
        const SizedBox(height: 12),
      ],
      if (localEnc.examinationFindings != null) ...[
        _infoCard('Examination Findings', Icons.search_outlined,
            localEnc.examinationFindings!),
        const SizedBox(height: 12),
      ],
      if (localEnc.diagnoses.isNotEmpty) ...[
        _buildDiagnosesCard(localEnc.diagnoses),
        const SizedBox(height: 12),
      ],
      if (localEnc.treatmentPlan != null) ...[
        _infoCard('Treatment Plan', Icons.medical_information_outlined,
            localEnc.treatmentPlan!),
        const SizedBox(height: 12),
      ],
      if (localEnc.disposition != null)
        _buildDispositionCard(localEnc.disposition!),
    ]);
  }

  // ── Card widgets ─────────────────────────────────────────────────────────

  Widget _buildFacilityCard(Map<String, dynamic> enc) {
    final sourceName = enc['meta']?['sourceName']?.toString() ??
        enc['serviceProvider']?['display']?.toString() ??
        'Unknown Facility';
    final sourceId = enc['meta']?['source']?.toString() ??
        enc['serviceProvider']?['reference']
            ?.toString()
            .replaceFirst('Organization/', '') ??
        '';
    final status = enc['status']?.toString() ?? '';

    return _card(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2D6A4F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_hospital_rounded,
              color: Color(0xFF2D6A4F), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('FACILITY',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700)),
            Text(sourceName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
            if (sourceId.isNotEmpty)
              Text(sourceId,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B))),
          ]),
        ),
        if (status.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status)),
            ),
          ),
      ]),
    );
  }

  Widget _buildDateCard(Map? period) {
    final start = period?['start']?.toString();
    final end = period?['end']?.toString();

    String duration = '';
    if (start != null && end != null) {
      try {
        final s = DateTime.parse(start);
        final e = DateTime.parse(end);
        final diff = e.difference(s);
        if (diff.inDays > 0) {
          duration = '${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
        } else if (diff.inHours > 0) {
          duration = '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
        } else {
          duration = '${diff.inMinutes} min';
        }
      } catch (_) {}
    }

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DATE & TIME',
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _iconRow(Icons.calendar_today_rounded, _formatDate(start)),
        if (end != null) ...[
          const SizedBox(height: 6),
          _iconRow(Icons.access_time_rounded, 'Ended: ${_formatDate(end)}'),
        ],
        if (duration.isNotEmpty) ...[
          const SizedBox(height: 6),
          _iconRow(Icons.timelapse_rounded, 'Duration: $duration'),
        ],
      ]),
    );
  }

  Widget _buildParticipantsCard(List participants) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.person_outlined, size: 16, color: Color(0xFF2D6A4F)),
          SizedBox(width: 8),
          Text('CARE TEAM',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ...participants.map((p) {
          final name =
              p['individual']?['display']?.toString() ?? 'Unknown';
          final role = p['type']?[0]?['text']?.toString() ??
              p['type']?[0]?['coding']?[0]?['display']?.toString() ??
              '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    const Color(0xFF2D6A4F).withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D6A4F)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A))),
                if (role.isNotEmpty)
                  Text(role,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildFhirDiagnosesCard(List diagnoses) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.sick_outlined, size: 16, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text('DIAGNOSES',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        ...diagnoses.map((d) {
          final condition =
              d['condition']?['display']?.toString() ??
                  d['display']?.toString() ??
                  'Unknown';
          final isPrimary =
              d['use']?['coding']?[0]?['code'] == 'primary' ||
                  d['rank'] == 1;
          final code =
              d['condition']?['coding']?[0]?['code']?.toString() ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? const Color(0xFF6366F1)
                      : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(condition,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A))),
                  if (code.isNotEmpty)
                    Text(code,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                ]),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('PRIMARY',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildHospitalizationCard(Map hospitalization) {
    final admitSource =
        hospitalization['admitSource']?['text']?.toString() ??
            hospitalization['admitSource']?['coding']?[0]?['display']
                ?.toString() ??
            '';
    final dischargeDisp =
        hospitalization['dischargeDisposition']?['text']?.toString() ??
            hospitalization['dischargeDisposition']?['coding']?[0]
                    ?['display']?.toString() ??
            '';

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.hotel_rounded, size: 16, color: Color(0xFF0EA5E9)),
          SizedBox(width: 8),
          Text('HOSPITALIZATION',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        if (admitSource.isNotEmpty)
          _labeledRow('Admitted from', admitSource),
        if (dischargeDisp.isNotEmpty)
          _labeledRow('Discharge disposition', dischargeDisp),
      ]),
    );
  }

  Widget _buildLocationCard(List location) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.location_on_outlined,
              size: 16, color: Color(0xFF2D6A4F)),
          SizedBox(width: 8),
          Text('LOCATION',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ...location.map((l) {
          final name =
              l['location']?['display']?.toString() ?? 'Unknown';
          final status = l['status']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.room_outlined,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF0F172A))),
              ),
              if (status.isNotEmpty)
                Text(status,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildContainedCard(List contained) {
    // Extract any text notes from contained resources
    final notes = <String>[];
    for (final o in contained) {
      final text = o['text']?['div']?.toString() ??
          o['valueString']?.toString() ??
          o['note']?[0]?['text']?.toString() ??
          '';
      if (text.isNotEmpty) {
        // Strip HTML tags from div
        notes.add(text.replaceAll(RegExp(r'<[^>]*>'), '').trim());
      }
    }
    if (notes.isEmpty) return const SizedBox();

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.notes_rounded, size: 16, color: Color(0xFF2D6A4F)),
          SizedBox(width: 8),
          Text('CLINICAL NOTES',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ...notes.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(n,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.5)),
            )),
      ]),
    );
  }

  Widget _buildMetaCard(Map<String, dynamic> enc) {
    return _card(
      color: Colors.grey[50],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
          SizedBox(width: 8),
          Text('RECORD DETAILS',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        _labeledRow('Encounter ID', enc['id']?.toString() ?? 'N/A'),
        _labeledRow('Status', enc['status']?.toString() ?? 'Unknown'),
        if (enc['meta']?['lastUpdated'] != null)
          _labeledRow('Last Updated',
              _formatDate(enc['meta']['lastUpdated'].toString())),
      ]),
    );
  }

  // ── Vital thresholds ─────────────────────────────────────────────────────
  static const Map<String, Map<String, double>> _thresholds = {
    'Blood Pressure': {'low': 90,  'high': 140, 'criticalLow': 70,  'criticalHigh': 180},
    'Temperature':    {'low': 36.0,'high': 37.5,'criticalLow': 35.0,'criticalHigh': 39.5},
    'Pulse':          {'low': 60,  'high': 100, 'criticalLow': 40,  'criticalHigh': 130},
    'O\u2082 Sat':   {'low': 95,  'high': 100, 'criticalLow': 90,  'criticalHigh': 100},
    'Resp. Rate':     {'low': 12,  'high': 20,  'criticalLow': 8,   'criticalHigh': 30},
    'Glucose':        {'low': 3.9, 'high': 7.8, 'criticalLow': 2.8, 'criticalHigh': 13.9},
    'BMI':            {'low': 18.5,'high': 24.9,'criticalLow': 15.0,'criticalHigh': 40.0},
  };

  /// null=normal  low  high  critical_low  critical_high
  String? _vitalStatus(String label, double value) {
    final t = _thresholds[label];
    if (t == null) return null;
    if (t['criticalLow']  != null && value < t['criticalLow']!)  return 'critical_low';
    if (t['criticalHigh'] != null && value > t['criticalHigh']!) return 'critical_high';
    if (t['low']  != null && value < t['low']!)  return 'low';
    if (t['high'] != null && value > t['high']!) return 'high';
    return null;
  }

  Widget _vitalStatusBadge(String status) {
    final isCritical = status.startsWith('critical');
    final isLow      = status.contains('low');
    final label = isCritical
        ? (isLow ? '\u25bc CRITICAL' : '\u25b2 CRITICAL')
        : (isLow ? '\u25bc LOW' : '\u25b2 HIGH');
    final bg   = isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
    final fg   = isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(
          fontSize: 8, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.3)),
    );
  }

  Widget _buildVitalsCard(Vitals vitals) {
    // Each item: label, numericValue (for threshold check), displayValue, unit, icon, color
    final items = <Map<String, dynamic>>[];

    if (vitals.systolicBP != null && vitals.diastolicBP != null) {
      items.add({
        'label': 'Blood Pressure',
        'numValue': vitals.systolicBP!,   // threshold on systolic
        'display': vitals.bpDisplay!,
        'icon': Icons.favorite_outline,
        'color': const Color(0xFFE11D48),
      });
    }
    if (vitals.temperature != null) {
      items.add({
        'label': 'Temperature',
        'numValue': vitals.temperature!,
        'display': '${vitals.temperature!.toStringAsFixed(1)} \u00b0C',
        'icon': Icons.thermostat_outlined,
        'color': const Color(0xFFF59E0B),
      });
    }
    if (vitals.pulseRate != null) {
      items.add({
        'label': 'Pulse',
        'numValue': vitals.pulseRate!.toDouble(),
        'display': '${vitals.pulseRate} bpm',
        'icon': Icons.monitor_heart_outlined,
        'color': const Color(0xFF8B5CF6),
      });
    }
    if (vitals.oxygenSaturation != null) {
      items.add({
        'label': 'O\u2082 Sat',
        'numValue': vitals.oxygenSaturation!,
        'display': '${vitals.oxygenSaturation}%',
        'icon': Icons.air_outlined,
        'color': const Color(0xFF0EA5E9),
      });
    }
    if (vitals.respiratoryRate != null) {
      items.add({
        'label': 'Resp. Rate',
        'numValue': vitals.respiratoryRate!.toDouble(),
        'display': '${vitals.respiratoryRate} /min',
        'icon': Icons.wind_power_outlined,
        'color': const Color(0xFF06B6D4),
      });
    }
    if (vitals.weight != null) {
      items.add({
        'label': 'Weight',
        'numValue': null,   // no clinical threshold
        'display': '${vitals.weight} kg',
        'icon': Icons.monitor_weight_outlined,
        'color': const Color(0xFF2D6A4F),
      });
    }
    if (vitals.height != null) {
      items.add({
        'label': 'Height',
        'numValue': null,
        'display': '${vitals.height} cm',
        'icon': Icons.height_outlined,
        'color': const Color(0xFF2D6A4F),
      });
    }
    if (vitals.bmi != null) {
      items.add({
        'label': 'BMI',
        'numValue': vitals.bmi!,
        'display': vitals.bmi!.toStringAsFixed(1),
        'icon': Icons.accessibility_new_outlined,
        'color': const Color(0xFF6366F1),
      });
    }
    if (vitals.bloodGlucose != null) {
      items.add({
        'label': 'Glucose',
        'numValue': vitals.bloodGlucose!,
        'display': '${vitals.bloodGlucose!.toStringAsFixed(1)} mmol/L',
        'icon': Icons.water_drop_outlined,
        'color': const Color(0xFFF59E0B),
      });
    }

    if (items.isEmpty) return const SizedBox();

    // Check if ANY vital is abnormal for the header alert banner
    final anyAbnormal = items.any((item) {
      final num = item['numValue'] as double?;
      if (num == null) return false;
      return _vitalStatus(item['label'] as String, num) != null;
    });
    final anyCritical = items.any((item) {
      final num = item['numValue'] as double?;
      if (num == null) return false;
      final s = _vitalStatus(item['label'] as String, num);
      return s == 'critical_low' || s == 'critical_high';
    });

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Icon(Icons.monitor_heart_outlined,
              size: 18,
              color: anyCritical
                  ? const Color(0xFFDC2626)
                  : anyAbnormal
                      ? const Color(0xFFD97706)
                      : const Color(0xFFE11D48)),
          const SizedBox(width: 8),
          const Text('VITALS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          const Spacer(),
          if (anyCritical)
            _alertChip('CRITICAL VALUES', const Color(0xFFDC2626), const Color(0xFFFEE2E2))
          else if (anyAbnormal)
            _alertChip('ABNORMAL VALUES', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
        ]),
        const SizedBox(height: 16),

        // Grid of vital tiles
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item    = items[index];
            final numVal  = item['numValue'] as double?;
            final status  = numVal != null
                ? _vitalStatus(item['label'] as String, numVal)
                : null;
            final isCrit  = status == 'critical_low' || status == 'critical_high';
            final isAbnormal = status != null && !isCrit;

            final tileBg = isCrit
                ? const Color(0xFFFEF2F2)
                : isAbnormal
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF8FAFC);
            final borderColor = isCrit
                ? const Color(0xFFDC2626)
                : isAbnormal
                    ? const Color(0xFFD97706)
                    : const Color(0xFFE2E8F0);
            final baseColor = item['color'] as Color;
            final valueColor = isCrit
                ? const Color(0xFFDC2626)
                : isAbnormal
                    ? const Color(0xFFD97706)
                    : const Color(0xFF0F172A);
            final accentColor = isCrit
                ? const Color(0xFFDC2626)
                : isAbnormal
                    ? const Color(0xFFD97706)
                    : baseColor;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: borderColor,
                    width: (isCrit || isAbnormal) ? 1.5 : 1.0),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item['icon'] as IconData,
                      size: 14, color: accentColor),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(item['label'] as String,
                            style: TextStyle(fontSize: 9,
                                color: accentColor.withOpacity(0.8),
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (status != null) _vitalStatusBadge(status),
                    ]),
                    const SizedBox(height: 2),
                    Text(item['display'] as String,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: valueColor),
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _alertChip(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w900,
                color: fg, letterSpacing: 0.4)),
      );

  Widget _buildDiagnosesCard(List<Diagnosis> diagnoses) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.sick_outlined, size: 16, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text('DIAGNOSES',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        ...diagnoses.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: d.isPrimary
                        ? const Color(0xFF6366F1).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(d.code,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: d.isPrimary
                              ? const Color(0xFF6366F1)
                              : Colors.grey[600])),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(d.description,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A))),
                ),
                if (d.isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PRIMARY',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ),
              ]),
            )),
      ]),
    );
  }

  Widget _buildDispositionCard(Disposition disposition) {
    final color = disposition == Disposition.discharged
        ? const Color(0xFF2D6A4F)
        : disposition == Disposition.admitted
            ? const Color(0xFF6366F1)
            : disposition == Disposition.referred
                ? const Color(0xFFF59E0B)
                : disposition == Disposition.deceased
                    ? const Color(0xFFE11D48)
                    : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(Icons.exit_to_app_outlined, color: color),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DISPOSITION',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700)),
          Text(
            '${disposition.name[0].toUpperCase()}${disposition.name.substring(1)}',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
        ]),
      ]),
    );
  }

  // ── Primitive helpers ─────────────────────────────────────────────────────

  Widget _card({required Widget child, Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      );

  Widget _infoCard(String title, IconData icon, String content) => _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Icon(icon, size: 16, color: const Color(0xFF2D6A4F)),
            const SizedBox(width: 8),
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 10),
          Text(content,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF475569), height: 1.5)),
        ]),
      );

  Widget _iconRow(IconData icon, String text) => Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF2D6A4F)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF0F172A))),
        ),
      ]);

  Widget _labeledRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
          ),
        ]),
      );

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Not recorded';
    try {
      return DateFormat('dd MMM yyyy, HH:mm')
          .format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'finished':
      case 'completed':
        return Colors.green;
      case 'in-progress':
      case 'in progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'planned':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}