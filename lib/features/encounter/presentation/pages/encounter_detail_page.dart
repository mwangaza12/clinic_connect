import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/encounter.dart';

class EncounterDetailPage extends StatelessWidget {
  final Encounter encounter;

  const EncounterDetailPage({super.key, required this.encounter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
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
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm')
                              .format(encounter.encounterDate),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${encounter.type.name[0].toUpperCase()}${encounter.type.name.substring(1)} Encounter',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'By ${encounter.clinicianName}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Vitals
                if (encounter.vitals != null) ...[
                  _buildVitalsCard(encounter.vitals!),
                  const SizedBox(height: 16),
                ],

                // Chief Complaint
                if (encounter.chiefComplaint != null)
                  _infoCard('Chief Complaint',
                      Icons.chat_bubble_outline, encounter.chiefComplaint!),

                // History
                if (encounter.historyOfPresentingIllness != null) ...[
                  const SizedBox(height: 12),
                  _infoCard('History of Presenting Illness',
                      Icons.history_edu_outlined,
                      encounter.historyOfPresentingIllness!),
                ],

                // Examination
                if (encounter.examinationFindings != null) ...[
                  const SizedBox(height: 12),
                  _infoCard('Examination Findings',
                      Icons.search_outlined,
                      encounter.examinationFindings!),
                ],

                // Diagnoses
                if (encounter.diagnoses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDiagnosesCard(encounter.diagnoses),
                ],

                // Treatment
                if (encounter.treatmentPlan != null) ...[
                  const SizedBox(height: 12),
                  _infoCard('Treatment Plan',
                      Icons.medical_information_outlined,
                      encounter.treatmentPlan!),
                ],

                // Disposition
                if (encounter.disposition != null) ...[
                  const SizedBox(height: 12),
                  _buildDispositionCard(encounter.disposition!),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard(Vitals vitals) {
    final vitalItems = <Map<String, String>>[];

    if (vitals.bpDisplay != null)
      vitalItems.add({'label': 'Blood Pressure', 'value': vitals.bpDisplay!, 'unit': ''});
    if (vitals.temperature != null)
      vitalItems.add({'label': 'Temperature', 'value': '${vitals.temperature}', 'unit': '°C'});
    if (vitals.pulseRate != null)
      vitalItems.add({'label': 'Pulse', 'value': '${vitals.pulseRate}', 'unit': 'bpm'});
    if (vitals.oxygenSaturation != null)
      vitalItems.add({'label': 'O₂ Sat', 'value': '${vitals.oxygenSaturation}', 'unit': '%'});
    if (vitals.weight != null)
      vitalItems.add({'label': 'Weight', 'value': '${vitals.weight}', 'unit': 'kg'});
    if (vitals.height != null)
      vitalItems.add({'label': 'Height', 'value': '${vitals.height}', 'unit': 'cm'});
    if (vitals.bmi != null)
      vitalItems.add({'label': 'BMI', 'value': vitals.bmi!.toStringAsFixed(1), 'unit': ''});
    if (vitals.bloodGlucose != null)
      vitalItems.add({'label': 'Glucose', 'value': '${vitals.bloodGlucose}', 'unit': 'mmol/L'});

    if (vitalItems.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_outlined,
                  size: 18, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text(
                'VITALS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
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
                      '${item['value']} ${item['unit']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label']!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2D6A4F)),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sick_outlined,
                  size: 16, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text(
                'DIAGNOSES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...diagnoses.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: d.isPrimary
                            ? const Color(0xFF6366F1).withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: d.isPrimary
                              ? const Color(0xFF6366F1)
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (d.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              )),
        ],
      ),
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
      child: Row(
        children: [
          Icon(Icons.exit_to_app_outlined, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DISPOSITION',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${disposition.name[0].toUpperCase()}${disposition.name.substring(1)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}