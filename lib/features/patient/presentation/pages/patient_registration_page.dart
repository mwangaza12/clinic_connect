import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../injection_container.dart';
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
  int _currentStep = 0;

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
  List<String> _allergies = [];
  List<String> _chronicConditions = [];

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
    super.dispose();
  }

  void _registerPatient() {
    if (_formKey.currentState!.validate()) {
      if (_dateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select date of birth')),
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
        allergies: _allergies,
        chronicConditions: _chronicConditions,
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

      context.read<PatientBloc>().add(RegisterPatientEvent(patient));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Patient'),
      ),
      body: BlocConsumer<PatientBloc, PatientState>(
        listener: (context, state) {
          if (state is PatientError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is PatientRegistered) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Patient ${state.patient.fullName} registered successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          if (state is PatientLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Form(
            key: _formKey,
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  _registerPatient();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 2 ? 'Register' : 'Continue'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: Basic Information
                Step(
                  title: const Text('Basic Information'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      TextFormField(
                        controller: _nupiController,
                        decoration: const InputDecoration(
                          labelText: 'NUPI *',
                          hintText: '123456789',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 9,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'NUPI is required';
                          }
                          if (value.length != 9) {
                            return 'NUPI must be 9 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _middleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Middle Name *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Middle name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Last name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(value: 'female', child: Text('Female')),
                        ],
                        onChanged: (value) {
                          setState(() => _gender = value!);
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _dateOfBirth = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _dateOfBirth == null
                                ? 'Select date'
                                : DateFormat('dd/MM/yyyy').format(_dateOfBirth!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step 2: Contact & Address
                Step(
                  title: const Text('Contact & Address'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: '+254712345678',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Phone number is required';
                          }
                          if (!value.startsWith('+254')) {
                            return 'Phone must start with +254';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _countyController,
                        decoration: const InputDecoration(
                          labelText: 'County *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'County is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subCountyController,
                        decoration: const InputDecoration(
                          labelText: 'Sub-County *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Sub-County is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _wardController,
                        decoration: const InputDecoration(
                          labelText: 'Ward *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ward is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _villageController,
                        decoration: const InputDecoration(
                          labelText: 'Village *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Village is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // Step 3: Medical & Next of Kin
                Step(
                  title: const Text('Medical & Next of Kin'),
                  isActive: _currentStep >= 2,
                  state: StepState.indexed,
                  content: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _bloodGroup,
                        decoration: const InputDecoration(
                          labelText: 'Blood Group (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'A+', child: Text('A+')),
                          DropdownMenuItem(value: 'A-', child: Text('A-')),
                          DropdownMenuItem(value: 'B+', child: Text('B+')),
                          DropdownMenuItem(value: 'B-', child: Text('B-')),
                          DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                          DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                          DropdownMenuItem(value: 'O+', child: Text('O+')),
                          DropdownMenuItem(value: 'O-', child: Text('O-')),
                        ],
                        onChanged: (value) {
                          setState(() => _bloodGroup = value);
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const Text('Next of Kin (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nextOfKinNameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nextOfKinPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+254712345678',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _nextOfKinRelationship,
                        decoration: const InputDecoration(
                          labelText: 'Relationship',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'spouse', child: Text('Spouse')),
                          DropdownMenuItem(value: 'parent', child: Text('Parent')),
                          DropdownMenuItem(value: 'child', child: Text('Child')),
                          DropdownMenuItem(value: 'sibling', child: Text('Sibling')),
                          DropdownMenuItem(value: 'friend', child: Text('Friend')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          setState(() => _nextOfKinRelationship = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}