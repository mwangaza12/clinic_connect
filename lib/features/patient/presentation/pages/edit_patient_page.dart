import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/patient.dart';
import '../bloc/patient_bloc.dart';
import '../bloc/patient_event.dart';
import '../bloc/patient_state.dart';

class EditPatientPage extends StatelessWidget {
  final Patient patient;
  const EditPatientPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PatientBloc>(),
      child: _EditPatientView(patient: patient),
    );
  }
}

class _EditPatientView extends StatefulWidget {
  final Patient patient;
  const _EditPatientView({required this.patient});

  @override
  State<_EditPatientView> createState() => _EditPatientViewState();
}

class _EditPatientViewState extends State<_EditPatientView> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentStep = 0;

  static const Color primaryDark  = Color(0xFF1B4332);
  static const Color accentGreen  = Color(0xFF2D6A4F);

  // ── Demographics ──────────────────────────────────────────────
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late String  _gender;
  late DateTime? _dateOfBirth;
  late String? _bloodGroup;

  // ── Address ───────────────────────────────────────────────────
  late final TextEditingController _countyController;
  late final TextEditingController _subCountyController;
  late final TextEditingController _wardController;
  late final TextEditingController _villageController;

  // ── Next of Kin ───────────────────────────────────────────────
  late final TextEditingController _nextOfKinNameController;
  late final TextEditingController _nextOfKinPhoneController;
  late String? _nextOfKinRelationship;

  // ── Clinical ──────────────────────────────────────────────────
  late List<String> _allergies;
  late List<String> _chronicConditions;
  final TextEditingController _allergyInput    = TextEditingController();
  final TextEditingController _conditionInput  = TextEditingController();

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _relationships = [
    'Spouse', 'Parent', 'Child', 'Sibling', 'Guardian', 'Friend', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _firstNameController   = TextEditingController(text: p.firstName);
    _middleNameController  = TextEditingController(text: p.middleName);
    _lastNameController    = TextEditingController(text: p.lastName);
    _phoneController       = TextEditingController(text: p.phoneNumber);
    _emailController       = TextEditingController(text: p.email ?? '');
    _gender                = p.gender;
    _dateOfBirth           = p.dateOfBirth;
    _bloodGroup            = p.bloodGroup;
    _countyController      = TextEditingController(text: p.county);
    _subCountyController   = TextEditingController(text: p.subCounty);
    _wardController        = TextEditingController(text: p.ward);
    _villageController     = TextEditingController(text: p.village);
    _nextOfKinNameController  = TextEditingController(text: p.nextOfKinName  ?? '');
    _nextOfKinPhoneController = TextEditingController(text: p.nextOfKinPhone ?? '');
    _nextOfKinRelationship    = p.nextOfKinRelationship;
    _allergies         = List<String>.from(p.allergies);
    _chronicConditions = List<String>.from(p.chronicConditions);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _countyController.dispose();
    _subCountyController.dispose();
    _wardController.dispose();
    _villageController.dispose();
    _nextOfKinNameController.dispose();
    _nextOfKinPhoneController.dispose();
    _allergyInput.dispose();
    _conditionInput.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_firstNameController.text.trim().isEmpty) {
          _snack('First name is required'); return false;
        }
        if (_lastNameController.text.trim().isEmpty) {
          _snack('Last name is required'); return false;
        }
        if (_dateOfBirth == null) {
          _snack('Date of birth is required'); return false;
        }
        if (_phoneController.text.trim().isEmpty) {
          _snack('Phone number is required'); return false;
        }
        return true;
      case 1:
        if (_countyController.text.trim().isEmpty) {
          _snack('County is required'); return false;
        }
        if (_subCountyController.text.trim().isEmpty) {
          _snack('Sub-county is required'); return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _snack(String msg, {Color color = Colors.orange}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── Submit ────────────────────────────────────────────────────

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.patient.copyWith(
      firstName:    _firstNameController.text.trim(),
      middleName:   _middleNameController.text.trim(),
      lastName:     _lastNameController.text.trim(),
      gender:       _gender,
      dateOfBirth:  _dateOfBirth,
      phoneNumber:  _phoneController.text.trim(),
      email:        _emailController.text.trim().isEmpty
                        ? null
                        : _emailController.text.trim(),
      county:       _countyController.text.trim(),
      subCounty:    _subCountyController.text.trim(),
      ward:         _wardController.text.trim(),
      village:      _villageController.text.trim(),
      bloodGroup:   _bloodGroup,
      allergies:    List<String>.from(_allergies),
      chronicConditions: List<String>.from(_chronicConditions),
      nextOfKinName: _nextOfKinNameController.text.trim().isEmpty
                         ? null
                         : _nextOfKinNameController.text.trim(),
      nextOfKinPhone: _nextOfKinPhoneController.text.trim().isEmpty
                          ? null
                          : _nextOfKinPhoneController.text.trim(),
      nextOfKinRelationship: _nextOfKinRelationship,
      updatedAt: DateTime.now(),
    );

    context.read<PatientBloc>().add(UpdatePatientEvent(updated));
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: primaryDark),
          onPressed: _prevStep,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Patient',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
            Text(
              ['Demographics', 'Address & Next of Kin', 'Clinical'][_currentStep],
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_currentStep + 1}/3',
                  style: const TextStyle(
                      color: primaryDark, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: BlocConsumer<PatientBloc, PatientState>(
        listener: (context, state) {
          if (state is PatientUpdated) {
            _snack('Patient updated successfully ✓', color: Colors.green);
            // Return the updated patient to the caller
            Navigator.pop(context, state.patient);
          } else if (state is PatientError) {
            _snack(state.message, color: Colors.red);
          }
        },
        builder: (context, state) {
          final loading = state is PatientLoading;
          return Form(
            key: _formKey,
            child: Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep0Demographics(),
                      _buildStep1Address(),
                      _buildStep2Clinical(),
                    ],
                  ),
                ),
                _buildBottomBar(loading),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Step indicator ─────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
      child: Row(
        children: [
          _stepDot(0, 'Info'),
          _stepLine(0),
          _stepDot(1, 'Address'),
          _stepLine(1),
          _stepDot(2, 'Clinical'),
        ],
      ),
    );
  }

  Widget _stepDot(int index, String label) {
    final done   = _currentStep > index;
    final active = _currentStep == index;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: done || active ? primaryDark : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Center(child: done
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text('${index + 1}',
                style: TextStyle(
                    color: active ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold, fontSize: 13))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
          fontSize: 10,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? primaryDark : Colors.grey)),
    ]);
  }

  Widget _stepLine(int index) => Expanded(child: Container(
    height: 2,
    margin: const EdgeInsets.only(bottom: 14),
    color: _currentStep > index ? primaryDark : Colors.grey[200],
  ));

  // ── Step 0: Demographics ──────────────────────────────────────

  Widget _buildStep0Demographics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.person_outline, 'Personal Information',
              'Update the patient\'s basic details'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _field(
                controller: _firstNameController, label: 'First Name',
                validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(child: _field(
                controller: _middleNameController, label: 'Middle Name')),
          ]),
          const SizedBox(height: 12),
          _field(controller: _lastNameController, label: 'Last Name',
              validator: (v) => v!.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          _field(controller: _phoneController, label: 'Phone Number',
              keyboardType: TextInputType.phone,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          _field(controller: _emailController, label: 'Email (optional)',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),

          // Gender
          _sectionHeader(Icons.wc_outlined, 'Gender', null),
          const SizedBox(height: 10),
          Row(children: ['male', 'female', 'other'].map((g) {
            final selected = _gender == g;
            return Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _gender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? primaryDark : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text(
                      g[0].toUpperCase() + g.substring(1),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),

          // Date of Birth
          _sectionHeader(Icons.cake_outlined, 'Date of Birth', null),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(1990),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: primaryDark),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dateOfBirth = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: primaryDark, size: 18),
                const SizedBox(width: 12),
                Text(
                  _dateOfBirth != null
                      ? DateFormat('dd MMMM yyyy').format(_dateOfBirth!)
                      : 'Tap to select',
                  style: TextStyle(
                      fontSize: 14,
                      color: _dateOfBirth != null
                          ? const Color(0xFF0F172A)
                          : Colors.grey),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Blood group
          _sectionHeader(Icons.bloodtype_outlined, 'Blood Group (optional)', null),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _bloodGroups.map((bg) {
              final sel = _bloodGroup == bg;
              return GestureDetector(
                onTap: () => setState(
                    () => _bloodGroup = sel ? null : bg),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel
                            ? primaryDark
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(bg,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : const Color(0xFF64748B))),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Address & Next of Kin ─────────────────────────────

  Widget _buildStep1Address() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.location_on_outlined, 'Residential Address',
              'Current place of residence'),
          const SizedBox(height: 16),
          _field(controller: _countyController, label: 'County',
              validator: (v) => v!.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          _field(controller: _subCountyController, label: 'Sub-County',
              validator: (v) => v!.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(
                controller: _wardController, label: 'Ward')),
            const SizedBox(width: 12),
            Expanded(child: _field(
                controller: _villageController, label: 'Village')),
          ]),
          const SizedBox(height: 24),
          _sectionHeader(Icons.contacts_outlined, 'Next of Kin (optional)',
              'Emergency contact'),
          const SizedBox(height: 16),
          _field(controller: _nextOfKinNameController, label: 'Full Name'),
          const SizedBox(height: 12),
          _field(controller: _nextOfKinPhoneController, label: 'Phone',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text('Relationship',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                value: _nextOfKinRelationship,
                items: _relationships.map((r) =>
                    DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) =>
                    setState(() => _nextOfKinRelationship = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Clinical ──────────────────────────────────────────

  Widget _buildStep2Clinical() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.health_and_safety_outlined, 'Allergies',
              'Known allergies — tap + to add'),
          const SizedBox(height: 12),
          _tagInput(
            controller: _allergyInput,
            tags: _allergies,
            hint: 'e.g. Penicillin',
            tagColor: const Color(0xFFE11D48),
            onAdd: () {
              final v = _allergyInput.text.trim();
              if (v.isNotEmpty && !_allergies.contains(v)) {
                setState(() { _allergies.add(v); _allergyInput.clear(); });
              }
            },
            onRemove: (i) => setState(() => _allergies.removeAt(i)),
          ),
          const SizedBox(height: 24),
          _sectionHeader(Icons.monitor_heart_outlined, 'Chronic Conditions',
              'Long-term medical conditions'),
          const SizedBox(height: 12),
          _tagInput(
            controller: _conditionInput,
            tags: _chronicConditions,
            hint: 'e.g. Hypertension',
            tagColor: const Color(0xFF6366F1),
            onAdd: () {
              final v = _conditionInput.text.trim();
              if (v.isNotEmpty && !_chronicConditions.contains(v)) {
                setState(() {
                  _chronicConditions.add(v);
                  _conditionInput.clear();
                });
              }
            },
            onRemove: (i) => setState(() => _chronicConditions.removeAt(i)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _buildBottomBar(bool loading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      color: Colors.white,
      child: Row(children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: loading ? null : _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: primaryDark),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back',
                  style: TextStyle(color: primaryDark,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: loading ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
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
                : Text(_currentStep < 2 ? 'Next' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String? subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryDark, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagInput({
    required TextEditingController controller,
    required List<String> tags,
    required String hint,
    required Color tagColor,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onFieldSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tagColor.withOpacity(0.3)),
              ),
              child: Icon(Icons.add_rounded, color: tagColor, size: 20),
            ),
          ),
        ]),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: tags.asMap().entries.map((e) => Chip(
              label: Text(e.value,
                  style: TextStyle(
                      color: tagColor, fontWeight: FontWeight.w600,
                      fontSize: 12)),
              backgroundColor: tagColor.withOpacity(0.08),
              deleteIconColor: tagColor,
              side: BorderSide(color: tagColor.withOpacity(0.2)),
              onDeleted: () => onRemove(e.key),
            )).toList(),
          ),
        ],
      ],
    );
  }
}