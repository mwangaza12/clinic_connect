import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../patient/domain/entities/patient.dart';
import '../../domain/entities/encounter.dart';
import '../bloc/encounter_bloc.dart';
import '../bloc/encounter_event.dart';
import '../bloc/encounter_state.dart';

class CreateEncounterPage extends StatelessWidget {
  final Patient patient;

  const CreateEncounterPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EncounterBloc>(),
      child: _CreateEncounterView(patient: patient),
    );
  }
}

class _CreateEncounterView extends StatefulWidget {
  final Patient patient;
  const _CreateEncounterView({required this.patient});

  @override
  State<_CreateEncounterView> createState() => _CreateEncounterViewState();
}

class _CreateEncounterViewState extends State<_CreateEncounterView> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // ── Triage ──────────────────────────────
  final _chiefComplaintController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _tempController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _o2Controller = TextEditingController();
  final _pulseController = TextEditingController();
  final _rrController = TextEditingController();
  final _glucoseController = TextEditingController();

  // ── Consultation ─────────────────────────
  final _historyController = TextEditingController();
  final _examinationController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();

  EncounterType _encounterType = EncounterType.outpatient;
  Disposition _disposition = Disposition.discharged;
  final List<Diagnosis> _diagnoses = [];

  // ICD-10 common Kenya diagnoses for quick pick
  final List<Map<String, String>> _commonDiagnoses = [
    {'code': 'A09', 'desc': 'Diarrhoea & gastroenteritis'},
    {'code': 'A15', 'desc': 'Respiratory tuberculosis'},
    {'code': 'A90', 'desc': 'Dengue fever'},
    {'code': 'B50', 'desc': 'Malaria (Plasmodium falciparum)'},
    {'code': 'B20', 'desc': 'HIV disease'},
    {'code': 'E11', 'desc': 'Type 2 diabetes mellitus'},
    {'code': 'I10', 'desc': 'Essential hypertension'},
    {'code': 'J00', 'desc': 'Acute nasopharyngitis (common cold)'},
    {'code': 'J18', 'desc': 'Pneumonia, unspecified'},
    {'code': 'J45', 'desc': 'Asthma'},
    {'code': 'K29', 'desc': 'Gastritis and duodenitis'},
    {'code': 'N39', 'desc': 'Urinary tract infection'},
    {'code': 'O80', 'desc': 'Normal delivery'},
    {'code': 'P07', 'desc': 'Preterm newborn'},
    {'code': 'Z34', 'desc': 'Antenatal care'},
  ];

  final Color primaryDark = const Color(0xFF1B4332);

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

  void _submit() {
    if (_chiefComplaintController.text.trim().isEmpty) {
      _showSnack('Chief complaint is required', Colors.orange);
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final vitals = Vitals(
      systolicBP: double.tryParse(_systolicController.text),
      diastolicBP: double.tryParse(_diastolicController.text),
      temperature: double.tryParse(_tempController.text),
      weight: double.tryParse(_weightController.text),
      height: double.tryParse(_heightController.text),
      oxygenSaturation: double.tryParse(_o2Controller.text),
      pulseRate: int.tryParse(_pulseController.text),
      respiratoryRate: int.tryParse(_rrController.text),
      bloodGlucose: double.tryParse(_glucoseController.text),
    );

    final encounter = Encounter(
      id: const Uuid().v4(),
      patientId: widget.patient.id,
      patientName: widget.patient.fullName,
      patientNupi: widget.patient.nupi,
      facilityId: authState.user.facilityId,
      facilityName: authState.user.facilityName,
      clinicianId: authState.user.id,
      clinicianName: authState.user.name,
      type: _encounterType,
      status: EncounterStatus.finished,
      vitals: vitals,
      chiefComplaint: _chiefComplaintController.text.trim(),
      historyOfPresentingIllness: _historyController.text.trim().isEmpty
          ? null
          : _historyController.text.trim(),
      examinationFindings: _examinationController.text.trim().isEmpty
          ? null
          : _examinationController.text.trim(),
      diagnoses: _diagnoses,
      treatmentPlan: _treatmentController.text.trim().isEmpty
          ? null
          : _treatmentController.text.trim(),
      clinicalNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      disposition: _disposition,
      encounterDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.read<EncounterBloc>().add(CreateEncounterEvent(encounter));
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _next() {
    if (_currentStep == 0 &&
        _chiefComplaintController.text.trim().isEmpty) {
      _showSnack('Please enter the chief complaint', Colors.orange);
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: primaryDark, size: 20),
          onPressed: _back,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Encounter',
              style: TextStyle(
                color: primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.patient.fullName,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: BlocConsumer<EncounterBloc, EncounterState>(
        listener: (context, state) {
          if (state is EncounterError) {
            _showSnack(state.message, Colors.red);
          } else if (state is EncounterCreated) {
            _showSnack('✅ Encounter saved!', const Color(0xFF2D6A4F));
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          final isLoading = state is EncounterLoading;
          return Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildTriagePage(),
                      _buildConsultationPage(),
                      _buildSummaryPage(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(isLoading),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // Progress Bar
  // ─────────────────────────────────────────
  Widget _buildProgressBar() {
    final steps = ['Triage', 'Consultation', 'Summary'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final lineIndex = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: _currentStep > lineIndex
                    ? primaryDark
                    : Colors.grey[200],
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isActive = _currentStep == stepIndex;
          final isDone = _currentStep > stepIndex;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: isDone || isActive
                      ? primaryDark
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 14)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? Colors.white
                                : Colors.grey[500],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isActive ? primaryDark : Colors.grey,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Step 1: Triage
  // ─────────────────────────────────────────
  Widget _buildTriagePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient card
          _patientCard(),
          const SizedBox(height: 24),

          // Encounter type
          _sectionHeader('Encounter Type', Icons.medical_services_outlined),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: EncounterType.values.map((t) {
              final isSelected = _encounterType == t;
              final label = t.name[0].toUpperCase() + t.name.substring(1);
              final icon = t == EncounterType.outpatient
                  ? Icons.chair_alt_outlined
                  : t == EncounterType.inpatient
                      ? Icons.bed_outlined
                      : t == EncounterType.emergency
                          ? Icons.emergency_outlined
                          : Icons.send_outlined;
              return GestureDetector(
                onTap: () => setState(() => _encounterType = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryDark
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? primaryDark
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Chief Complaint
          _sectionHeader('Chief Complaint *', Icons.chat_bubble_outline),
          const SizedBox(height: 12),
          _textField(
            controller: _chiefComplaintController,
            hint: 'What brings the patient in today?',
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Vitals
          _sectionHeader('Vitals', Icons.monitor_heart_outlined),
          const SizedBox(height: 4),
          const Text(
            'Leave blank if not measured',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),

          // BP row
          _vitalsRow([
            _vitalField(
              controller: _systolicController,
              label: 'Systolic BP',
              unit: 'mmHg',
              icon: Icons.favorite_outline,
              color: const Color(0xFFE11D48),
            ),
            _vitalField(
              controller: _diastolicController,
              label: 'Diastolic BP',
              unit: 'mmHg',
              icon: Icons.favorite_border,
              color: const Color(0xFFE11D48),
            ),
          ]),
          const SizedBox(height: 12),

          // Temp + O2
          _vitalsRow([
            _vitalField(
              controller: _tempController,
              label: 'Temperature',
              unit: '°C',
              icon: Icons.thermostat_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _vitalField(
              controller: _o2Controller,
              label: 'O₂ Saturation',
              unit: '%',
              icon: Icons.air_outlined,
              color: const Color(0xFF0EA5E9),
            ),
          ]),
          const SizedBox(height: 12),

          // Pulse + RR
          _vitalsRow([
            _vitalField(
              controller: _pulseController,
              label: 'Pulse Rate',
              unit: 'bpm',
              icon: Icons.monitor_heart_outlined,
              color: const Color(0xFF8B5CF6),
              isInt: true,
            ),
            _vitalField(
              controller: _rrController,
              label: 'Respiratory Rate',
              unit: 'bpm',
              icon: Icons.wind_power_outlined,
              color: const Color(0xFF06B6D4),
              isInt: true,
            ),
          ]),
          const SizedBox(height: 12),

          // Weight + Height
          _vitalsRow([
            _vitalField(
              controller: _weightController,
              label: 'Weight',
              unit: 'kg',
              icon: Icons.monitor_weight_outlined,
              color: const Color(0xFF2D6A4F),
            ),
            _vitalField(
              controller: _heightController,
              label: 'Height',
              unit: 'cm',
              icon: Icons.height_outlined,
              color: const Color(0xFF2D6A4F),
            ),
          ]),
          const SizedBox(height: 12),

          // Blood glucose
          _vitalField(
            controller: _glucoseController,
            label: 'Blood Glucose',
            unit: 'mmol/L',
            icon: Icons.water_drop_outlined,
            color: const Color(0xFFF59E0B),
            fullWidth: true,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Step 2: Consultation
  // ─────────────────────────────────────────
  Widget _buildConsultationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'History of Presenting Illness', Icons.history_edu_outlined),
          const SizedBox(height: 12),
          _textField(
            controller: _historyController,
            hint: 'Onset, duration, progression, associated symptoms...',
            maxLines: 4,
          ),
          const SizedBox(height: 20),

          _sectionHeader(
              'Examination Findings', Icons.search_outlined),
          const SizedBox(height: 12),
          _textField(
            controller: _examinationController,
            hint: 'General appearance, systems review...',
            maxLines: 4,
          ),
          const SizedBox(height: 20),

          // Diagnoses
          _sectionHeader('Diagnoses (ICD-10)', Icons.sick_outlined),
          const SizedBox(height: 8),

          // Added diagnoses chips
          if (_diagnoses.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _diagnoses.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: d.isPrimary
                        ? primaryDark.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: d.isPrimary
                          ? primaryDark
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (d.isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: primaryDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '1°',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        '${d.code} - ${d.description}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: d.isPrimary
                              ? primaryDark
                              : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _diagnoses.remove(d)),
                        child: Icon(Icons.close,
                            size: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Common diagnoses quick pick
          const Text(
            'Common Diagnoses (tap to add)',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonDiagnoses.map((d) {
              final isAdded = _diagnoses
                  .any((diag) => diag.code == d['code']);
              return GestureDetector(
                onTap: isAdded
                    ? null
                    : () {
                        setState(() {
                          _diagnoses.add(Diagnosis(
                            code: d['code']!,
                            description: d['desc']!,
                            isPrimary: _diagnoses.isEmpty,
                          ));
                        });
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAdded
                        ? Colors.grey[100]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAdded
                          ? Colors.grey[300]!
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '${d['code']} - ${d['desc']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAdded
                          ? Colors.grey[400]
                          : const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                      decoration: isAdded
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Custom diagnosis button
          OutlinedButton.icon(
            onPressed: () => _showCustomDiagnosisDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Custom ICD-10 Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryDark,
              side: BorderSide(color: primaryDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _sectionHeader('Treatment Plan', Icons.medical_information_outlined),
          const SizedBox(height: 12),
          _textField(
            controller: _treatmentController,
            hint: 'Medications prescribed, procedures, follow-up plan...',
            maxLines: 4,
          ),
          const SizedBox(height: 20),

          _sectionHeader('Additional Notes', Icons.notes_outlined),
          const SizedBox(height: 12),
          _textField(
            controller: _notesController,
            hint: 'Any additional clinical notes...',
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Disposition
          _sectionHeader('Disposition', Icons.exit_to_app_outlined),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Disposition.values.map((d) {
              final isSelected = _disposition == d;
              final label = d.name[0].toUpperCase() + d.name.substring(1);
              final color = d == Disposition.discharged
                  ? const Color(0xFF2D6A4F)
                  : d == Disposition.admitted
                      ? const Color(0xFF6366F1)
                      : d == Disposition.referred
                          ? const Color(0xFFF59E0B)
                          : d == Disposition.deceased
                              ? const Color(0xFFE11D48)
                              : const Color(0xFF94A3B8);

              return GestureDetector(
                onTap: () => setState(() => _disposition = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.grey[600],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Step 3: Summary
  // ─────────────────────────────────────────
  Widget _buildSummaryPage() {
    // Calculate BMI if available
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    String? bmi;
    if (weight != null && height != null && height > 0) {
      final h = height / 100;
      bmi = (weight / (h * h)).toStringAsFixed(1);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined,
                    color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Encounter Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm')
                            .format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Patient
          _summarySection('Patient', [
            _summaryRow('Name', widget.patient.fullName),
            _summaryRow('NUPI', widget.patient.nupi),
            _summaryRow('Age', '${widget.patient.age} years'),
            _summaryRow('Type',
                _encounterType.name[0].toUpperCase() +
                    _encounterType.name.substring(1)),
          ]),
          const SizedBox(height: 16),

          // Vitals summary
          if (_systolicController.text.isNotEmpty ||
              _tempController.text.isNotEmpty ||
              _weightController.text.isNotEmpty)
            _summarySection('Vitals', [
              if (_systolicController.text.isNotEmpty &&
                  _diastolicController.text.isNotEmpty)
                _summaryRow('Blood Pressure',
                    '${_systolicController.text}/${_diastolicController.text} mmHg'),
              if (_tempController.text.isNotEmpty)
                _summaryRow(
                    'Temperature', '${_tempController.text} °C'),
              if (_pulseController.text.isNotEmpty)
                _summaryRow(
                    'Pulse', '${_pulseController.text} bpm'),
              if (_o2Controller.text.isNotEmpty)
                _summaryRow(
                    'O₂ Saturation', '${_o2Controller.text}%'),
              if (_weightController.text.isNotEmpty)
                _summaryRow(
                    'Weight', '${_weightController.text} kg'),
              if (_heightController.text.isNotEmpty)
                _summaryRow(
                    'Height', '${_heightController.text} cm'),
              if (bmi != null) _summaryRow('BMI', bmi),
              if (_glucoseController.text.isNotEmpty)
                _summaryRow('Blood Glucose',
                    '${_glucoseController.text} mmol/L'),
            ]),

          if (_chiefComplaintController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _summarySection('Chief Complaint', [
              _summaryText(_chiefComplaintController.text),
            ]),
          ],

          if (_diagnoses.isNotEmpty) ...[
            const SizedBox(height: 16),
            _summarySection('Diagnoses', [
              ..._diagnoses.map((d) => _summaryRow(
                    d.isPrimary ? 'Primary' : 'Secondary',
                    '${d.code} - ${d.description}',
                  )),
            ]),
          ],

          if (_treatmentController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _summarySection('Treatment Plan', [
              _summaryText(_treatmentController.text),
            ]),
          ],

          const SizedBox(height: 16),
          _summarySection('Disposition', [
            _summaryRow(
                'Patient outcome',
                _disposition.name[0].toUpperCase() +
                    _disposition.name.substring(1)),
          ]),

          const SizedBox(height: 24),

          // FHIR note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined,
                    color: Color(0xFF6366F1), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This encounter will be stored as FHIR R4 resources: Encounter, Observation (vitals), and Condition (diagnoses).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4338CA),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Helper Widgets
  // ─────────────────────────────────────────
  Widget _patientCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryDark.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryDark.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryDark,
            child: Text(
              widget.patient.firstName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'NUPI: ${widget.patient.nupi} • ${widget.patient.age} yrs • ${widget.patient.gender}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
          fontWeight: FontWeight.w500, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryDark, width: 2),
        ),
      ),
    );
  }

  Widget _vitalsRow(List<Widget> children) {
    return Row(
      children: children
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: c,
                ),
              ))
          .toList(),
    );
  }

  Widget _vitalField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
    bool isInt = false,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: isInt
                      ? TextInputType.number
                      : const TextInputType.numberWithOptions(
                          decimal: true),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: '—',
                    hintStyle: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summarySection(String title, List<Widget> children) {
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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF475569),
        height: 1.5,
      ),
    );
  }

  // ─────────────────────────────────────────
  // Custom Diagnosis Dialog
  // ─────────────────────────────────────────
  void _showCustomDiagnosisDialog() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Add ICD-10 Diagnosis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(
                labelText: 'ICD-10 Code',
                hintText: 'e.g. A01.0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Typhoid fever',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeCtrl.text.isNotEmpty && descCtrl.text.isNotEmpty) {
                setState(() {
                  _diagnoses.add(Diagnosis(
                    code: codeCtrl.text.trim().toUpperCase(),
                    description: descCtrl.text.trim(),
                    isPrimary: _diagnoses.isEmpty,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Bottom Actions
  // ─────────────────────────────────────────
  Widget _buildBottomBar(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : _back,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      if (_currentStep < 2) {
                        _next();
                      } else {
                        _submit();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == 2
                          ? 'Save Encounter'
                          : 'Continue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}