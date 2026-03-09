import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/encounter.dart';

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

class EncounterDetailPage extends StatelessWidget {
  final dynamic encounter; // Either Encounter entity or FHIR Map
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

  /// True when the encounter is a raw FHIR map (from HIE or verification data).
  /// Uses runtime type check — never relies on the isFederated flag alone.
  bool get _isFhirMap => encounter is Map<String, dynamic>;

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
                if (_isFhirMap)
                  _buildFederatedContent()
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

  Widget _buildSliverAppBar() {
    String title = 'Encounter Details';
    String date = '';
    String clinician = '';
    String subtitle = '';

    if (_isFhirMap) {
      final enc = encounter as Map<String, dynamic>;
      title = enc['class']?['display']?.toString() ??
          enc['type']?[0]?['text']?.toString() ??
          'Clinical Encounter';

      final period = enc['period'] as Map?;
      if (period?['start'] != null) {
        try {
          date = DateFormat('dd MMM yyyy, HH:mm')
              .format(DateTime.parse(period!['start']));
        } catch (_) {
          date = period!['start']?.toString() ?? '';
        }
      }

      clinician = enc['participant']?[0]?['individual']?['display']
              ?.toString() ??
          '';
      subtitle =
          'at ${enc['meta']?['sourceName']?.toString() ?? 'Unknown Facility'}';
    } else {
      final localEnc = encounter as Encounter;
      final typeName = localEnc.type.name;
      title =
          '${typeName[0].toUpperCase()}${typeName.substring(1)} Encounter';
      date = DateFormat('dd MMM yyyy, HH:mm').format(localEnc.encounterDate);
      clinician = localEnc.clinicianName;
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: const Color(0xFF1B4332),
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

  Widget _buildLocalContent() {
    final localEnc = encounter as Encounter;

    return Column(
      children: [
        if (localEnc.vitals != null) ...[
          _buildVitalsCard(localEnc.vitals!),
          const SizedBox(height: 16),
        ],
        if (localEnc.chiefComplaint != null)
          _infoCard('Chief Complaint', Icons.chat_bubble_outline,
              localEnc.chiefComplaint!),
        if (localEnc.historyOfPresentingIllness != null) ...[
          const SizedBox(height: 12),
          _infoCard('History of Presenting Illness',
              Icons.history_edu_outlined,
              localEnc.historyOfPresentingIllness!),
        ],
        if (localEnc.examinationFindings != null) ...[
          const SizedBox(height: 12),
          _infoCard('Examination Findings', Icons.search_outlined,
              localEnc.examinationFindings!),
        ],
        if (localEnc.diagnoses.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDiagnosesCard(localEnc.diagnoses),
        ],
        if (localEnc.treatmentPlan != null) ...[
          const SizedBox(height: 12),
          _infoCard('Treatment Plan', Icons.medical_information_outlined,
              localEnc.treatmentPlan!),
        ],
        if (localEnc.disposition != null) ...[
          const SizedBox(height: 12),
          _buildDispositionCard(localEnc.disposition!),
        ],
      ],
    );
  }

  Widget _buildFederatedContent() {
    final enc = encounter as Map<String, dynamic>;

    final reasonCode = enc['reasonCode'] as List? ?? [];
    final diagnosis = enc['diagnosis'] as List? ?? [];
    final location = enc['location'] as List? ?? [];
    final hospitalization = enc['hospitalization'] as Map?;
    final period = enc['period'] as Map?;

    return Column(
      children: [
        // Facility card
        _buildFacilityCard(enc),
        const SizedBox(height: 16),

        // Date & time
        _buildDateCard(period),
        const SizedBox(height: 16),

        // Chief complaint
        if (reasonCode.isNotEmpty) ...[
          _infoCard(
            'Chief Complaint',
            Icons.chat_bubble_outline,
            reasonCode[0]['text']?.toString() ?? 'Not recorded',
          ),
          const SizedBox(height: 16),
        ],

        // Diagnoses
        if (diagnosis.isNotEmpty) ...[
          _buildFhirDiagnosesCard(diagnosis),
          const SizedBox(height: 16),
        ],

        // Hospitalization
        if (hospitalization != null) ...[
          _infoCard(
            'Hospitalization',
            Icons.local_hospital_outlined,
            'Admit: ${hospitalization['admitSource']?['text'] ?? 'Unknown'}\n'
                'Discharge: ${hospitalization['dischargeDisposition']?['text'] ?? 'Pending'}',
          ),
          const SizedBox(height: 16),
        ],

        // Location
        if (location.isNotEmpty) ...[
          _infoCard(
            'Location',
            Icons.location_on_outlined,
            location[0]['location']?['display']?.toString() ?? 'Unknown',
          ),
          const SizedBox(height: 16),
        ],

        // Record meta
        _buildMetaCard(enc),
      ],
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> enc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FACILITY',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700)),
            Text(
              enc['meta']?['sourceName']?.toString() ?? 'Unknown',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A)),
            ),
            if ((enc['meta']?['source']?.toString() ?? '').isNotEmpty)
              Text(
                enc['meta']['source'].toString(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
          ]),
        ),
        if (isFederated)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Remote',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple)),
          ),
      ]),
    );
  }

  Widget _buildDateCard(Map? period) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DATE & TIME',
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 16, color: Color(0xFF2D6A4F)),
          const SizedBox(width: 8),
          Text(
            _formatDate(period?['start']?.toString()),
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          ),
        ]),
        if (period?['end'] != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time_rounded,
                size: 16, color: Color(0xFF2D6A4F)),
            const SizedBox(width: 8),
            Text(
              'Until: ${_formatDate(period!['end']?.toString())}',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF475569)),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildMetaCard(Map<String, dynamic> enc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
        Text('Encounter ID: ${enc['id'] ?? 'N/A'}',
            style:
                const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(
          'Status: ${enc['status'] ?? 'Unknown'}',
          style: TextStyle(
              fontSize: 11,
              color: _getStatusColor(enc['status']?.toString() ?? '')),
        ),
      ]),
    );
  }

  Widget _buildVitalsCard(Vitals vitals) {
    final vitalItems = <Map<String, String>>[];

    if (vitals.bpDisplay != null) {
      vitalItems
          .add({'label': 'Blood Pressure', 'value': vitals.bpDisplay!, 'unit': ''});
    }
    if (vitals.temperature != null) {
      vitalItems.add({
        'label': 'Temperature',
        'value': vitals.temperature!.toStringAsFixed(1),
        'unit': '°C'
      });
    }
    if (vitals.pulseRate != null) {
      vitalItems.add({
        'label': 'Pulse',
        'value': vitals.pulseRate!.toString(),
        'unit': 'bpm'
      });
    }
    if (vitals.oxygenSaturation != null) {
      vitalItems.add({
        'label': 'O₂ Sat',
        'value': vitals.oxygenSaturation!.toString(),
        'unit': '%'
      });
    }
    if (vitals.weight != null) {
      vitalItems.add({
        'label': 'Weight',
        'value': vitals.weight!.toString(),
        'unit': 'kg'
      });
    }
    if (vitals.height != null) {
      vitalItems.add({
        'label': 'Height',
        'value': vitals.height!.toString(),
        'unit': 'cm'
      });
    }
    if (vitals.bmi != null) {
      vitalItems.add({
        'label': 'BMI',
        'value': vitals.bmi!.toStringAsFixed(1),
        'unit': ''
      });
    }
    if (vitals.bloodGlucose != null) {
      vitalItems.add({
        'label': 'Glucose',
        'value': vitals.bloodGlucose!.toStringAsFixed(1),
        'unit': 'mmol/L'
      });
    }

    if (vitalItems.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
            childAspectRatio: 1.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: vitalItems.length,
          itemBuilder: (context, index) {
            final item = vitalItems[index];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item['value']} ${item['unit']}'.trim(),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label']!,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _infoCard(String title, IconData icon, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF2D6A4F)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5),
          ),
        ]),
        const SizedBox(height: 10),
        Text(content,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF475569), height: 1.5)),
      ]),
    );
  }

  Widget _buildDiagnosesCard(List<Diagnosis> diagnoses) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.sick_outlined, size: 16, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text('DIAGNOSES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
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

  Widget _buildFhirDiagnosesCard(List diagnoses) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.sick_outlined, size: 16, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text('DIAGNOSES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        ...diagnoses.map((d) {
          final condition = d['condition']?['display']?.toString() ??
              d['display']?.toString() ??
              'Unknown';
          final isPrimary =
              d['use']?['coding']?[0]?['code'] == 'primary';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? const Color(0xFF6366F1)
                      : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(condition,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A))),
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Not recorded';
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(dateStr));
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