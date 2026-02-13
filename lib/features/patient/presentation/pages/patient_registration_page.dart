import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../injection_container.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
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

  // Theme Colors
  final Color primaryDark = const Color(0xFF1B4332);
  final Color accentGreen = const Color(0xFF2D6A4F);

  // Controllers
  final _nupiController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _countyController = TextEditingController();
  final _subCountyController = TextEditingController();
  final _wardController = TextEditingController();
  final _villageController = TextEditingController();
  final _nextOfKinNameController = TextEditingController();
  final _nextOfKinPhoneController = TextEditingController();

  String _gender = 'male';
  DateTime? _dateOfBirth;
  String? _bloodGroup;
  String? _nextOfKinRelationship;

  @override
  void dispose() {
    _nupiController.dispose();
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

  void _onNextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    } else {
      _registerPatient();
    }
  }

  void _onPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _registerPatient() {
    if (_formKey.currentState!.validate()) {
      if (_dateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select date of birth'), backgroundColor: Colors.orange),
        );
        return;
      }
     // Get facility ID from auth state using context
      String facilityId;
      try {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated) {
          facilityId = authState.user.facilityId;
        } else {
          throw Exception('User not authenticated');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: $e'), 
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final patient = Patient(
        id: const Uuid().v4(),
        nupi: _nupiController.text.trim(),
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _gender,
        dateOfBirth: _dateOfBirth!,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        county: _countyController.text.trim(),
        subCounty: _subCountyController.text.trim(),
        ward: _wardController.text.trim(),
        village: _villageController.text.trim(),
        bloodGroup: _bloodGroup,
        facilityId: facilityId,
        allergies: const [],
        chronicConditions: const [],
        nextOfKinName: _nextOfKinNameController.text.trim().isEmpty ? null : _nextOfKinNameController.text.trim(),
        nextOfKinPhone: _nextOfKinPhoneController.text.trim().isEmpty ? null : _nextOfKinPhoneController.text.trim(),
        nextOfKinRelationship: _nextOfKinRelationship,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      context.read<PatientBloc>().add(RegisterPatientEvent(patient));
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryDark, size: 20),
          onPressed: _onPreviousStep,
        ),
        title: Text(
          'Patient Registration',
          style: TextStyle(color: primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: BlocConsumer<PatientBloc, PatientState>(
        listener: (context, state) {
          if (state is PatientError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
            );
          } else if (state is PatientRegistered) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ Patient ${state.patient.fullName} registered!'), backgroundColor: accentGreen, behavior: SnackBarBehavior.floating),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
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
                      _buildStepOne(),
                      _buildStepTwo(),
                      _buildStepThree(),
                    ],
                  ),
                ),
              ),
              _buildBottomAction(state is PatientLoading),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        children: [
          _stepIndicator(0, "Basic"),
          _lineIndicator(0),
          _stepIndicator(1, "Contact"),
          _lineIndicator(1),
          _stepIndicator(2, "Medical"),
        ],
      ),
    );
  }

  Widget _stepIndicator(int index, String label) {
    bool isCompleted = _currentStep > index;
    bool isActive = _currentStep == index;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 30, width: 30,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? primaryDark : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted 
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text("${index + 1}", style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? primaryDark : Colors.grey)),
      ],
    );
  }

  Widget _lineIndicator(int index) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: _currentStep > index ? primaryDark : Colors.grey[200],
      ),
    );
  }

  // --- FORM STEPS ---

  Widget _buildStepOne() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Identity & Name", "Ensure NUPI matches patient ID card"),
          const SizedBox(height: 20),
          _buildTextField(controller: _nupiController, label: "NUPI Number", icon: Icons.fingerprint, hint: "9 Digits", keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          _buildTextField(controller: _firstNameController, label: "First Name", icon: Icons.person_outline),
          const SizedBox(height: 20),
          _buildTextField(controller: _middleNameController, label: "Middle Name", icon: Icons.person_outline),
          const SizedBox(height: 20),
          _buildTextField(controller: _lastNameController, label: "Last Name", icon: Icons.person_outline),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDropdown(
                label: "Gender",
                value: _gender,
                items: ['male', 'female'],
                onChanged: (v) => setState(() => _gender = v!),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildDatePicker()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Contact Details", "Primary contact for health alerts"),
          const SizedBox(height: 20),
          _buildTextField(controller: _phoneController, label: "Phone Number", icon: Icons.phone_android, hint: "+254..."),
          const SizedBox(height: 20),
          _buildTextField(controller: _emailController, label: "Email Address", icon: Icons.alternate_email, hint: "Optional"),
          const SizedBox(height: 32),
          _sectionHeader("Residential Address", "Required for community health mapping"),
          const SizedBox(height: 20),
          _buildTextField(controller: _countyController, label: "County", icon: Icons.map_outlined),
          const SizedBox(height: 20),
          _buildTextField(controller: _subCountyController, label: "Sub-County", icon: Icons.location_city),
          const SizedBox(height: 20),
          _buildTextField(controller: _wardController, label: "Ward", icon: Icons.explore_outlined),
          const SizedBox(height: 20),
          _buildTextField(controller: _villageController, label: "Village/Street", icon: Icons.home_work_outlined),
        ],
      ),
    );
  }

  Widget _buildStepThree() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Clinical Metadata", "Optional fields for immediate triage"),
          const SizedBox(height: 20),
          _buildDropdown(
            label: "Blood Group",
            value: _bloodGroup,
            hint: "Select Blood Group",
            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),
          const SizedBox(height: 32),
          _sectionHeader("Next of Kin", "Emergency contact information"),
          const SizedBox(height: 20),
          _buildTextField(controller: _nextOfKinNameController, label: "Full Name", icon: Icons.contacts_outlined),
          const SizedBox(height: 20),
          _buildTextField(controller: _nextOfKinPhoneController, label: "Phone Number", icon: Icons.phone_android),
          const SizedBox(height: 20),
          _buildDropdown(
            label: "Relationship",
            value: _nextOfKinRelationship,
            hint: "Select Relationship",
            items: ['spouse', 'parent', 'child', 'sibling', 'friend', 'other'],
            onChanged: (v) => setState(() => _nextOfKinRelationship = v),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTS ---

  Widget _sectionHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark)),
        Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, String? hint, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryDark, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentGreen, width: 2)),
      ),
      validator: (v) => (v == null || v.isEmpty) && label.contains('*') ? 'Required' : null,
    );
  }

  Widget _buildDropdown({required String label, String? value, String? hint, required List<String> items, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(hint ?? ""),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now());
        if (date != null) setState(() => _dateOfBirth = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: primaryDark),
            const SizedBox(width: 8),
            Text(_dateOfBirth == null ? "DOB *" : DateFormat('dd/MM/yyyy').format(_dateOfBirth!), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : _onPreviousStep,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Back"),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading ? null : _onNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 2 ? "Finalize Registration" : "Continue"),
            ),
          ),
        ],
      ),
    );
  }
}