import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/encounter.dart';
import '../../../../core/services/hie_api_service.dart';

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

  @override
  void initState() {
    super.initState();
    if (_isFhirMap) {
      _fullEncounter = widget.encounter as Map<String, dynamic>;
      _fetchFullEncounter();
    }
  }

  Future<void> _fetchFullEncounter() async {
    final enc = widget.encounter as Map<String, dynamic>;
    final encounterId = enc['id']?.toString();
    final accessToken = widget.accessToken;
    final facilityId = enc['meta']?['source']?.toString();

    if (encounterId == null || encounterId.isEmpty) return;
    if (accessToken == null || accessToken.isEmpty) return;

    setState(() {
      _fetching = true;
      _fetchError = null;
    });

    try {
      debugPrint('📋 Fetching full encounter: $encounterId from $facilityId');

      final result = await HieApiService.instance.getFhirEncounter(
        encounterId: encounterId,
        accessToken: accessToken,
        facilityId: facilityId,
      );

      if (!mounted) return;

      if (result.success && result.data != null) {
        final body = result.data!;
        // Unwrap if it came back wrapped in a Bundle
        if (body['resourceType'] == 'Bundle') {
          final entries = body['entry'] as List? ?? [];
          if (entries.isNotEmpty) {
            final resource =
                entries.first['resource'] as Map<String, dynamic>?;
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
        setState(() => _fetchError = result.error);
      }
    } catch (e) {
      debugPrint('❌ Error fetching full encounter: $e');
      if (mounted) setState(() => _fetchError = e.toString());
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
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
                  _buildFhirContent(
                      _fullEncounter ??
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
      final rawTitle = enc['class']?['display']?.toString() ??
          enc['type']?[0]?['text']?.toString() ??
          'Clinical Encounter';
      title = rawTitle[0].toUpperCase() +
          rawTitle.substring(1).toLowerCase();

      final period = enc['period'] as Map?;
      if (period?['start'] != null) {
        try {
          date = DateFormat('dd MMM yyyy, HH:mm')
              .format(DateTime.parse(period!['start'].toString()));
        } catch (_) {
          date = period!['start']?.toString() ?? '';
        }
      }

      clinician = enc['participant']?[0]?['individual']?['display']
              ?.toString() ??
          '';
      final sourceName = enc['meta']?['sourceName']?.toString() ??
          enc['serviceProvider']?['display']?.toString() ??
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

  // ── FHIR content ─────────────────────────────────────────────────────────

  Widget _buildFhirContent(Map<String, dynamic> enc) {
    final reasonCode = enc['reasonCode'] as List? ?? [];
    final diagnosis = enc['diagnosis'] as List? ?? [];
    final location = enc['location'] as List? ?? [];
    final hospitalization = enc['hospitalization'] as Map?;
    final period = enc['period'] as Map?;
    final participants = enc['participant'] as List? ?? [];
    final serviceType = enc['serviceType'];
    final priority = enc['priority'];
    final contained = enc['contained'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFacilityCard(enc),
        const SizedBox(height: 12),
        _buildDateCard(period),
        const SizedBox(height: 12),

        if (reasonCode.isNotEmpty) ...[
          _infoCard(
            'Chief Complaint',
            Icons.chat_bubble_outline,
            reasonCode
                .map((r) => r['text']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .join('\n'),
          ),
          const SizedBox(height: 12),
        ],

        if (participants.isNotEmpty) ...[
          _buildParticipantsCard(participants),
          const SizedBox(height: 12),
        ],

        if (serviceType != null) ...[
          _infoCard(
            'Service Type',
            Icons.medical_services_outlined,
            serviceType['text']?.toString() ??
                serviceType['coding']?[0]?['display']?.toString() ??
                '',
          ),
          const SizedBox(height: 12),
        ],

        if (priority != null) ...[
          _infoCard(
            'Priority',
            Icons.flag_outlined,
            priority['text']?.toString() ??
                priority['coding']?[0]?['display']?.toString() ??
                '',
          ),
          const SizedBox(height: 12),
        ],

        if (diagnosis.isNotEmpty) ...[
          _buildFhirDiagnosesCard(diagnosis),
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

  // ── Local content ────────────────────────────────────────────────────────

  Widget _buildLocalContent() {
    final localEnc = widget.encounter as Encounter;
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

  // ── Vitals card — FIXED: FittedBox + mainAxisSize.min prevents overflow ──

  Widget _buildVitalsCard(Vitals vitals) {
    final vitalItems = <Map<String, String>>[];
    if (vitals.bpDisplay != null) {
      vitalItems.add({
        'label': 'Blood Pressure',
        'value': vitals.bpDisplay!,
        'unit': '',
      });
    }
    if (vitals.temperature != null) {
      vitalItems.add({
        'label': 'Temperature',
        'value': vitals.temperature!.toStringAsFixed(1),
        'unit': '°C',
      });
    }
    if (vitals.pulseRate != null) {
      vitalItems.add({
        'label': 'Pulse',
        'value': vitals.pulseRate!.toString(),
        'unit': 'bpm',
      });
    }
    if (vitals.oxygenSaturation != null) {
      vitalItems.add({
        'label': 'O₂ Sat',
        'value': vitals.oxygenSaturation!.toString(),
        'unit': '%',
      });
    }
    if (vitals.weight != null) {
      vitalItems.add({
        'label': 'Weight',
        'value': vitals.weight!.toString(),
        'unit': 'kg',
      });
    }
    if (vitals.height != null) {
      vitalItems.add({
        'label': 'Height',
        'value': vitals.height!.toString(),
        'unit': 'cm',
      });
    }
    if (vitals.bmi != null) {
      vitalItems.add({
        'label': 'BMI',
        'value': vitals.bmi!.toStringAsFixed(1),
        'unit': '',
      });
    }
    if (vitals.bloodGlucose != null) {
      vitalItems.add({
        'label': 'Glucose',
        'value': vitals.bloodGlucose!.toStringAsFixed(1),
        'unit': 'mmol/L',
      });
    }
    if (vitalItems.isEmpty) return const SizedBox();

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.monitor_heart_outlined,
              size: 18, color: Color(0xFFE11D48)),
          SizedBox(width: 8),
          Text('VITALS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            // Slightly taller cells so value + label never clip
            childAspectRatio: 1.05,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: vitalItems.length,
          itemBuilder: (context, index) {
            final item = vitalItems[index];
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                // ✅ min prevents Column from demanding more height than it needs
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ FittedBox scales down value text on narrow screens
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${item['value']} ${item['unit']}'.trim(),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['label']!,
                    style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ]),
    );
  }

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