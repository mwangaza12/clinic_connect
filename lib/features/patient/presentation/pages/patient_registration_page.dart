// lib/features/patient/presentation/pages/patient_registration_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/hie_api_service.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/patient_local_datasource.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/patient.dart';
import '../bloc/patient_bloc.dart';
import '../bloc/patient_event.dart';
import '../bloc/patient_state.dart';

class PatientRegistrationPage extends StatelessWidget {
  const PatientRegistrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<PatientBloc>(),
      child: const PatientRegistrationView(),
    );
  }
}

class PatientRegistrationView extends StatefulWidget {
  const PatientRegistrationView({super.key});

  @override
  State<PatientRegistrationView> createState() => _PatientRegistrationViewState();
}

class _PatientRegistrationViewState extends State<PatientRegistrationView> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final Color primaryDark = const Color(0xFF1B4332);
  final Color accentGreen = const Color(0xFF2D6A4F);

  // ── Security / HIE fields (Step 0) ────────────────────────────
  final _nationalIdController     = TextEditingController();
  final _securityAnswerController = TextEditingController();
  final _pinController            = TextEditingController();
  final _pinConfirmController     = TextEditingController();

  // ── Demographics (Step 1) ─────────────────────────────────────
  final _firstNameController  = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController   = TextEditingController();
  final _phoneController      = TextEditingController();
  final _emailController      = TextEditingController();
  String _gender = 'male';
  DateTime? _dateOfBirth;
  String? _bloodGroup;

  // ── Address / Next of kin (Step 2) ────────────────────────────
  final _countyController         = TextEditingController();
  final _subCountyController      = TextEditingController();
  final _wardController           = TextEditingController();
  final _villageController        = TextEditingController();
  final _nextOfKinNameController  = TextEditingController();
  final _nextOfKinPhoneController = TextEditingController();
  String? _nextOfKinRelationship;

  // ── State ─────────────────────────────────────────────────────
  bool _isSubmitting = false;

  static const _securityQuestions = [
    'What was the name of your first pet?',
    "What is your mother's maiden name?",
    'What city were you born in?',
    'What was the name of your primary school?',
    'What is the name of your oldest sibling?',
  ];
  String? _selectedSecurityQuestion;

  @override
  void dispose() {
    _nationalIdController.dispose();
    _securityAnswerController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
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
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────

  void _onNextStep() {
    if (_currentStep < 2) {
      if (!_validateCurrentStep()) return;
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _registerPatient();
    }
  }

  void _onPreviousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nationalIdController.text.trim().isEmpty) {
          _showSnack('National ID is required'); return false;
        }
        if (_selectedSecurityQuestion == null) {
          _showSnack('Please select a security question'); return false;
        }
        if (_securityAnswerController.text.trim().isEmpty) {
          _showSnack('Security answer is required'); return false;
        }
        if (_pinController.text.length < 4) {
          _showSnack('PIN must be at least 4 digits'); return false;
        }
        if (_pinController.text != _pinConfirmController.text) {
          _showSnack('PINs do not match'); return false;
        }
        return true;
      case 1:
        if (_firstNameController.text.trim().isEmpty ||
            _lastNameController.text.trim().isEmpty) {
          _showSnack('First and last name are required'); return false;
        }
        if (_dateOfBirth == null) {
          _showSnack('Date of birth is required'); return false;
        }
        if (_phoneController.text.trim().isEmpty) {
          _showSnack('Phone number is required'); return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showSnack(String msg, {Color color = Colors.orange}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── Registration ──────────────────────────────────────────────

  Future<void> _registerPatient() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      _showSnack('Authentication error', color: Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final facilityId = authState.user.facilityId;
      final dob = _dateOfBirth != null
          ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!)
          : '';

      final hieResult = await HieApiService.instance.registerPatient(
        nationalId:       _nationalIdController.text.trim(),
        firstName:        _firstNameController.text.trim(),
        lastName:         _lastNameController.text.trim(),
        middleName:       _middleNameController.text.trim().isEmpty
                              ? null
                              : _middleNameController.text.trim(),
        dateOfBirth:      dob,
        gender:           _gender,
        phoneNumber:      _phoneController.text.trim(),
        email:            _emailController.text.trim().isEmpty
                              ? null
                              : _emailController.text.trim(),
        address: {
          'county':    _countyController.text.trim(),
          'subCounty': _subCountyController.text.trim(),
          'ward':      _wardController.text.trim(),
          'village':   _villageController.text.trim(),
        },
        securityQuestion: _selectedSecurityQuestion!,
        securityAnswer:   _securityAnswerController.text.trim(),
        pin:              _pinController.text.trim(),
      );

      final nupi          = hieResult.nupi ?? _generateLocalNupi();
      final alreadyExists = hieResult.data?['alreadyExists'] == true;

      // ── Duplicate guard ───────────────────────────────────────────
      // Gateway says patient exists on AfyaNet.
      // Check SQLite (fast, offline) to see if already at THIS facility.
      if (alreadyExists) {
        final localDs  = sl<PatientLocalDatasource>();
        final existing = await localDs.getPatientByNupi(nupi);

        if (existing != null && mounted) {
          _showSnack(
            'This patient is already registered here (NUPI: $nupi)',
            color: Colors.orange,
          );
          Navigator.of(context).pop();
          return; // ← stops here, no new record created
        }

        // On AfyaNet but new to this facility — fall through to save locally
        if (mounted) {
          _showSnack(
            'Patient already on AfyaNet — linked to this facility',
            color: const Color(0xFF1B4332),
          );
        }
      } else if (hieResult.success && hieResult.blockIndex != null && mounted) {
        _showSnack(
          '⛓ Block #${hieResult.blockIndex} minted — patient on AfyaChain',
          color: const Color(0xFF1B4332),
        );
      } else if (!hieResult.success && mounted) {
        _showSnack(
          'Saved locally. Blockchain sync pending: ${hieResult.error}',
          color: Colors.orange,
        );
      }

      // Save locally — using NUPI as dedup key so ConflictAlgorithm.replace
      // in SQLite and Firestore .set() are both idempotent
      final patient = Patient(
        id:           const Uuid().v4(),
        nupi:         nupi,
        firstName:    _firstNameController.text.trim(),
        middleName:   _middleNameController.text.trim(),
        lastName:     _lastNameController.text.trim(),
        gender:       _gender,
        dateOfBirth:  _dateOfBirth!,
        phoneNumber:  _phoneController.text.trim(),
        email:        _emailController.text.trim().isEmpty
                          ? null
                          : _emailController.text.trim(),
        county:       _countyController.text.trim(),
        subCounty:    _subCountyController.text.trim(),
        ward:         _wardController.text.trim(),
        village:      _villageController.text.trim(),
        bloodGroup:   _bloodGroup,
        facilityId:   facilityId,
        allergies:    const [],
        chronicConditions: const [],
        nextOfKinName: _nextOfKinNameController.text.trim().isEmpty
                           ? null
                           : _nextOfKinNameController.text.trim(),
        nextOfKinPhone: _nextOfKinPhoneController.text.trim().isEmpty
                            ? null
                            : _nextOfKinPhoneController.text.trim(),
        nextOfKinRelationship: _nextOfKinRelationship,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (mounted) {
        context.read<PatientBloc>().add(RegisterPatientEvent(patient));
      }

    } catch (e) {
      // BUG FIX: old code showed a red error snackbar and stopped — the patient
      // was never saved and Navigator.pop was never called.
      // Correct offline behaviour: if the HIE/network call fails (DioException,
      // SocketException, etc.), generate a local NUPI, save to SQLite, and let
      // the BlocConsumer listener handle navigation as normal.
      debugPrint('[HIE] Registration error (going offline): $e');

      final isNetworkError = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('dio') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('host');

      if (isNetworkError && mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is! Authenticated) return;

        // BUG FIX: old code generated KE-YYYY-XXXXXX which looks like a real
        // NUPI. Only the HIE gateway should issue real NUPIs.
        // Use PENDING- prefix so it is unambiguous, and SyncManager's
        // _replaceLocalNupi() will overwrite it with the real NUPI on sync.
        final shortId = const Uuid().v4().substring(0, 8).toUpperCase();
        final nupi = 'PENDING-$shortId';
        _showSnack(
          '📴 Offline — saved locally. NUPI will be assigned when back online.',
          color: const Color(0xFF1B4332),
        );

        final patient = Patient(
          id:           const Uuid().v4(),
          nupi:         nupi,
          firstName:    _firstNameController.text.trim(),
          middleName:   _middleNameController.text.trim(),
          lastName:     _lastNameController.text.trim(),
          gender:       _gender,
          dateOfBirth:  _dateOfBirth!,
          phoneNumber:  _phoneController.text.trim(),
          email:        _emailController.text.trim().isEmpty
                            ? null
                            : _emailController.text.trim(),
          county:       _countyController.text.trim(),
          subCounty:    _subCountyController.text.trim(),
          ward:         _wardController.text.trim(),
          village:      _villageController.text.trim(),
          bloodGroup:   _bloodGroup,
          facilityId:   authState.user.facilityId,
          allergies:    const [],
          chronicConditions: const [],
          nextOfKinName: _nextOfKinNameController.text.trim().isEmpty
                             ? null
                             : _nextOfKinNameController.text.trim(),
          nextOfKinPhone: _nextOfKinPhoneController.text.trim().isEmpty
                              ? null
                              : _nextOfKinPhoneController.text.trim(),
          nextOfKinRelationship: _nextOfKinRelationship,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (mounted) {
          context.read<PatientBloc>().add(RegisterPatientEvent(patient));
          // BlocConsumer listener will call Navigator.pop when PatientRegistered
          // is emitted — no manual navigation needed here.
        }
      } else if (mounted) {
        _showSnack(
          'Registration error: ${e.toString().split('\n').first}',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _generateLocalNupi() {
    final year = DateTime.now().year;
    final rand = (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
    return 'KE-$year-$rand';
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _onPreviousStep,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Patient',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
            Text(
              ['Identity & Security', 'Demographics', 'Address & Next of Kin'][_currentStep],
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_currentStep + 1}/3',
                  style: TextStyle(color: primaryDark,
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: BlocConsumer<PatientBloc, PatientState>(
        listener: (context, state) {
          if (state is PatientRegistered) {
            _showSnack('Patient registered successfully ✓', color: Colors.green);
            Navigator.pop(context);
          } else if (state is PatientError) {
            _showSnack(state.message, color: Colors.red);
          }
        },
        builder: (context, state) {
          final isLoading = state is PatientLoading || _isSubmitting;
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
                      _buildStep0Security(),
                      _buildStep1Demographics(),
                      _buildStep2Address(),
                    ],
                  ),
                ),
                _buildBottomBar(isLoading),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
      child: Row(
        children: [
          _stepDot(0, 'Identity'),
          _stepLine(0),
          _stepDot(1, 'Info'),
          _stepLine(1),
          _stepDot(2, 'Address'),
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

  // ── Step 0: Identity & Security ───────────────────────────────

  Widget _buildStep0Security() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.badge_outlined, 'National ID',
              'Required to generate the patient\'s NUPI on AfyaChain'),
          const SizedBox(height: 16),
          _field(
            controller: _nationalIdController,
            label: 'National ID / Passport Number',
            hint: 'e.g. 12345678',
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          _sectionHeader(Icons.lock_outline, 'Security',
              'Used to verify the patient\'s identity at any facility'),
          const SizedBox(height: 16),
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
                hint: Text('Select security question',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                value: _selectedSecurityQuestion,
                items: _securityQuestions
                    .map((q) => DropdownMenuItem(value: q, child: Text(q,
                        style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSecurityQuestion = v),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _securityAnswerController,
            label: 'Security Answer',
            hint: 'Your answer',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _pinController,
            label: '4-digit PIN',
            hint: '••••',
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (v) {
              if (v == null || v.trim().length < 4) return 'Minimum 4 digits';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: _pinConfirmController,
            label: 'Confirm PIN',
            hint: '••••',
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (v) {
              if (v != _pinController.text) return 'PINs do not match';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDEF7EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2D6A4F), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The NUPI will be automatically generated by the AfyaLink gateway using the National ID and date of birth.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0F5132), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Demographics ──────────────────────────────────────

  Widget _buildStep1Demographics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.person_outline, 'Personal Information', null),
          const SizedBox(height: 16),
          _field(controller: _firstNameController, label: 'First Name',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          _field(controller: _middleNameController, label: 'Middle Name (optional)'),
          const SizedBox(height: 12),
          _field(controller: _lastNameController, label: 'Last Name',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _genderCard('male',   Icons.male,   'Male')),
            const SizedBox(width: 12),
            Expanded(child: _genderCard('female', Icons.female, 'Female')),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                Icon(Icons.cake_outlined, color: accentGreen, size: 20),
                const SizedBox(width: 12),
                Text(
                  _dateOfBirth == null
                      ? 'Select Date of Birth'
                      : DateFormat('dd MMM yyyy').format(_dateOfBirth!),
                  style: TextStyle(
                      color: _dateOfBirth == null ? Colors.grey[400] : const Color(0xFF0F172A),
                      fontSize: 14),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _field(controller: _phoneController, label: 'Phone Number',
              hint: '+254XXXXXXXXX',
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          _field(controller: _emailController, label: 'Email (optional)',
              keyboardType: TextInputType.emailAddress),
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
                hint: Text('Blood Group (optional)',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                value: _bloodGroup,
                items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodGroup = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Address & Next of Kin ─────────────────────────────

  Widget _buildStep2Address() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.location_on_outlined, 'Address', null),
          const SizedBox(height: 16),
          _field(controller: _countyController, label: 'County'),
          const SizedBox(height: 12),
          _field(controller: _subCountyController, label: 'Sub-County'),
          const SizedBox(height: 12),
          _field(controller: _wardController, label: 'Ward'),
          const SizedBox(height: 12),
          _field(controller: _villageController, label: 'Village / Estate'),
          const SizedBox(height: 24),
          _sectionHeader(Icons.people_outline, 'Next of Kin', 'Optional'),
          const SizedBox(height: 16),
          _field(controller: _nextOfKinNameController, label: 'Next of Kin Name'),
          const SizedBox(height: 12),
          _field(controller: _nextOfKinPhoneController, label: 'Next of Kin Phone',
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
                items: ['Spouse', 'Parent', 'Child', 'Sibling', 'Friend', 'Other']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _nextOfKinRelationship = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ─────────────────────────────────────

  Widget _buildBottomBar(bool isLoading) {
    final isLast = _currentStep == 2;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : _onPreviousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: primaryDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back', style: TextStyle(color: primaryDark, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isLoading ? null : _onNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isLast ? 'Register Patient' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Widget _genderCard(String value, IconData icon, String label) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primaryDark.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? primaryDark : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? primaryDark : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: selected ? primaryDark : Colors.grey[600],
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String? subtitle) {
    return Row(children: [
      Icon(icon, color: accentGreen, size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: primaryDark)),
        if (subtitle != null)
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ]),
    ]);
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
      controller:   controller,
      obscureText:  obscureText,
      keyboardType: keyboardType,
      maxLength:    maxLength,
      validator:    validator,
      decoration: InputDecoration(
        labelText: label,
        hintText:  hint,
        filled:    true,
        fillColor: Colors.white,
        counterText: '',
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentGreen, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}