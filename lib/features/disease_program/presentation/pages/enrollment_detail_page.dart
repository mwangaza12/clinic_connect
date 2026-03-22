// lib/features/disease_program/presentation/pages/enrollment_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/disease_program.dart';
import '../bloc/program_bloc.dart';
import '../bloc/program_event.dart';
import 'enroll_patient_page.dart';

class EnrollmentDetailPage extends StatefulWidget {
  final ProgramEnrollment enrollment;

  const EnrollmentDetailPage({super.key, required this.enrollment});

  @override
  State<EnrollmentDetailPage> createState() => _EnrollmentDetailPageState();
}

class _EnrollmentDetailPageState extends State<EnrollmentDetailPage> {
  late ProgramEnrollment _enrollment;

  @override
  void initState() {
    super.initState();
    _enrollment = widget.enrollment;
  }

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

  Color get _color => _programColors[_enrollment.program]!;
  IconData get _icon => _programIcons[_enrollment.program]!;

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
                if (_enrollment.status == ProgramEnrollmentStatus.died)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This patient is deceased. The enrollment record '
                            'is locked and cannot be edited.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _enrollmentSummaryCard(),
                const SizedBox(height: 16),
                _programSpecificCard(),
                const SizedBox(height: 16),
                if (_enrollment.outcomeNotes != null &&
                    _enrollment.outcomeNotes!.isNotEmpty)
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
      actions: [
        if (_enrollment.status == ProgramEnrollmentStatus.died) ...[
          // Deceased — show a lock indicator; no edits or status changes allowed
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Patient is deceased — record is locked',
              child: Icon(Icons.lock_outline_rounded,
                  color: Colors.white.withOpacity(0.7), size: 22),
            ),
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            tooltip: 'Change status',
            onPressed: _changeStatus,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: 'Edit enrollment',
            onPressed: _openEdit,
          ),
        ],
      ],
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
                              _enrollment.program.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _enrollment.patientName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusPill(_enrollment.status),
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

  Future<void> _changeStatus() async {
    final options = <_StatusOption>[
      if (_enrollment.status != ProgramEnrollmentStatus.active)
        _StatusOption(ProgramEnrollmentStatus.active,      'Active',       Icons.play_circle_outline_rounded,    Colors.green),
      if (_enrollment.status != ProgramEnrollmentStatus.completed)
        _StatusOption(ProgramEnrollmentStatus.completed,   'Complete',     Icons.check_circle_outline_rounded,   Colors.blue),
      if (_enrollment.status != ProgramEnrollmentStatus.defaulted)
        _StatusOption(ProgramEnrollmentStatus.defaulted,   'Defaulted',    Icons.warning_amber_rounded,          Colors.orange),
      if (_enrollment.status != ProgramEnrollmentStatus.transferred)
        _StatusOption(ProgramEnrollmentStatus.transferred, 'Transferred',  Icons.swap_horiz_rounded,             Colors.purple),
      if (_enrollment.status != ProgramEnrollmentStatus.died)
        _StatusOption(ProgramEnrollmentStatus.died,        'Deceased',     Icons.remove_circle_outline_rounded,  Colors.red),
    ];

    final notesCtrl = TextEditingController();

    final chosen = await showModalBottomSheet<ProgramEnrollmentStatus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Change program status',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Current: ${_enrollment.status.name.toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 16),
              ...options.map((o) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: o.color.withOpacity(0.12),
                  child: Icon(o.icon, color: o.color, size: 18),
                ),
                title: Text(o.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.grey),
                onTap: () => Navigator.pop(context, o.status),
              )),
              const Divider(),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  hintText: 'Optional notes (e.g. reason for change)…',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    // Fire the status update through a fresh bloc instance
    final bloc = sl<ProgramBloc>();
    bloc.add(UpdateEnrollmentStatus(
      enrollmentId: _enrollment.id,
      status:       chosen,
      notes:        notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    ));

    // Optimistically update local state so the badge refreshes immediately
    setState(() {
      _enrollment = ProgramEnrollment(
        id:                  _enrollment.id,
        patientNupi:         _enrollment.patientNupi,
        patientName:         _enrollment.patientName,
        facilityId:          _enrollment.facilityId,
        program:             _enrollment.program,
        status:              chosen,
        enrollmentDate:      _enrollment.enrollmentDate,
        completionDate:      chosen == ProgramEnrollmentStatus.completed
                                 ? DateTime.now()
                                 : _enrollment.completionDate,
        programSpecificData: _enrollment.programSpecificData,
        outcomeNotes:        notesCtrl.text.trim().isEmpty
                                 ? _enrollment.outcomeNotes
                                 : notesCtrl.text.trim(),
        createdAt:           _enrollment.createdAt,
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status updated to ${chosen.name.toUpperCase()}'),
        backgroundColor: const Color(0xFF2D6A4F),
      ));
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProgramBloc>(),
          child: EnrollPatientPage(
            patientNupi:        _enrollment.patientNupi,
            patientName:        _enrollment.patientName,
            facilityId:         _enrollment.facilityId,
            initialEnrollment:  _enrollment,
          ),
        ),
      ),
    );
    if (updated == true && mounted) {
      // Reload the enrollment from the detail page isn't straightforward
      // without a bloc — pop back to the dashboard so it refreshes.
      Navigator.pop(context, true);
    }
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
        _row(Icons.badge_outlined,        'NUPI',             _enrollment.patientNupi),
        _row(Icons.local_hospital_outlined,'Facility',        _enrollment.facilityId),
        _row(Icons.calendar_today_outlined,'Enrolled',        _fmt(_enrollment.enrollmentDate)),
        if (_enrollment.completionDate != null)
          _row(Icons.event_available_outlined, 'Completed',   _fmt(_enrollment.completionDate)),
        _row(Icons.sync_outlined,          'Sync status',
            _enrollment.programSpecificData != null ? 'Saved' : 'Pending'),
      ],
    );
  }

  // ── program-specific card ─────────────────────────────────────────────
  Widget _programSpecificCard() {
    final data = _enrollment.programSpecificData ?? {};

    final Widget content;
    switch (_enrollment.program) {
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
          _enrollment.outcomeNotes!,
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

class _StatusOption {
  final ProgramEnrollmentStatus status;
  final String   label;
  final IconData icon;
  final Color    color;
  const _StatusOption(this.status, this.label, this.icon, this.color);
}