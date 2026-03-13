// lib/features/disease_program/presentation/pages/enrollment_detail_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/disease_program.dart';

class EnrollmentDetailPage extends StatelessWidget {
  final ProgramEnrollment enrollment;

  const EnrollmentDetailPage({super.key, required this.enrollment});

  // ── colour palette – matches rest of the app ──────────────────────────
  static const _bg       = Color(0xFFF8FAFC);
  static const _surface  = Colors.white;
  static const _textDark = Color(0xFF0F172A);
  static const _textMid  = Color(0xFF475569);
  static const _textSoft = Color(0xFF94A3B8);
  static const _border   = Color(0xFFE2E8F0);

  static const Map<DiseaseProgram, Color> _programColors = {
    DiseaseProgram.hivArt:       Color(0xFFEF4444),
    DiseaseProgram.ncdDiabetes:  Color(0xFF3B82F6),
    DiseaseProgram.hypertension: Color(0xFFF97316),
    DiseaseProgram.malaria:      Color(0xFF22C55E),
    DiseaseProgram.tb:           Color(0xFFA855F7),
    DiseaseProgram.mch:          Color(0xFFEC4899),
  };

  static const Map<DiseaseProgram, IconData> _programIcons = {
    DiseaseProgram.hivArt:       Icons.coronavirus_outlined,
    DiseaseProgram.ncdDiabetes:  Icons.water_drop_outlined,
    DiseaseProgram.hypertension: Icons.favorite_outline,
    DiseaseProgram.malaria:      Icons.bug_report_outlined,
    DiseaseProgram.tb:           Icons.air_outlined,
    DiseaseProgram.mch:          Icons.child_care_outlined,
  };

  Color get _color => _programColors[enrollment.program]!;
  IconData get _icon => _programIcons[enrollment.program]!;

  // ── helpers ───────────────────────────────────────────────────────────
  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

  String _str(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    if (v is List) return v.isEmpty ? '—' : v.join(', ');
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  // ── build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildHeroHeader(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _enrollmentSummaryCard(),
                const SizedBox(height: 16),
                _programSpecificCard(),
                const SizedBox(height: 16),
                if (enrollment.outcomeNotes != null &&
                    enrollment.outcomeNotes!.isNotEmpty)
                  _notesCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── hero header ───────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _color,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 20, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_color, _color.withOpacity(0.75)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enrollment.program.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              enrollment.patientName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusPill(enrollment.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(ProgramEnrollmentStatus status) {
    const labels = {
      ProgramEnrollmentStatus.active:      'ACTIVE',
      ProgramEnrollmentStatus.completed:   'COMPLETED',
      ProgramEnrollmentStatus.defaulted:   'DEFAULTED',
      ProgramEnrollmentStatus.transferred: 'TRANSFERRED',
      ProgramEnrollmentStatus.died:        'DECEASED',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Text(
        labels[status] ?? status.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── enrollment summary card ───────────────────────────────────────────
  Widget _enrollmentSummaryCard() {
    return _card(
      title: 'Enrollment Summary',
      icon: Icons.assignment_outlined,
      children: [
        _row(Icons.badge_outlined,        'NUPI',             enrollment.patientNupi),
        _row(Icons.local_hospital_outlined,'Facility',        enrollment.facilityId),
        _row(Icons.calendar_today_outlined,'Enrolled',        _fmt(enrollment.enrollmentDate)),
        if (enrollment.completionDate != null)
          _row(Icons.event_available_outlined, 'Completed',   _fmt(enrollment.completionDate)),
        _row(Icons.sync_outlined,          'Sync status',
            enrollment.programSpecificData != null ? 'Saved' : 'Pending'),
      ],
    );
  }

  // ── program-specific card ─────────────────────────────────────────────
  Widget _programSpecificCard() {
    final data = enrollment.programSpecificData ?? {};

    final Widget content;
    switch (enrollment.program) {
      case DiseaseProgram.hivArt:
        content = _hivSection(data);
        break;
      case DiseaseProgram.ncdDiabetes:
        content = _diabetesSection(data);
        break;
      case DiseaseProgram.hypertension:
        content = _hypertensionSection(data);
        break;
      case DiseaseProgram.malaria:
        content = _malariaSection(data);
        break;
      case DiseaseProgram.tb:
        content = _tbSection(data);
        break;
      case DiseaseProgram.mch:
        content = _mchSection(data);
        break;
    }

    return _card(
      title: 'Clinical Details',
      icon: Icons.medical_information_outlined,
      children: [content],
    );
  }

  // ── HIV/ART section ───────────────────────────────────────────────────
  Widget _hivSection(Map<String, dynamic> d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subheading('Diagnosis'),
        _row(Icons.today_outlined,        'HIV Diagnosis Date',  _str(d['hivDiagnosisDate'])),
        _row(Icons.stairs_outlined,       'WHO Clinical Stage',  _str(d['whoStage'])),
        const SizedBox(height: 12),
        _subheading('CD4 & Viral Load'),
        _row(Icons.biotech_outlined,      'Baseline CD4',        _str(d['baselineCd4Count']) == '—' ? '—' : '${_str(d['baselineCd4Count'])} cells/μL'),
        _row(Icons.biotech_outlined,      'Current CD4',         _str(d['currentCd4Count']) == '—' ? '—' : '${_str(d['currentCd4Count'])} cells/μL'),
        _row(Icons.analytics_outlined,    'Viral Load Status',   _str(d['viralLoadStatus'])),
        _row(Icons.numbers_outlined,      'Last Viral Load',     _str(d['lastViralLoad']) == '—' ? '—' : '${_str(d['lastViralLoad'])} copies/mL'),
        _row(Icons.event_outlined,        'VL Date',             _str(d['lastViralLoadDate'])),
        const SizedBox(height: 12),
        _subheading('Treatment'),
        _row(Icons.medication_outlined,   'ARV Regimen',         _str(d['arvRegimen'])),
        _row(Icons.calendar_month_outlined,'ARV Start Date',     _str(d['arvStartDate'])),
        _row(Icons.event_available_outlined,'Next Appointment',  _str(d['nextAppointmentDate'])),
        const SizedBox(height: 12),
        _subheading('Prophylaxis'),
        _boolRow('TB Prophylaxis (INH)',        d['onTbProphylaxis']),
        _boolRow('Cotrimoxazole Prophylaxis',   d['onCotrimoxazole']),
      ],
    );
  }

  // ── Diabetes section ──────────────────────────────────────────────────
  Widget _diabetesSection(Map<String, dynamic> d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subheading('Diagnosis'),
        _row(Icons.category_outlined,     'Diabetes Type',       _str(d['diabetesType'])),
        _row(Icons.today_outlined,        'Diagnosis Date',      _str(d['diagnosisDate'])),
        const SizedBox(height: 12),
        _subheading('Glycaemic Control'),
        _row(Icons.percent_outlined,      'HbA1c',               _str(d['hba1c']) == '—' ? '—' : '${_str(d['hba1c'])}%'),
        _row(Icons.water_drop_outlined,   'Fasting Blood Sugar',  _str(d['fastingBloodSugar']) == '—' ? '—' : '${_str(d['fastingBloodSugar'])} mg/dL'),
        _row(Icons.water_drop_outlined,   'Random Blood Sugar',   _str(d['randomBloodSugar']) == '—' ? '—' : '${_str(d['randomBloodSugar'])} mg/dL'),
        const SizedBox(height: 12),
        _subheading('Treatment'),
        _row(Icons.medication_outlined,   'Medication',          _str(d['medication'])),
        _boolRow('On Insulin',                                    d['onInsulin']),
        if (_str(d['insulinRegimen']) != '—')
          _row(Icons.vaccines_outlined,   'Insulin Regimen',     _str(d['insulinRegimen'])),
        _row(Icons.warning_amber_outlined,'Complications',        _str(d['complications'])),
        const SizedBox(height: 12),
        _subheading('Follow-up'),
        _row(Icons.visibility_outlined,   'Last Eye Exam',        _str(d['lastEyeExam'])),
        _row(Icons.directions_walk_outlined,'Last Foot Exam',     _str(d['lastFootExam'])),
        _row(Icons.event_available_outlined,'Next Appointment',   _str(d['nextAppointmentDate'])),
      ],
    );
  }

  // ── Hypertension section ──────────────────────────────────────────────
  Widget _hypertensionSection(Map<String, dynamic> d) {
    final sys = _str(d['systolic']);
    final dia = _str(d['diastolic']);
    final bp  = (sys == '—' && dia == '—') ? '—' : '$sys / $dia mmHg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subheading('Diagnosis'),
        _row(Icons.today_outlined,        'Diagnosis Date',      _str(d['diagnosisDate'])),
        _row(Icons.stairs_outlined,       'Stage',               _str(d['stage'])),
        _row(Icons.category_outlined,     'Risk Category',       _str(d['riskCategory'])),
        const SizedBox(height: 12),
        _subheading('Measurements'),
        _row(Icons.favorite_outline,      'Blood Pressure',      bp),
        _row(Icons.monitor_heart_outlined,'Heart Rate',          _str(d['heartRate']) == '—' ? '—' : '${_str(d['heartRate'])} bpm'),
        const SizedBox(height: 12),
        _subheading('Treatment'),
        _row(Icons.medication_outlined,   'Medication',          _str(d['medication'])),
        _row(Icons.checklist_outlined,    'Adherence',           _str(d['medicationAdherence'])),
        _row(Icons.warning_amber_outlined,'Risk Factors',        _str(d['riskFactors'])),
        _boolRow('Has Complications',                            d['hasComplications']),
        if (_str(d['complications']) != '—')
          _row(Icons.info_outline,        'Complications',       _str(d['complications'])),
        const SizedBox(height: 12),
        _subheading('Investigations'),
        _row(Icons.monitor_heart_outlined,'Last ECG',            _str(d['lastEcg'])),
        _row(Icons.eco_outlined,         'Last Echo',           _str(d['lastEcho'])),
        _row(Icons.event_available_outlined,'Next Appointment',  _str(d['nextAppointmentDate'])),
      ],
    );
  }

  // ── Malaria section ───────────────────────────────────────────────────
  Widget _malariaSection(Map<String, dynamic> d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subheading('Diagnosis'),
        _row(Icons.today_outlined,        'Diagnosis Date',      _str(d['diagnosisDate'])),
        _row(Icons.bug_report_outlined,   'Malaria Type',        _str(d['malariaType'])),
        _row(Icons.warning_amber_outlined,'Severity',            _str(d['severity'])),
        _row(Icons.biotech_outlined,      'Diagnosis Method',    _str(d['diagnosisMethod'])),
        const SizedBox(height: 12),
        _subheading('Clinical Findings'),
        _row(Icons.thermostat_outlined,   'Temperature',         _str(d['temperature']) == '—' ? '—' : '${_str(d['temperature'])} °C'),
        _row(Icons.numbers_outlined,      'Parasite Count',      _str(d['parasiteCount']) == '—' ? '—' : '${_str(d['parasiteCount'])} /μL'),
        const SizedBox(height: 12),
        _subheading('Treatment'),
        _boolRow('Received Treatment',                           d['receivedTreatment']),
        _row(Icons.medication_outlined,   'Treatment',           _str(d['treatment'])),
        _row(Icons.pending_actions_outlined,'Treatment Outcome', _str(d['treatmentOutcome'])),
        _row(Icons.event_outlined,        'Follow-up Date',      _str(d['followUpDate'])),
      ],
    );
  }

  // ── TB section ────────────────────────────────────────────────────────
  Widget _tbSection(Map<String, dynamic> d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subheading('Diagnosis'),
        _row(Icons.today_outlined,        'Diagnosis Date',      _str(d['diagnosisDate'])),
        _row(Icons.category_outlined,     'TB Type',             _str(d['tbType'])),
        _row(Icons.location_on_outlined,  'Disease Site',        _str(d['diseaseSite'])),
        const SizedBox(height: 12),
        _subheading('Treatment'),
        _row(Icons.play_arrow_outlined,   'Treatment Start',     _str(d['treatmentStartDate'])),
        _row(Icons.medication_outlined,   'Regimen',             _str(d['treatmentRegimen'])),
        _row(Icons.stairs_outlined,       'Treatment Phase',     _str(d['treatmentPhase'])),
        _row(Icons.monitor_weight_outlined,'Weight',             _str(d['weight']) == '—' ? '—' : '${_str(d['weight'])} kg'),
        _row(Icons.pending_actions_outlined,'Outcome',           _str(d['treatmentOutcome'])),
        const SizedBox(height: 12),
        _subheading('HIV Co-infection'),
        _row(Icons.coronavirus_outlined,  'HIV Status',          _str(d['hivStatus'])),
        _boolRow('On ART',                                       d['onArt']),
        const SizedBox(height: 12),
        _subheading('Follow-up'),
        _row(Icons.person_outline,        'DOT Provider',        _str(d['dotProvider'])),
        _row(Icons.science_outlined,      'Last Sputum Test',    _str(d['lastSputumTest'])),
        _row(Icons.event_available_outlined,'Next Appointment',  _str(d['nextAppointmentDate'])),
      ],
    );
  }

  // ── MCH section ───────────────────────────────────────────────────────
  Widget _mchSection(Map<String, dynamic> d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subheading('Service'),
        _row(Icons.category_outlined,     'Service Type',        _str(d['serviceType'])),
        const SizedBox(height: 12),
        _subheading('Obstetric History'),
        _row(Icons.event_outlined,        'Expected Delivery',   _str(d['edd'])),
        _row(Icons.pregnant_woman_outlined,'Gravidity',          _str(d['gravidity'])),
        _row(Icons.child_friendly_outlined,'Parity',             _str(d['parity'])),
        const SizedBox(height: 12),
        _subheading('Vitals'),
        _row(Icons.height_outlined,       'Height',              _str(d['height']) == '—' ? '—' : '${_str(d['height'])} cm'),
        _row(Icons.monitor_weight_outlined,'Weight',             _str(d['weight']) == '—' ? '—' : '${_str(d['weight'])} kg'),
        _row(Icons.flag_outlined,         'Risk Level',          _str(d['riskLevel'])),
        const SizedBox(height: 12),
        _subheading('ANC Visits'),
        _boolRow('Has ANC Visits',                               d['hasAncVisits']),
        if (_str(d['ancVisits']) != '—')
          _row(Icons.numbers_outlined,    'Number of Visits',    _str(d['ancVisits'])),
        const SizedBox(height: 12),
        _subheading('Supplementation'),
        _boolRow('Iron Supplementation',                         d['receivingIron']),
        _boolRow('Folic Acid',                                   d['receivingFolicAcid']),
        _boolRow('IPTp (Malaria prophylaxis)',                    d['receivingIptp']),
        _boolRow('Tetanus Toxoid (TTV)',                         d['receivingTtv']),
      ],
    );
  }

  // ── outcome notes card ────────────────────────────────────────────────
  Widget _notesCard() {
    return _card(
      title: 'Outcome Notes',
      icon: Icons.notes_outlined,
      children: [
        Text(
          enrollment.outcomeNotes!,
          style: const TextStyle(
            fontSize: 14,
            color: _textMid,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ── shared widget helpers ─────────────────────────────────────────────
  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: _color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _subheading(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _color,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _textSoft),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _textMid,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: _textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boolRow(String label, dynamic value) {
    final isTrue = value == true || value == 'true';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isTrue ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 15,
            color: isTrue ? const Color(0xFF22C55E) : _textSoft,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isTrue ? _textDark : _textMid,
              fontWeight: isTrue ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}