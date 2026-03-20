// lib/features/home/presentation/pages/check_in_page.dart
//
// 3-step nurse check-in:
//   Step 1 — Select Patient
//   Step 2 — Priority & Chief Complaint
//   Step 3 — Vitals + Review & Confirm

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../injection_container.dart';
import '../../../patient/domain/entities/patient.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/bloc/patient_state.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});
  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  static const _primary = Colors.teal;
  static const _primaryDark = Color(0xFF00796B);

  final _pageCtrl      = PageController();
  final _searchCtrl    = TextEditingController();
  final _complaintCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();
  final _bpSysCtrl     = TextEditingController();
  final _bpDiaCtrl     = TextEditingController();
  final _tempCtrl      = TextEditingController();
  final _weightCtrl    = TextEditingController();
  final _spo2Ctrl      = TextEditingController();
  final _pulseCtrl     = TextEditingController();

  int      _step     = 0;
  Patient? _patient;
  String   _priority = 'medium';
  bool     _saving   = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _searchCtrl, _complaintCtrl, _notesCtrl,
      _bpSysCtrl, _bpDiaCtrl, _tempCtrl,
      _weightCtrl, _spo2Ctrl, _pulseCtrl,
    ]) c.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────

  void _next() {
    if (_step == 0 && _patient == null) {
      _snack('Please select a patient', Colors.orange);
      return;
    }
    if (_step == 1 && _complaintCtrl.text.trim().isEmpty) {
      _snack('Please enter chief complaint', Colors.orange);
      return;
    }
    setState(() => _step++);
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // ── Submit ───────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final vitals = <String, dynamic>{};
      if (_bpSysCtrl.text.isNotEmpty)
        vitals['systolic_bp'] = int.tryParse(_bpSysCtrl.text);
      if (_bpDiaCtrl.text.isNotEmpty)
        vitals['diastolic_bp'] = int.tryParse(_bpDiaCtrl.text);
      if (_tempCtrl.text.isNotEmpty)
        vitals['temperature'] = double.tryParse(_tempCtrl.text);
      if (_weightCtrl.text.isNotEmpty)
        vitals['weight'] = double.tryParse(_weightCtrl.text);
      if (_spo2Ctrl.text.isNotEmpty)
        vitals['oxygen_saturation'] = int.tryParse(_spo2Ctrl.text);
      if (_pulseCtrl.text.isNotEmpty)
        vitals['pulse_rate'] = int.tryParse(_pulseCtrl.text);

      final fid = FacilityInfo().facilityId;
      await FirebaseConfig.facilityDb.collection('triage_queue').add({
        'patient_nupi':    _patient!.nupi,
        'patient_name':    _patient!.fullName,
        'patient_gender':  _patient!.gender,
        'patient_age':     _patient!.age,
        'facility_id':     fid,
        'chief_complaint': _complaintCtrl.text.trim(),
        'priority':        _priority,
        'status':          'waiting',
        'notes':           _notesCtrl.text.trim().isEmpty
                               ? null : _notesCtrl.text.trim(),
        'vitals':          vitals.isEmpty ? null : vitals,
        'created_at':      FieldValue.serverTimestamp(),
        'updated_at':      FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _snack('✅ ${_patient!.firstName} checked in', _primaryDark);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack('Failed: $e', Colors.red);
      setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<PatientBloc>()..add(const LoadPatientsByFacilityEvent()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _primaryDark, size: 20),
            onPressed: _back,
          ),
          title: const Text('Patient Check-In',
              style: TextStyle(
                  color: _primaryDark,
                  fontWeight: FontWeight.w800)),
        ),
        body: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(children: [
        _stepDot(0, 'Patient'),
        _stepLine(0),
        _stepDot(1, 'Complaint'),
        _stepLine(1),
        _stepDot(2, 'Vitals'),
      ]),
    );
  }

  Widget _stepDot(int index, String label) {
    final done   = _step > index;
    final active = _step == index;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: done || active ? _primaryDark : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text('${index + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey[500],
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active ? _primaryDark : Colors.grey,
          )),
    ]);
  }

  Widget _stepLine(int index) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: _step > index ? _primaryDark : Colors.grey[200],
    ),
  );

  // ── Step 1: Select Patient ────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepTitle('Select Patient', 'Search registered patients at this facility'),
        const SizedBox(height: 20),

        if (_patient != null) ...[
          _SelectedPatientCard(
            patient: _patient!,
            onClear: () => setState(() => _patient = null),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primaryDark.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryDark.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: _primaryDark, size: 18),
              const SizedBox(width: 10),
              Text('Patient selected. Tap Continue to proceed.',
                  style: TextStyle(
                      color: _primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ] else ...[
          Builder(builder: (ctx) => _PatientSearchField(
            controller: _searchCtrl,
            onSelect: (p) => setState(() {
              _patient = p;
              _searchCtrl.clear();
            }),
          )),
        ],
      ]),
    );
  }

  // ── Step 2: Priority & Chief Complaint ───────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepTitle('Triage Details',
            'Set urgency level and reason for visit'),
        const SizedBox(height: 20),

        // Mini patient reminder
        if (_patient != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _primaryDark.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 16, backgroundColor: _primaryDark,
                child: Text(
                  _patient!.firstName.isNotEmpty
                      ? _patient!.firstName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Text(_patient!.fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 6),
              Text('${_patient!.age} yrs',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
          ),

        const Text('Priority Level',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 10),
        _PrioritySelector(
          value: _priority,
          onChange: (v) => setState(() => _priority = v),
        ),
        const SizedBox(height: 20),

        const Text('Chief Complaint *',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        _inputField(
          controller: _complaintCtrl,
          hint: 'What brings the patient in today?',
          icon: Icons.notes_rounded,
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        const Text('Additional Notes (optional)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        _inputField(
          controller: _notesCtrl,
          hint: 'Any other relevant information...',
          icon: Icons.edit_note_rounded,
          maxLines: 3,
        ),
      ]),
    );
  }

  // ── Step 3: Vitals + Review ───────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepTitle('Vitals & Confirm',
            'Record vitals if available, then confirm check-in'),
        const SizedBox(height: 20),

        const Text('Quick Vitals (optional)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: _vitalField(_bpSysCtrl, 'Systolic', 'mmHg',
              Icons.favorite_rounded, Colors.red)),
          const SizedBox(width: 10),
          Expanded(child: _vitalField(_bpDiaCtrl, 'Diastolic', 'mmHg',
              Icons.favorite_border_rounded, Colors.pink)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _vitalField(_pulseCtrl, 'Pulse', 'bpm',
              Icons.timeline_rounded, Colors.blue)),
          const SizedBox(width: 10),
          Expanded(child: _vitalField(_tempCtrl, 'Temp', '°C',
              Icons.thermostat_rounded, Colors.orange)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _vitalField(_spo2Ctrl, 'SpO₂', '%',
              Icons.air_rounded, Colors.teal)),
          const SizedBox(width: 10),
          Expanded(child: _vitalField(_weightCtrl, 'Weight', 'kg',
              Icons.monitor_weight_rounded, Colors.purple)),
        ]),

        const SizedBox(height: 24),

        // Review summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryDark.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryDark.withOpacity(0.15)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CHECK-IN SUMMARY',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _primaryDark,
                    letterSpacing: 0.8)),
            const SizedBox(height: 12),
            _summaryRow(Icons.person_rounded, 'Patient',
                _patient?.fullName ?? '—'),
            _summaryRow(Icons.flag_rounded, 'Priority',
                _priority.toUpperCase()),
            _summaryRow(Icons.notes_rounded, 'Complaint',
                _complaintCtrl.text.trim().isEmpty
                    ? '—' : _complaintCtrl.text.trim()),
          ]),
        ),
      ]),
    );
  }

  // ── Bottom action bar ─────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _back,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: _primaryDark),
                foregroundColor: _primaryDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _saving
                ? null
                : (_step < 2 ? _next : _submit),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _step == 2 ? 'Confirm Check-In' : 'Continue',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────

  Widget _stepTitle(String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _primaryDark)),
      const SizedBox(height: 4),
      Text(sub,
          style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 13)),
    ],
  );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 48 : 0),
            child: Icon(icon, color: _primaryDark, size: 20),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryDark, width: 2),
          ),
        ),
      );

  Widget _vitalField(TextEditingController ctrl, String label,
      String unit, IconData icon, Color color) =>
      TextField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          prefixIcon: Icon(icon, color: color, size: 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: 2),
          ),
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      );

  Widget _summaryRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: _primaryDark),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

// ── Patient search field ──────────────────────────────────────────────────────

class _PatientSearchField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(Patient) onSelect;
  const _PatientSearchField(
      {required this.controller, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: controller,
        onChanged: (q) {
          if (q.isEmpty) {
            context
                .read<PatientBloc>()
                .add(const LoadPatientsByFacilityEvent());
          } else {
            context.read<PatientBloc>().add(SearchPatientEvent(q));
          }
        },
        decoration: InputDecoration(
          hintText: 'Search by name or NUPI...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF00796B)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF00796B), width: 2),
          ),
        ),
      ),
      const SizedBox(height: 8),
      BlocBuilder<PatientBloc, PatientState>(
        builder: (context, state) {
          if (state is PatientLoading) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator.adaptive(),
            );
          }
          if (state is PatientsLoaded && state.patients.isNotEmpty) {
            return Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.patients.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final p = state.patients[i];
                  return ListTile(
                    onTap: () => onSelect(p),
                    leading: CircleAvatar(
                      backgroundColor: p.gender == 'female'
                          ? const Color(0xFFEC4899).withOpacity(0.12)
                          : const Color(0xFF00796B).withOpacity(0.12),
                      child: Text(
                        p.firstName.isNotEmpty
                            ? p.firstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: p.gender == 'female'
                              ? const Color(0xFFEC4899)
                              : const Color(0xFF00796B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(p.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text(
                        '${p.age} yrs  •  ${p.nupi}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFCBD5E1)),
                  );
                },
              ),
            );
          }
          if (state is PatientsLoaded && state.patients.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.search_off_rounded,
                    size: 40, color: Color(0xFFCBD5E1)),
                SizedBox(height: 8),
                Text('No patients found',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              ]),
            );
          }
          return const SizedBox();
        },
      ),
    ]);
  }
}

// ── Selected patient card ─────────────────────────────────────────────────────

class _SelectedPatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onClear;
  const _SelectedPatientCard(
      {required this.patient, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00796B).withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00796B).withOpacity(0.3), width: 1.5),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF00796B),
          child: Text(
            patient.firstName.isNotEmpty
                ? patient.firstName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient.fullName,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            Text('${patient.age} yrs  •  ${patient.nupi}',
                style: const TextStyle(
                    color: Color(0xFF00796B), fontSize: 12)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Color(0xFF00796B)),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

// ── Priority selector ─────────────────────────────────────────────────────────

class _PrioritySelector extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  const _PrioritySelector(
      {required this.value, required this.onChange});

  static const _opts = [
    (label: 'Low',      val: 'low',      color: Color(0xFF22C55E), icon: Icons.arrow_downward_rounded),
    (label: 'Medium',   val: 'medium',   color: Color(0xFF3B82F6), icon: Icons.remove_rounded),
    (label: 'High',     val: 'high',     color: Color(0xFFF59E0B), icon: Icons.arrow_upward_rounded),
    (label: 'Critical', val: 'critical', color: Color(0xFFEF4444), icon: Icons.emergency_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _opts.map((o) {
        final sel = value == o.val;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChange(o.val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel ? o.color : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? o.color : Colors.grey.shade200,
                  width: sel ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(o.icon,
                    color: sel ? Colors.white : o.color, size: 20),
                const SizedBox(height: 4),
                Text(o.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : o.color,
                    )),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}