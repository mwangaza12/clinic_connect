// lib/features/patient/presentation/pages/patient_lookup_page.dart
//
// FIXES:
//  1. _fetchQuestion calls HieApiService.getSecurityQuestion()
//     which now hits GET /api/verify/question (was /api/patients/verify/question)
//  2. _verifyAnswer calls HieApiService.verifySecurityAnswer()
//     which now hits POST /api/verify/answer (was /api/patients/verify/answer)
//  3. _createEncounter passes nupiPatient: data (Map) to CreateEncounterPage —
//     the named param exists and is typed Map<String,dynamic>?

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/hie_api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../encounter/presentation/pages/create_encounter_page.dart';
import '../../domain/entities/patient.dart';

class PatientLookupPage extends StatefulWidget {
  const PatientLookupPage({super.key});

  @override
  State<PatientLookupPage> createState() => _PatientLookupPageState();
}

class _PatientLookupPageState extends State<PatientLookupPage> {
  // ── Controllers ─────────────────────────────────────────────────
  final _nationalIdController = TextEditingController();
  final _dobController        = TextEditingController();
  final _answerController     = TextEditingController();

  // ── State ────────────────────────────────────────────────────────
  int     _step              = 0;
  bool    _loading           = false;
  String? _error;
  String? _securityQuestion;
  Map<String, dynamic>? _patientData;
  DateTime? _selectedDob;

  static const Color _primary = Color(0xFF1B4332);
  static const Color _accent  = Color(0xFF2D6A4F);
  static const Color _bg      = Color(0xFFF8FAFC);

  @override
  void dispose() {
    _nationalIdController.dispose();
    _dobController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  // ── Step 0: fetch security question ─────────────────────────────
  Future<void> _fetchQuestion() async {
    final nationalId = _nationalIdController.text.trim();
    if (nationalId.isEmpty || _selectedDob == null) {
      _setError('Please enter National ID and Date of Birth');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() { _loading = true; _error = null; });

    try {
      final dob = '${_selectedDob!.year}-'
          '${_selectedDob!.month.toString().padLeft(2, '0')}-'
          '${_selectedDob!.day.toString().padLeft(2, '0')}';

      // FIX: now calls GET /api/verify/question (via corrected HieApiService)
      final result = await HieApiService.instance.getSecurityQuestion(
        nationalId: nationalId,
        dob:        dob,
      );

      if (result.success && result.question != null) {
        setState(() {
          _securityQuestion = result.question;
          _step = 1;
        });
      } else {
        _setError(result.error ?? 'Patient not found on AfyaNet');
      }
    } catch (e) {
      _setError('Network error: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Step 1: verify answer → get full demographics ────────────────
  Future<void> _verifyAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      _setError('Please enter your answer');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() { _loading = true; _error = null; });

    try {
      final nationalId = _nationalIdController.text.trim();
      final dob = '${_selectedDob!.year}-'
          '${_selectedDob!.month.toString().padLeft(2, '0')}-'
          '${_selectedDob!.day.toString().padLeft(2, '0')}';

      // FIX: now calls POST /api/verify/answer (via corrected HieApiService)
      final result = await HieApiService.instance.verifySecurityAnswer(
        nationalId: nationalId,
        dob:        dob,
        answer:     answer,
        facilityId: authState.user.facilityId,
      );

      if (result.success && result.patientData != null) {
        setState(() {
          _patientData = result.patientData;
          _step = 2;
        });
      } else {
        _setError(result.error ?? 'Incorrect answer');
      }
    } catch (e) {
      _setError('Network error: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  void _reset() {
    setState(() {
      _step             = 0;
      _error            = null;
      _securityQuestion = null;
      _patientData      = null;
      _answerController.clear();
    });
  }

  // ── Pick DOB ─────────────────────────────────────────────────────
  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime(1990),
      firstDate:   DateTime(1900),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob    = picked;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  // ── Navigate to CreateEncounterPage ──────────────────────────────
  // FIX: was passing nupiPatient: data but CreateEncounterPage expects
  //      patient: (Patient) and nupiPatient: (Map?) — both are now correct.
  void _createEncounter(BuildContext context) {
    final data      = _patientData!;
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final hiPatient = Patient.fromHieData(
      data:       data,
      facilityId: authState.user.facilityId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEncounterPage(
          patient:     hiPatient,
          nupiPatient: data,   // raw HIE map — bloc will upsert into Firestore if needed
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 28),
            if (_error != null) ...[
              _buildErrorBanner(_error!),
              const SizedBox(height: 16),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 20),
        onPressed: _step > 0 ? _reset : () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cross-Facility Lookup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
          Text(
            ['Identity', 'Verify', 'Result'][_step],
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['Identity', 'Verify', 'Result'];
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 16),
              color: _step > i ~/ 2 ? _primary : Colors.grey[200],
            ),
          );
        }
        final idx    = i ~/ 2;
        final done   = _step > idx;
        final active = _step == idx;
        return Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: done || active ? _primary : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(child: done
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text('${idx + 1}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: active ? Colors.white : Colors.grey[500]))),
          ),
          const SizedBox(height: 4),
          Text(labels[idx],
              style: TextStyle(fontSize: 10,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? _primary : Colors.grey)),
        ]);
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:  return _buildStep0(key: const ValueKey(0));
      case 1:  return _buildStep1(key: const ValueKey(1));
      case 2:  return _buildStep2(key: const ValueKey(2));
      default: return const SizedBox();
    }
  }

  // ── Step 0 — National ID + DOB ───────────────────────────────────
  Widget _buildStep0({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBanner(
          Icons.hub_rounded,
          'National Patient Index',
          'Enter the patient\'s National ID and date of birth to retrieve their security question.',
        ),
        const SizedBox(height: 24),
        _label('National ID / Passport Number'),
        const SizedBox(height: 8),
        _inputField(
          controller: _nationalIdController,
          hint:       'e.g. 12345678',
          icon:       Icons.badge_outlined,
          inputType:  TextInputType.number,
        ),
        const SizedBox(height: 16),
        _label('Date of Birth'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDob,
          child: AbsorbPointer(
            child: _inputField(
              controller: _dobController,
              hint:       'Select date of birth',
              icon:       Icons.cake_outlined,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _primaryButton(
          label:   'Find Patient',
          icon:    Icons.search_rounded,
          loading: _loading,
          onTap:   _fetchQuestion,
        ),
      ],
    );
  }

  // ── Step 1 — Security Question ───────────────────────────────────
  Widget _buildStep1({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primary.withOpacity(0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1), shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: _primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Security Question',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8), letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Text(_securityQuestion ?? '',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 20),
        _label('Your Answer'),
        const SizedBox(height: 8),
        _inputField(
          controller: _answerController,
          hint:       'Type your answer',
          icon:       Icons.vpn_key_outlined,
        ),
        const SizedBox(height: 28),
        _primaryButton(
          label:   'Verify Identity',
          icon:    Icons.verified_user_outlined,
          loading: _loading,
          onTap:   _verifyAnswer,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: _reset,
            icon:  const Icon(Icons.arrow_back, size: 16),
            label: const Text('Start Over'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  // ── Step 2 — Demographics result ────────────────────────────────
  Widget _buildStep2({Key? key}) {
    final data           = _patientData!;
    final nupi           = data['nupi']?.toString()         ?? '';
    final name           = data['name']?.toString()         ?? 'Unknown';
    final gender         = data['gender']?.toString()       ?? '';
    final dob            = data['dateOfBirth']?.toString()  ?? '';
    final phone          = data['phoneNumber']?.toString()  ?? '';
    final county         = data['county']?.toString()       ?? '';
    final subCounty      = data['subCounty']?.toString()    ?? '';
    final facilityName   = data['registeredFacility']?.toString() ?? 'Unknown';
    final facilityCounty = data['facilityCounty']?.toString() ?? '';
    final bloodGroup     = data['bloodGroup']?.toString();
    final isCurrentFacility = data['isCurrentFacility'] == true;

    String age = '';
    try {
      final parts = dob.split('-');
      if (parts.length == 3) age = '${DateTime.now().year - int.parse(parts[0])} yrs';
    } catch (_) {}

    final genderColor = gender.toLowerCase() == 'female'
        ? const Color(0xFFEC4899) : const Color(0xFF3B82F6);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verified badge
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF2D6A4F), size: 14),
              SizedBox(width: 6),
              Text('Patient Verified',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Color(0xFF2D6A4F))),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Patient card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF2D6A4F).withOpacity(0.25), width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: genderColor, width: 3),
                ),
                child: CircleAvatar(
                  backgroundColor: _primary.withOpacity(0.08),
                  child: Text(initial,
                      style: const TextStyle(fontSize: 22,
                          fontWeight: FontWeight.w900, color: _primary)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _chip(nupi, const Color(0xFF6366F1)),
                  if (age.isNotEmpty) _chip(age, const Color(0xFF0EA5E9)),
                  if (gender.isNotEmpty) _chip(gender.toUpperCase(), genderColor),
                  if (bloodGroup != null) _chip(bloodGroup, const Color(0xFFE11D48)),
                ]),
              ])),
            ]),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            _sectionLabel('Demographics'),
            const SizedBox(height: 12),
            _detailRow(Icons.cake_outlined,       'Date of Birth', dob),
            _detailRow(Icons.phone_outlined,       'Phone',        phone),
            _detailRow(Icons.location_on_outlined, 'County',       county),
            if (subCounty.isNotEmpty)
              _detailRow(Icons.map_outlined, 'Sub-County', subCounty),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            _sectionLabel('Registered Facility'),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isCurrentFacility
                          ? const Color(0xFF2D6A4F) : const Color(0xFF0EA5E9))
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_hospital_rounded,
                    color: isCurrentFacility
                        ? const Color(0xFF2D6A4F) : const Color(0xFF0EA5E9),
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(facilityName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (facilityCounty.isNotEmpty)
                  Text('$facilityCounty County',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
              if (isCurrentFacility) _chip('This Facility', const Color(0xFF2D6A4F)),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(children: [
                Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Clinical records remain at the registering facility. '
                  'Only demographic data is shown here.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                )),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Create Encounter CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _createEncounter(context),
            icon:  const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Create Encounter',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon:  const Icon(Icons.search_rounded, size: 18),
            label: const Text('Search Another Patient'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────

  Widget _infoBanner(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: _primary, size: 26),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, color: _primary, fontSize: 14)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)));

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller:   controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: _accent),
        filled:     true,
        fillColor:  Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(loading ? 'Please wait...' : label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Colors.red, fontSize: 13))),
        GestureDetector(
          onTap: () => setState(() => _error = null),
          child: const Icon(Icons.close, color: Colors.red, size: 16),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8), letterSpacing: 0.5));

  Widget _detailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A))),
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );
}