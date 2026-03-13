import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/encounter.dart';
import '../bloc/encounter_bloc.dart';
import '../bloc/encounter_event.dart';
import '../bloc/encounter_state.dart';

class EditEncounterPage extends StatelessWidget {
  final Encounter encounter;
  const EditEncounterPage({super.key, required this.encounter});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EncounterBloc>(),
      child: _EditEncounterView(encounter: encounter),
    );
  }
}

class _EditEncounterView extends StatefulWidget {
  final Encounter encounter;
  const _EditEncounterView({required this.encounter});

  @override
  State<_EditEncounterView> createState() => _EditEncounterViewState();
}

class _EditEncounterViewState extends State<_EditEncounterView> {
  final _pageController = PageController();
  int _currentStep = 0;

  // ── Triage ────────────────────────────────────────────────────
  late final TextEditingController _chiefComplaintController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _tempController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _o2Controller;
  late final TextEditingController _pulseController;
  late final TextEditingController _rrController;
  late final TextEditingController _glucoseController;

  // ── Consultation ──────────────────────────────────────────────
  late final TextEditingController _historyController;
  late final TextEditingController _examinationController;
  late final TextEditingController _treatmentController;
  late final TextEditingController _notesController;

  late EncounterType   _encounterType;
  late Disposition     _disposition;
  late List<Diagnosis> _diagnoses;

  static const Color _primary = Color(0xFF1B4332);

  final List<Map<String, String>> _commonDiagnoses = [
    {'code': 'A09', 'desc': 'Diarrhoea & gastroenteritis'},
    {'code': 'A15', 'desc': 'Respiratory tuberculosis'},
    {'code': 'B50', 'desc': 'Malaria (Plasmodium falciparum)'},
    {'code': 'B20', 'desc': 'HIV disease'},
    {'code': 'E11', 'desc': 'Type 2 diabetes mellitus'},
    {'code': 'I10', 'desc': 'Essential hypertension'},
    {'code': 'J00', 'desc': 'Common cold'},
    {'code': 'J18', 'desc': 'Pneumonia, unspecified'},
    {'code': 'J45', 'desc': 'Asthma'},
    {'code': 'K29', 'desc': 'Gastritis and duodenitis'},
    {'code': 'N39', 'desc': 'Urinary tract infection'},
    {'code': 'Z34', 'desc': 'Antenatal care'},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.encounter;
    final v = e.vitals;

    _chiefComplaintController  = TextEditingController(text: e.chiefComplaint ?? '');
    _systolicController        = TextEditingController(text: v?.systolicBP?.toStringAsFixed(0) ?? '');
    _diastolicController       = TextEditingController(text: v?.diastolicBP?.toStringAsFixed(0) ?? '');
    _tempController            = TextEditingController(text: v?.temperature?.toString() ?? '');
    _weightController          = TextEditingController(text: v?.weight?.toString() ?? '');
    _heightController          = TextEditingController(text: v?.height?.toString() ?? '');
    _o2Controller              = TextEditingController(text: v?.oxygenSaturation?.toString() ?? '');
    _pulseController           = TextEditingController(text: v?.pulseRate?.toString() ?? '');
    _rrController              = TextEditingController(text: v?.respiratoryRate?.toString() ?? '');
    _glucoseController         = TextEditingController(text: v?.bloodGlucose?.toString() ?? '');
    _historyController         = TextEditingController(text: e.historyOfPresentingIllness ?? '');
    _examinationController     = TextEditingController(text: e.examinationFindings ?? '');
    _treatmentController       = TextEditingController(text: e.treatmentPlan ?? '');
    _notesController           = TextEditingController(text: e.clinicalNotes ?? '');
    _encounterType             = e.type;
    _disposition               = e.disposition ?? Disposition.discharged;
    _diagnoses                 = List<Diagnosis>.from(e.diagnoses);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chiefComplaintController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _tempController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _o2Controller.dispose();
    _pulseController.dispose();
    _rrController.dispose();
    _glucoseController.dispose();
    _historyController.dispose();
    _examinationController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────

  void _next() {
    if (_currentStep == 0 && _chiefComplaintController.text.trim().isEmpty) {
      _snack('Chief complaint is required', Colors.orange);
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── Submit ────────────────────────────────────────────────────

  void _submit() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final vitals = Vitals(
      systolicBP:       double.tryParse(_systolicController.text),
      diastolicBP:      double.tryParse(_diastolicController.text),
      temperature:      double.tryParse(_tempController.text),
      weight:           double.tryParse(_weightController.text),
      height:           double.tryParse(_heightController.text),
      oxygenSaturation: double.tryParse(_o2Controller.text),
      pulseRate:        int.tryParse(_pulseController.text),
      respiratoryRate:  int.tryParse(_rrController.text),
      bloodGlucose:     double.tryParse(_glucoseController.text),
    );

    final updated = Encounter(
      id:           widget.encounter.id,
      patientId:    widget.encounter.patientId,
      patientName:  widget.encounter.patientName,
      patientNupi:  widget.encounter.patientNupi,
      facilityId:   widget.encounter.facilityId,
      facilityName: widget.encounter.facilityName,
      clinicianId:  widget.encounter.clinicianId,
      clinicianName: widget.encounter.clinicianName,
      type:         _encounterType,
      status:       widget.encounter.status,
      vitals:       vitals,
      chiefComplaint: _chiefComplaintController.text.trim(),
      historyOfPresentingIllness: _historyController.text.trim().isEmpty
          ? null : _historyController.text.trim(),
      examinationFindings: _examinationController.text.trim().isEmpty
          ? null : _examinationController.text.trim(),
      diagnoses:    List<Diagnosis>.from(_diagnoses),
      treatmentPlan: _treatmentController.text.trim().isEmpty
          ? null : _treatmentController.text.trim(),
      clinicalNotes: _notesController.text.trim().isEmpty
          ? null : _notesController.text.trim(),
      disposition:  _disposition,
      encounterDate: widget.encounter.encounterDate,
      createdAt:    widget.encounter.createdAt,
      updatedAt:    DateTime.now(),
    );

    context.read<EncounterBloc>().add(UpdateEncounterEvent(updated));
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: _back,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Encounter',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(
              widget.encounter.patientName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_currentStep + 1}/3',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: BlocConsumer<EncounterBloc, EncounterState>(
        listener: (context, state) {
          if (state is EncounterUpdated) {
            _snack('Encounter updated ✓', Colors.green);
            Navigator.pop(context, state.encounter);
          } else if (state is EncounterError) {
            _snack(state.message, Colors.red);
          }
        },
        builder: (context, state) {
          final loading = state is EncounterLoading;
          return Column(
            children: [
              _buildStepBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep0Triage(),
                    _buildStep1Consultation(),
                    _buildStep2Summary(),
                  ],
                ),
              ),
              _buildBottomBar(loading),
            ],
          );
        },
      ),
    );
  }

  // ── Step bar ──────────────────────────────────────────────────

  Widget _buildStepBar() {
    const steps = ['Triage', 'Consultation', 'Review'];
    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final done   = _currentStep > i;
          final active = _currentStep == i;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done || active
                        ? Colors.white
                        : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < steps.length - 1) const SizedBox(width: 4),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Step 0: Triage ────────────────────────────────────────────

  Widget _buildStep0Triage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encounter type
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Encounter Type', Icons.local_hospital_outlined),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: EncounterType.values.map((t) {
                  final sel = _encounterType == t;
                  final color = t == EncounterType.emergency
                      ? const Color(0xFFE11D48)
                      : t == EncounterType.inpatient
                          ? const Color(0xFF6366F1)
                          : t == EncounterType.referral
                              ? const Color(0xFFF59E0B)
                              : _primary;
                  return GestureDetector(
                    onTap: () => setState(() => _encounterType = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? color : color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        t.name[0].toUpperCase() + t.name.substring(1),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: sel ? Colors.white : color),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          )),
          const SizedBox(height: 12),

          // Chief complaint
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Chief Complaint *', Icons.chat_bubble_outline),
              const SizedBox(height: 12),
              _textField(
                controller: _chiefComplaintController,
                hint: 'Describe the main complaint',
                maxLines: 3,
              ),
            ],
          )),
          const SizedBox(height: 12),

          // Vitals
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Vitals (optional)', Icons.monitor_heart_outlined),
              const SizedBox(height: 12),
              _vitalsRow([
                _vitalsField(_systolicController, 'Systolic BP', 'mmHg',
                    icon: Icons.favorite_outline, color: const Color(0xFFE11D48)),
                _vitalsField(_diastolicController, 'Diastolic BP', 'mmHg',
                    icon: Icons.favorite_border, color: const Color(0xFFE11D48)),
              ]),
              _vitalsRow([
                _vitalsField(_tempController, 'Temperature', '°C',
                    icon: Icons.thermostat_outlined, color: const Color(0xFFF59E0B)),
                _vitalsField(_o2Controller, 'O₂ Saturation', '%',
                    icon: Icons.air_outlined, color: const Color(0xFF0EA5E9)),
              ]),
              _vitalsRow([
                _vitalsField(_pulseController, 'Pulse Rate', 'bpm',
                    icon: Icons.monitor_heart_outlined, color: const Color(0xFF8B5CF6), isInt: true),
                _vitalsField(_rrController, 'Respiratory Rate', '/min',
                    icon: Icons.wind_power_outlined, color: const Color(0xFF06B6D4), isInt: true),
              ]),
              _vitalsRow([
                _vitalsField(_weightController, 'Weight', 'kg',
                    icon: Icons.monitor_weight_outlined, color: const Color(0xFF2D6A4F)),
                _vitalsField(_heightController, 'Height', 'cm',
                    icon: Icons.height_outlined, color: const Color(0xFF2D6A4F)),
              ]),
              _vitalsRow([
                _vitalsField(_glucoseController, 'Blood Glucose', 'mmol/L',
                    icon: Icons.water_drop_outlined, color: const Color(0xFFF59E0B)),
                const Expanded(child: SizedBox()),
              ]),
            ],
          )),
        ],
      ),
    );
  }

  // ── Step 1: Consultation ──────────────────────────────────────

  Widget _buildStep1Consultation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('History of Presenting Illness',
                  Icons.history_edu_outlined),
              const SizedBox(height: 12),
              _textField(
                controller: _historyController,
                hint: 'Detailed history of the presenting illness',
                maxLines: 4,
              ),
            ],
          )),
          const SizedBox(height: 12),

          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Examination Findings', Icons.search_outlined),
              const SizedBox(height: 12),
              _textField(
                controller: _examinationController,
                hint: 'Physical examination findings',
                maxLines: 4,
              ),
            ],
          )),
          const SizedBox(height: 12),

          // Diagnoses
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Diagnoses', Icons.sick_outlined),
              const SizedBox(height: 12),
              if (_diagnoses.isNotEmpty) ...[
                ..._diagnoses.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: d.isPrimary
                        ? const Color(0xFF6366F1).withOpacity(0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: d.isPrimary
                            ? const Color(0xFF6366F1).withOpacity(0.3)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(d.code,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: Color(0xFF6366F1))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(d.description,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A)))),
                    if (d.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('PRIMARY',
                            style: TextStyle(
                                fontSize: 9, color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _diagnoses.remove(d)),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: Color(0xFF94A3B8)),
                    ),
                  ]),
                )),
                const SizedBox(height: 8),
              ],

              // Common diagnoses picker
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _commonDiagnoses.map((cd) {
                  final selected =
                      _diagnoses.any((d) => d.code == cd['code']);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _diagnoses.removeWhere(
                              (d) => d.code == cd['code']);
                        } else {
                          _diagnoses.add(Diagnosis(
                            code: cd['code']!,
                            description: cd['desc']!,
                            isPrimary: _diagnoses.isEmpty,
                          ));
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${cd['code']} · ${cd['desc']}',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _showCustomDiagnosisDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add custom ICD-10 code'),
                style: TextButton.styleFrom(foregroundColor: _primary),
              ),
            ],
          )),
          const SizedBox(height: 12),

          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Treatment Plan', Icons.medication_outlined),
              const SizedBox(height: 12),
              _textField(
                controller: _treatmentController,
                hint: 'Medications, procedures, follow-up instructions',
                maxLines: 4,
              ),
            ],
          )),
          const SizedBox(height: 12),

          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Clinical Notes', Icons.notes_outlined),
              const SizedBox(height: 12),
              _textField(
                controller: _notesController,
                hint: 'Additional clinical observations',
                maxLines: 3,
              ),
            ],
          )),
          const SizedBox(height: 12),

          // Disposition
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Disposition', Icons.exit_to_app_outlined),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: Disposition.values.map((d) {
                  final sel = _disposition == d;
                  final color = d == Disposition.discharged
                      ? _primary
                      : d == Disposition.admitted
                          ? const Color(0xFF6366F1)
                          : d == Disposition.referred
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFE11D48);
                  return GestureDetector(
                    onTap: () => setState(() => _disposition = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? color : color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        d.name[0].toUpperCase() + d.name.substring(1),
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13,
                            color: sel ? Colors.white : color),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          )),
        ],
      ),
    );
  }

  // ── Step 2: Summary / Review ──────────────────────────────────

  Widget _buildStep2Summary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Review Changes', Icons.checklist_outlined),
              const SizedBox(height: 14),
              _summaryRow('Type',
                  _encounterType.name[0].toUpperCase() +
                      _encounterType.name.substring(1)),
              _summaryRow('Chief Complaint',
                  _chiefComplaintController.text.trim()),
              if (_diagnoses.isNotEmpty)
                _summaryRow('Diagnoses',
                    _diagnoses.map((d) => '${d.code} ${d.description}').join(', ')),
              if (_treatmentController.text.trim().isNotEmpty)
                _summaryRow('Treatment', _treatmentController.text.trim()),
              _summaryRow('Disposition',
                  _disposition.name[0].toUpperCase() +
                      _disposition.name.substring(1)),
            ],
          )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primary.withOpacity(0.15)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF1B4332), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Saving will update this encounter in Firestore and sync to the local database.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF1B4332), height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Custom diagnosis dialog ───────────────────────────────────

  void _showCustomDiagnosisDialog() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add ICD-10 Diagnosis'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: codeCtrl,
            decoration: const InputDecoration(
                labelText: 'ICD-10 Code', hintText: 'e.g. A01.0'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
                labelText: 'Description', hintText: 'e.g. Typhoid fever'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () {
              if (codeCtrl.text.trim().isNotEmpty &&
                  descCtrl.text.trim().isNotEmpty) {
                setState(() => _diagnoses.add(Diagnosis(
                  code: codeCtrl.text.trim().toUpperCase(),
                  description: descCtrl.text.trim(),
                  isPrimary: _diagnoses.isEmpty,
                )));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────

  Widget _buildBottomBar(bool loading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      color: Colors.white,
      child: Row(children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: loading ? null : _back,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back',
                  style: TextStyle(
                      color: _primary, fontWeight: FontWeight.w700)),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: loading ? null : _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _currentStep < 2 ? 'Next' : 'Save Changes',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      );

  Widget _sectionLabel(String title, IconData icon) => Row(children: [
        Icon(icon, size: 16, color: _primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
      ]);

  Widget _textField({
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
        ),
      );

  // ── Vital thresholds ─────────────────────────────────────────────────────
  static const Map<String, Map<String, double>> _vitalThresholds = {
    'Systolic BP':      {'low': 90,  'high': 140, 'criticalLow': 70,  'criticalHigh': 180},
    'Diastolic BP':     {'low': 60,  'high': 90,  'criticalLow': 40,  'criticalHigh': 120},
    'Temperature':      {'low': 36.0,'high': 37.5,'criticalLow': 35.0,'criticalHigh': 39.5},
    'O₂ Saturation':  {'low': 95,  'high': 100, 'criticalLow': 90,  'criticalHigh': 100},
    'Pulse Rate':       {'low': 60,  'high': 100, 'criticalLow': 40,  'criticalHigh': 130},
    'Respiratory Rate': {'low': 12,  'high': 20,  'criticalLow': 8,   'criticalHigh': 30},
    'Blood Glucose':    {'low': 3.9, 'high': 7.8, 'criticalLow': 2.8, 'criticalHigh': 13.9},
  };

  String? _vitalStatus(String label, String text) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    final t = _vitalThresholds[label];
    if (t == null) return null;
    if ((t['criticalLow']  != null && v < t['criticalLow']!) ||
        (t['criticalHigh'] != null && v > t['criticalHigh']!)) return 'critical';
    if ((t['low']  != null && v < t['low']!) ||
        (t['high'] != null && v > t['high']!)) return 'elevated';
    return null;
  }

  Widget _vitalsRow(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: children
            .expand((w) => [w, const SizedBox(width: 10)])
            .toList()
          ..removeLast()),
      );

  Widget _vitalsField(
    TextEditingController controller,
    String label,
    String unit, {
    IconData icon = Icons.monitor_heart_outlined,
    Color color = const Color(0xFF64748B),
    bool isInt = false,
  }) {
    return Expanded(
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final status     = _vitalStatus(label, value.text);
          final isCritical = status == 'critical';
          final isElevated = status == 'elevated';

          final borderColor = isCritical
              ? const Color(0xFFDC2626)
              : isElevated ? const Color(0xFFD97706) : const Color(0xFFE2E8F0);
          final bgColor = isCritical
              ? const Color(0xFFFEF2F2)
              : isElevated ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC);
          final accentColor = isCritical
              ? const Color(0xFFDC2626)
              : isElevated ? const Color(0xFFD97706) : color;
          final valueColor = isCritical
              ? const Color(0xFFDC2626)
              : isElevated ? const Color(0xFFD97706) : const Color(0xFF0F172A);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: borderColor,
                  width: (isCritical || isElevated) ? 1.5 : 1.0),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 13, color: accentColor),
                const SizedBox(width: 4),
                Expanded(child: Text(label,
                    style: TextStyle(fontSize: 10, color: accentColor,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
                if (isCritical)
                  _vitalAlertTag('CRITICAL', const Color(0xFFDC2626), const Color(0xFFFEE2E2))
                else if (isElevated) ...[
                  _vitalAlertTag(
                    double.tryParse(value.text.trim()) != null &&
                        _vitalThresholds[label] != null &&
                        double.parse(value.text.trim()) < (_vitalThresholds[label]!['low'] ?? 0)
                        ? 'LOW' : 'HIGH',
                    const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: controller,
                  keyboardType: isInt
                      ? TextInputType.number
                      : const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: valueColor),
                  decoration: InputDecoration(
                    hintText: '—',
                    hintStyle: TextStyle(color: Colors.grey[300], fontSize: 18),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                )),
                Text(unit, style: TextStyle(fontSize: 11,
                    color: isCritical ? const Color(0xFFDC2626)
                        : isElevated ? const Color(0xFFD97706) : Colors.grey[400],
                    fontWeight: FontWeight.w500)),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _vitalAlertTag(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(
            fontSize: 8, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.3)),
      );

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A))),
            ),
          ],
        ),
      );
}