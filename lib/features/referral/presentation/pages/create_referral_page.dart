// lib/features/referral/presentation/pages/create_referral_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../facility/domain/entities/facility.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../facility/presentation/bloc/facility_bloc.dart';
import '../../../facility/presentation/bloc/facility_event.dart';
import '../../../facility/presentation/bloc/facility_state.dart';
import '../../../patient/domain/entities/patient.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/bloc/patient_state.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/referral.dart';
import '../bloc/referral_bloc.dart';
import '../bloc/referral_event.dart';
import '../bloc/referral_state.dart';

class CreateReferralPage extends StatefulWidget {
  final User user;

  const CreateReferralPage({super.key, required this.user});

  @override
  State<CreateReferralPage> createState() => _CreateReferralPageState();
}

class _CreateReferralPageState extends State<CreateReferralPage> {
  final _formKey = GlobalKey<FormState>();
  final _toFacilityNameController = TextEditingController();
  final _toFacilityIdController = TextEditingController();
  final _reasonController = TextEditingController();
  final _clinicalSummaryController = TextEditingController();
  final _diagnosesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _searchController = TextEditingController();
  final _facilitySearchController = TextEditingController();

  ReferralPriority _priority = ReferralPriority.normal;
  Patient? _selectedPatient;
  Facility? _selectedFacility;
  bool _isSearchingFacilities = false;
  int _currentStep = 0;
  final PageController _pageController = PageController();

  final Color primaryDark = const Color(0xFF1B4332);

  @override
  void initState() {
    super.initState();
    // Load patients when page initializes - use addPostFrameCallback to ensure context has providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Use try-catch to handle any provider issues
        try {
          context.read<PatientBloc>().add(const LoadPatientsEvent());
          print('✅ PatientBloc loaded successfully');
        } catch (e) {
          print('❌ Error loading PatientBloc: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _toFacilityNameController.dispose();
    _toFacilityIdController.dispose();
    _reasonController.dispose();
    _clinicalSummaryController.dispose();
    _diagnosesController.dispose();
    _medicationsController.dispose();
    _instructionsController.dispose();
    _searchController.dispose();
    _facilitySearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Referral _createReferral() {
    // Combine clinical notes
    final clinicalNotes = '''
Clinical Summary: ${_clinicalSummaryController.text.trim()}
Diagnoses: ${_diagnosesController.text.trim()}
Current Medications: ${_medicationsController.text.trim()}
Special Instructions: ${_instructionsController.text.trim()}
'''.trim();

    print('📝 Creating referral with:');
    print('  - Patient: ${_selectedPatient!.fullName}');
    print('  - To: ${_selectedFacility!.name}');
    print('  - Reason: ${_reasonController.text.trim()}');

    return Referral(
      id: const Uuid().v4(),
      patientNupi: _selectedPatient!.nupi,
      patientName: _selectedPatient!.fullName,
      fromFacilityId: widget.user.facilityId,
      fromFacilityName: widget.user.facilityName,
      toFacilityId: _selectedFacility!.id,
      toFacilityName: _selectedFacility!.name,
      reason: _reasonController.text.trim(),
      priority: _priority,
      status: ReferralStatus.pending,
      clinicalNotes: clinicalNotes.isNotEmpty ? clinicalNotes : null,
      createdAt: DateTime.now(),
      createdBy: widget.user.id,
      createdByName: widget.user.name,
    );
  }

  void _submit() {
    print('🚀 _submit called');
    print('Form valid: ${_formKey.currentState?.validate()}');
    print('Selected patient: ${_selectedPatient?.fullName}');
    print('Selected facility: ${_selectedFacility?.name}');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }
    
    if (_selectedPatient == null) {
      print('❌ No patient selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_selectedFacility == null) {
      print('❌ No facility selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a receiving facility'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('📤 Dispatching CreateReferralEvent');
    // Use Provider.of instead of context.read for better reliability
    Provider.of<ReferralBloc>(context, listen: false).add(
      CreateReferralEvent(_createReferral()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Use create instead of value to ensure fresh instances
        BlocProvider<PatientBloc>(
          create: (context) => sl<PatientBloc>()..add(const LoadPatientsEvent()),
        ),
        BlocProvider<ReferralBloc>(
          create: (context) => sl<ReferralBloc>(),
        ),
        BlocProvider<FacilityBloc>(
          create: (context) => sl<FacilityBloc>(),
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: primaryDark,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'New Referral',
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: BlocConsumer<ReferralBloc, ReferralState>(
          listener: (context, state) {
            if (state is ReferralError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is ReferralCreated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Referral created successfully!'),
                  backgroundColor: Color(0xFF2D6A4F),
                ),
              );
              
              // Add a small delay to show the success message before popping
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            }
          },
          builder: (context, state) {
            // Show loading indicator if needed
            if (state is ReferralLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Creating referral...'),
                  ],
                ),
              );
            }
            
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
                        _buildStepOne(context),
                        _buildStepTwo(context),
                        _buildStepThree(),
                      ],
                    ),
                  ),
                ),
                _buildBottomActions(state is ReferralLoading),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        children: [
          _stepIndicator(0, 'Patient'),
          _lineIndicator(0),
          _stepIndicator(1, 'Facility'),
          _lineIndicator(1),
          _stepIndicator(2, 'Clinical'),
        ],
      ),
    );
  }

  Widget _stepIndicator(int index, String label) {
    final isCompleted = _currentStep > index;
    final isActive = _currentStep == index;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? primaryDark : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? primaryDark : Colors.grey,
          ),
        ),
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

  // Step 1: Select Patient
  Widget _buildStepOne(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Patient',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: primaryDark,
            ),
          ),
          const Text(
            'Choose the patient to be referred',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Selected Patient Display
          if (_selectedPatient != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2D6A4F).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2D6A4F),
                    child: Text(
                      _selectedPatient!.firstName
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPatient!.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'NUPI: ${_selectedPatient!.nupi} • ${_selectedPatient!.age} yrs',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2D6A4F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF2D6A4F)),
                    onPressed: () =>
                        setState(() => _selectedPatient = null),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Search
          TextField(
            controller: _searchController,
            onChanged: (query) {
              if (query.isEmpty) {
                context
                    .read<PatientBloc>()
                    .add(const LoadPatientsEvent());
              } else {
                context
                    .read<PatientBloc>()
                    .add(SearchPatientEvent(query));
              }
            },
            decoration: InputDecoration(
              hintText: 'Search by name, NUPI or phone...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Patient List
          BlocBuilder<PatientBloc, PatientState>(
            builder: (context, state) {
              if (state is PatientLoading) {
                return const Center(
                    child: CircularProgressIndicator.adaptive());
              }

              if (state is PatientsLoaded) {
                if (state.patients.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No patients found'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.patients.length,
                  itemBuilder: (context, index) {
                    final patient = state.patients[index];
                    final isSelected =
                        _selectedPatient?.id == patient.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2D6A4F).withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2D6A4F)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        onTap: () =>
                            setState(() => _selectedPatient = patient),
                        leading: CircleAvatar(
                          backgroundColor: patient.gender == 'female'
                              ? const Color(0xFFEC4899)
                              : const Color(0xFF6366F1),
                          child: Text(
                            patient.firstName
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          patient.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'NUPI: ${patient.nupi} • ${patient.age} yrs',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF2D6A4F))
                            : null,
                      ),
                    );
                  },
                );
              }

              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }

  // Step 2: Receiving Facility with Search
  Widget _buildStepTwo(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receiving Facility',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: primaryDark,
            ),
          ),
          const Text(
            'Where is the patient being referred to?',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Selected Facility Display
          if (_selectedFacility != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2D6A4F).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Color(0xFF2D6A4F),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFacility!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D6A4F).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedFacility!.type,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedFacility!.county} County',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF2D6A4F)),
                    onPressed: () {
                      setState(() {
                        _selectedFacility = null;
                        _toFacilityNameController.clear();
                        _toFacilityIdController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

          if (_selectedFacility == null) ...[
            const SizedBox(height: 16),

            // Search Input - Using Builder to ensure proper context
            Builder(
              builder: (context) => TextField(
                controller: _facilitySearchController,
                onChanged: (query) {
                  print('🔍 Searching for: "$query"');
                  if (query.length >= 3) {
                    setState(() => _isSearchingFacilities = true);
                    context.read<FacilityBloc>().add(
                      SearchFacilitiesEvent(query),
                    );
                  } else {
                    setState(() {
                      _isSearchingFacilities = false;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search for facility (min 3 characters)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _isSearchingFacilities
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
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
                    borderSide: BorderSide(color: const Color(0xFF2D6A4F), width: 2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Search Results
            BlocBuilder<FacilityBloc, FacilityState>(
              builder: (context, state) {
                print('📦 FacilityBloc state: $state');
                
                if (state is FacilitySearchLoaded) {
                  print('✅ Found ${state.facilities.length} facilities');
                  
                  if (state.facilities.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No facilities found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: BoxConstraints(
                      maxHeight: 200,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: state.facilities.length,
                      itemBuilder: (context, index) {
                        final facility = state.facilities[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _selectedFacility = facility;
                                _toFacilityNameController.text = facility.name;
                                _toFacilityIdController.text = facility.id;
                                _facilitySearchController.clear();
                                _isSearchingFacilities = false;
                              });
                              print('✅ Selected facility: ${facility.name}');
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D6A4F).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.local_hospital_rounded,
                                color: const Color(0xFF2D6A4F),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              facility.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${facility.county} • ${facility.type}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                
                if (state is FacilityLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (state is FacilityError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: ${state.message}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                
                return const SizedBox();
              },
            ),
          ],

          const SizedBox(height: 24),

          // Priority
          Text(
            'Referral Priority',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: primaryDark,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: ReferralPriority.values.map((p) {
              final isSelected = _priority == p;
              final color = p == ReferralPriority.normal
                  ? const Color(0xFF2D6A4F)
                  : p == ReferralPriority.urgent
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE11D48);

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          p == ReferralPriority.normal
                              ? Icons.schedule_rounded
                              : p == ReferralPriority.urgent
                                  ? Icons.priority_high_rounded
                                  : Icons.emergency_rounded,
                          color: isSelected ? color : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? color : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _buildField(
            controller: _reasonController,
            label: 'Referral Reason *',
            icon: Icons.notes_rounded,
            hint: 'Why is the patient being referred?',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // Step 3: Clinical Summary
  Widget _buildStepThree() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clinical Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: primaryDark,
            ),
          ),
          const Text(
            'Provide clinical context for receiving facility',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 24),

          _buildField(
            controller: _clinicalSummaryController,
            label: 'Clinical Summary *',
            icon: Icons.summarize_outlined,
            hint: 'Brief clinical history and current presentation...',
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          _buildField(
            controller: _diagnosesController,
            label: 'Diagnoses (optional)',
            icon: Icons.sick_outlined,
            hint: 'e.g. Malaria, Hypertension...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          _buildField(
            controller: _medicationsController,
            label: 'Current Medications (optional)',
            icon: Icons.medication_outlined,
            hint: 'List current medications...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          _buildField(
            controller: _instructionsController,
            label: 'Special Instructions (optional)',
            icon: Icons.info_outline_rounded,
            hint: 'Any special notes for receiving facility...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 60 : 0),
          child: Icon(icon, color: primaryDark, size: 20),
        ),
        filled: true,
        fillColor: Colors.white,
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
          borderSide: BorderSide(color: const Color(0xFF2D6A4F), width: 2),
        ),
      ),
      validator: (v) {
        if (label.contains('*') && (v == null || v.isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildBottomActions(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        setState(() => _currentStep--);
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      if (_currentStep < 2) {
                        // Validate current step before proceeding
                        if (_currentStep == 0 && _selectedPatient == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a patient'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _selectedFacility == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a facility'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        setState(() => _currentStep++);
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
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
                      _currentStep == 2 ? 'Submit Referral' : 'Continue',
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