import 'dart:io'; // SocketException, HandshakeException
import 'package:dio/dio.dart'; // DioException, DioExceptionType
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../../../../core/services/backend_api_service.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/patient_local_datasource.dart';
import '../../data/models/patient_model.dart';
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

  // ── Kenya Areas API ───────────────────────────────────────────
  static const _areasApiKey = 'keyPub1569gsvndc123kg9sjhg';
  static const _areasApiUrl = 'https://kenyaareadata.vercel.app/api/areas';

  Map<String, dynamic> _areasData = {};
  bool _areasLoading = false;
  bool _areasLoadFailed = false;

  // Cascading selection
  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedWard;

  // Derived lists from the API response
  List<String> get _counties {
    final keys = _areasData.keys.toList();
    keys.sort();
    return keys;
  }

  List<String> get _subCounties {
    if (_selectedCounty == null) return [];
    final county = _areasData[_selectedCounty];
    if (county is! Map) return [];
    final keys = (county as Map<String, dynamic>).keys.toList();
    keys.sort();
    return keys;
  }

  // FIXED: Wards are a List, not a Map
  List<String> get _wards {
    if (_selectedCounty == null || _selectedSubCounty == null) return [];
    final sub = (_areasData[_selectedCounty] as Map<String, dynamic>?)?[_selectedSubCounty];
    
    // The API returns wards as a List of strings, not a Map
    if (sub is List) {
      final list = List<String>.from(sub);
      list.sort();
      return list;
    }
    return [];
  }

  // REMOVED: Villages getter - API doesn't provide villages

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

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchAreas();
  }

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

  // ── Kenya Areas API fetch ─────────────────────────────────────

  Future<void> _fetchAreas() async {
    if (!mounted) return;
    setState(() {
      _areasLoading    = true;
      _areasLoadFailed = false;
    });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await dio.get(
        _areasApiUrl,
        queryParameters: {'apiKey': _areasApiKey},
      );

      final raw = response.data;
      final Map<String, dynamic> parsed;

      if (raw is Map<String, dynamic>) {
        if (raw.containsKey('counties') && raw['counties'] is Map) {
          parsed = Map<String, dynamic>.from(raw['counties'] as Map);
        } else if (raw.containsKey('data') && raw['data'] is Map) {
          parsed = Map<String, dynamic>.from(raw['data'] as Map);
        } else if (raw.containsKey('areas') && raw['areas'] is Map) {
          parsed = Map<String, dynamic>.from(raw['areas'] as Map);
        } else {
          parsed = raw;
        }
      } else {
        parsed = {};
      }

      debugPrint('[AreasAPI] ✓ ${parsed.keys.length} counties loaded');

      if (mounted) {
        setState(() {
          _areasData    = parsed;
          _areasLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint('[AreasAPI] ✗ ${e.type} — ${e.response?.statusCode} — ${e.response?.data}');
      if (mounted) {
        setState(() {
          _areasLoading    = false;
          _areasLoadFailed = true;
        });
      }
    } catch (e) {
      debugPrint('[AreasAPI] ✗ $e');
      if (mounted) {
        setState(() {
          _areasLoading    = false;
          _areasLoadFailed = true;
        });
      }
    }
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

  // ── Offline detection ─────────────────────────────────────────

  bool _isOfflineError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return true;
        default:
          break;
      }
      final inner = e.error;
      if (inner is SocketException)    return true;
      if (inner is HandshakeException) return true;
    }
    if (e is SocketException)    return true;
    if (e is HandshakeException) return true;
    if (e is StateError) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('failed host lookup')    ||
           msg.contains('no address associated') ||
           msg.contains('connection refused')    ||
           msg.contains('connection timed out')  ||
           msg.contains('network is unreachable');
  }

  // ── Shared Patient builder ────────────────────────────────────

  Patient _buildPatient({
    required String nupi,
    required String facilityId,
  }) {
    return Patient(
      id:           const Uuid().v4(),
      nupi:         nupi,
      firstName:    _firstNameController.text.trim(),
      middleName:   _middleNameController.text.trim(),
      lastName:     _lastNameController.text.trim(),
      gender:       _gender,
      dateOfBirth:  _dateOfBirth!,
      phoneNumber:  _phoneController.text.trim(),
      email:        _emailController.text.trim().isEmpty
                        ? null : _emailController.text.trim(),
      county:       _countyController.text.trim(),
      subCounty:    _subCountyController.text.trim(),
      ward:         _wardController.text.trim(),
      village:      _villageController.text.trim(),
      bloodGroup:   _bloodGroup,
      facilityId:   facilityId,
      allergies:    const [],
      chronicConditions: const [],
      nextOfKinName: _nextOfKinNameController.text.trim().isEmpty
                         ? null : _nextOfKinNameController.text.trim(),
      nextOfKinPhone: _nextOfKinPhoneController.text.trim().isEmpty
                          ? null : _nextOfKinPhoneController.text.trim(),
      nextOfKinRelationship: _nextOfKinRelationship,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ── Offline save + dual sync enqueue ─────────────────────────

  Future<void> _savePatientOffline({
    required String facilityId,
    required String dob,
  }) async {
    if (_dateOfBirth == null) {
      if (mounted) _showSnack('Date of birth is missing', color: Colors.red);
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    final shortId     = const Uuid().v4().substring(0, 8).toUpperCase();
    final pendingNupi = 'PENDING-$shortId';
    final patient     = _buildPatient(nupi: pendingNupi, facilityId: facilityId);

    try {
      final localDs = sl<PatientLocalDatasource>();
      await localDs.savePatient(PatientModel.fromEntity(patient));
      debugPrint('[Registration] Saved offline → SQLite  NUPI: $pendingNupi');
    } catch (saveErr) {
      debugPrint('[Registration] SQLite save error: $saveErr');
      if (mounted) {
        _showSnack('Could not save locally: $saveErr', color: Colors.red);
        setState(() => _isSubmitting = false);
      }
      return;
    }

    final hiePayload = {
      'localNupi':        pendingNupi,
      'nationalId':       _nationalIdController.text.trim(),
      'firstName':        _firstNameController.text.trim(),
      'lastName':         _lastNameController.text.trim(),
      'middleName':       _middleNameController.text.trim().isEmpty
                              ? null : _middleNameController.text.trim(),
      'dateOfBirth':      dob,
      'gender':           _gender,
      'phoneNumber':      _phoneController.text.trim(),
      'email':            _emailController.text.trim().isEmpty
                              ? null : _emailController.text.trim(),
      'securityQuestion': _selectedSecurityQuestion,
      'securityAnswer':   _securityAnswerController.text.trim(),
      'pin':              _pinController.text.trim(),
      'address': {
        'county':    _countyController.text.trim(),
        'subCounty': _subCountyController.text.trim(),
        'ward':      _wardController.text.trim(),
        'village':   _villageController.text.trim(),
      },
    };

    await SyncManager().enqueue(
      entityType: SyncEntityType.patient,
      entityId:   patient.id,
      operation:  SyncOperation.create,
      payload:    PatientModel.fromEntity(patient).toJson(),
    );

    await SyncManager().enqueue(
      entityType: SyncEntityType.hiePatient,
      entityId:   'hie_${patient.id}',
      operation:  SyncOperation.create,
      payload:    hiePayload,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      _showSnack(
        '📴 Saved offline — will sync to AfyaNet when back online.',
        color: const Color(0xFF1B4332),
      );
      Navigator.of(context).pop();
    }
  }

  // ── Registration ──────────────────────────────────────────────

  Future<void> _registerPatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) { _showSnack('Date of birth is required'); return; }

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      _showSnack('Authentication error', color: Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    final facilityId = authState.user.facilityId;
    final dob = DateFormat('yyyy-MM-dd').format(_dateOfBirth!);

    BackendApiService? backend;
    try {
      backend = await BackendApiService.instanceAsync;
    } catch (initErr) {
      debugPrint('[Registration] BackendApiService init failed: $initErr');
      await _savePatientOffline(facilityId: facilityId, dob: dob);
      return;
    }

    try {
      final hieResult = await backend.registerPatient(
        nationalId:       _nationalIdController.text.trim(),
        firstName:        _firstNameController.text.trim(),
        lastName:         _lastNameController.text.trim(),
        middleName:       _middleNameController.text.trim().isEmpty
                              ? null : _middleNameController.text.trim(),
        dateOfBirth:      dob,
        gender:           _gender,
        phoneNumber:      _phoneController.text.trim(),
        email:            _emailController.text.trim().isEmpty
                              ? null : _emailController.text.trim(),
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

      final shortId       = const Uuid().v4().substring(0, 8).toUpperCase();
      final nupi          = hieResult.nupi ??
          (hieResult.success ? _generateLocalNupi() : 'PENDING-$shortId');
      final alreadyExists = hieResult.data?['alreadyExists'] == true;
      final blockIndex    = hieResult.data?['blockIndex'];

      if (alreadyExists) {
        final localDs  = sl<PatientLocalDatasource>();
        final existing = await localDs.getPatientByNupi(nupi);

        if (existing != null && mounted) {
          _showSnack(
            'Patient already registered here (NUPI: $nupi)',
            color: Colors.orange,
          );
          Navigator.of(context).pop();
          return;
        }

        if (mounted) {
          _showSnack(
            'Patient already on AfyaNet — linked to this facility',
            color: const Color(0xFF1B4332),
          );
        }
      } else if (hieResult.success && mounted) {
        _showSnack(
          blockIndex != null
              ? '⛓ Block #$blockIndex minted — patient on AfyaChain'
              : '✓ Patient registered on AfyaNet',
          color: const Color(0xFF1B4332),
        );
      } else if (!hieResult.success) {
        debugPrint('[Registration] Backend error: ${hieResult.error}');
        if (mounted) {
          _showSnack(
            'Registration failed: ${hieResult.error ?? "Unknown error"}',
            color: Colors.red,
          );
        }
        return;
      }

      final patient = _buildPatient(nupi: nupi, facilityId: facilityId);
      if (mounted) {
        context.read<PatientBloc>().add(RegisterPatientEvent(patient));
      }

      if (!hieResult.success || hieResult.nupi == null) {
        await SyncManager().enqueue(
          entityType: SyncEntityType.hiePatient,
          entityId:   'hie_${patient.id}',
          operation:  SyncOperation.create,
          payload: {
            'localNupi':        nupi,
            'nationalId':       _nationalIdController.text.trim(),
            'firstName':        _firstNameController.text.trim(),
            'lastName':         _lastNameController.text.trim(),
            'middleName':       _middleNameController.text.trim().isEmpty
                                    ? null : _middleNameController.text.trim(),
            'dateOfBirth':      dob,
            'gender':           _gender,
            'phoneNumber':      _phoneController.text.trim(),
            'email':            _emailController.text.trim().isEmpty
                                    ? null : _emailController.text.trim(),
            'securityQuestion': _selectedSecurityQuestion,
            'securityAnswer':   _securityAnswerController.text.trim(),
            'pin':              _pinController.text.trim(),
            'address': {
              'county':    _countyController.text.trim(),
              'subCounty': _subCountyController.text.trim(),
              'ward':      _wardController.text.trim(),
              'village':   _villageController.text.trim(),
            },
          },
        );
      }

    } catch (e) {
      debugPrint('[Registration] catch: $e');

      if (_isOfflineError(e)) {
        await _savePatientOffline(facilityId: facilityId, dob: dob);
        return;
      }

      if (mounted) {
        _showSnack(
          'Registration error: ${e.toString().split('\n').first}',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
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
                      color: _dateOfBirth == null
                          ? Colors.grey[400] : const Color(0xFF0F172A),
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

          if (_areasLoading)
            _buildAreasLoadingIndicator()

          else if (_areasLoadFailed) ...[
            _buildAreasFailedBanner(),
            const SizedBox(height: 12),
            _field(controller: _countyController,    label: 'County'),
            const SizedBox(height: 12),
            _field(controller: _subCountyController, label: 'Sub-County'),
            const SizedBox(height: 12),
            _field(controller: _wardController,      label: 'Ward'),
            const SizedBox(height: 12),
            _field(controller: _villageController,   label: 'Village / Estate'),
          ]

          else ...[
            _areaDropdown(
              label: 'County',
              icon: Icons.map_outlined,
              value: _selectedCounty,
              items: _counties,
              onChanged: (v) => setState(() {
                _selectedCounty    = v;
                _selectedSubCounty = null;
                _selectedWard      = null;
                _countyController.text    = v ?? '';
                _subCountyController.text = '';
                _wardController.text      = '';
                _villageController.text   = '';
              }),
            ),
            const SizedBox(height: 12),

            _areaDropdown(
              label: 'Sub-County',
              icon: Icons.account_tree_outlined,
              value: _selectedSubCounty,
              items: _subCounties,
              enabled: _selectedCounty != null,
              disabledHint: 'Select a county first',
              onChanged: (v) => setState(() {
                _selectedSubCounty = v;
                _selectedWard      = null;
                _subCountyController.text = v ?? '';
                _wardController.text      = '';
                _villageController.text   = '';
              }),
            ),
            const SizedBox(height: 12),

            _areaDropdown(
              label: 'Ward',
              icon: Icons.holiday_village_outlined,
              value: _selectedWard,
              items: _wards,
              enabled: _selectedSubCounty != null,
              disabledHint: 'Select a sub-county first',
              onChanged: (v) => setState(() {
                _selectedWard = v;
                _wardController.text = v ?? '';
              }),
            ),
            const SizedBox(height: 12),

            // CHANGED: Village is now a text field, not a dropdown
            _field(
              controller: _villageController,
              label: 'Village / Estate',
              hint: 'Enter village or estate name',
            ),
          ],

          const SizedBox(height: 24),
          _sectionHeader(Icons.people_outline, 'Next of Kin', 'Optional'),
          const SizedBox(height: 16),
          _field(controller: _nextOfKinNameController,  label: 'Next of Kin Name'),
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

  // ── Areas API UI helpers ──────────────────────────────────────

  Widget _buildAreasLoadingIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: accentGreen),
          ),
          const SizedBox(width: 10),
          Text('Loading Kenya county data…',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 12),
        for (int i = 0; i < 4; i++) ...[
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (i < 3) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildAreasFailedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE083)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Could not load county data. Please type your address manually.',
              style: TextStyle(fontSize: 12, color: Color(0xFF856404), height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _fetchAreas,
            child: Text('Retry',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentGreen)),
          ),
        ],
      ),
    );
  }

  Widget _areaDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool enabled = true,
    String? disabledHint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? const Color(0xFFE2E8F0) : const Color(0xFFEEF2F7),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: enabled ? accentGreen : Colors.grey[300]),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                hint: Text(label,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                disabledHint: Text(disabledHint ?? label,
                    style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          if (enabled && value == null && items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDEF7EC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${items.length}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentGreen)),
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
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : _onPreviousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: primaryDark),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back',
                  style: TextStyle(
                      color: primaryDark, fontWeight: FontWeight.w600)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isLast ? 'Register Patient' : 'Next',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
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
        Text(title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: primaryDark)),
        if (subtitle != null)
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentGreen, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}