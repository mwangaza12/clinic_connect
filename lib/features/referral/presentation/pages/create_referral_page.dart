import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../facility/domain/entities/facility.dart';
import '../../../facility/presentation/bloc/facility_bloc.dart';
import '../../../facility/presentation/bloc/facility_event.dart';
import '../../../facility/presentation/bloc/facility_state.dart';
import '../../../patient/domain/entities/patient.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/bloc/patient_state.dart';
import '../../domain/entities/referral.dart';
import '../bloc/referral_bloc.dart';
import '../bloc/referral_event.dart';
import '../bloc/referral_state.dart';

class CreateReferralPage extends StatelessWidget {
  final User user;

  const CreateReferralPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PatientBloc>(
          create: (_) => sl<PatientBloc>()..add(const LoadPatientsEvent()),
        ),
        BlocProvider<FacilityBloc>(
          create: (_) => sl<FacilityBloc>(),
        ),
        // ✅ ReferralBloc is FRESH here, and BlocConsumer below listens to IT
        BlocProvider<ReferralBloc>(
          create: (_) => sl<ReferralBloc>(),
        ),
      ],
      child: _CreateReferralView(user: user),
    );
  }
}

class _CreateReferralView extends StatefulWidget {
  final User user;

  const _CreateReferralView({required this.user});

  @override
  State<_CreateReferralView> createState() => _CreateReferralViewState();
}

class _CreateReferralViewState extends State<_CreateReferralView> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _clinicalSummaryController = TextEditingController();
  final _diagnosesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _searchController = TextEditingController();
  final _facilitySearchController = TextEditingController();
  final PageController _pageController = PageController();

  ReferralPriority _priority = ReferralPriority.normal;
  Patient? _selectedPatient;
  Facility? _selectedFacility;
  int _currentStep = 0;

  final Color primaryDark = const Color(0xFF1B4332);

  @override
  void dispose() {
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatient == null) {
      _showSnack('Please select a patient', Colors.orange);
      return;
    }
    if (_selectedFacility == null) {
      _showSnack('Please select a receiving facility', Colors.orange);
      return;
    }

    final clinicalNotes = [
      if (_clinicalSummaryController.text.trim().isNotEmpty)
        'Summary: ${_clinicalSummaryController.text.trim()}',
      if (_diagnosesController.text.trim().isNotEmpty)
        'Diagnoses: ${_diagnosesController.text.trim()}',
      if (_medicationsController.text.trim().isNotEmpty)
        'Medications: ${_medicationsController.text.trim()}',
      if (_instructionsController.text.trim().isNotEmpty)
        'Instructions: ${_instructionsController.text.trim()}',
    ].join('\n');

    final referral = Referral(
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

    // ✅ This reads from the BlocProvider ABOVE in the same widget tree
    context.read<ReferralBloc>().add(CreateReferralEvent(referral));
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedPatient == null) {
      _showSnack('Please select a patient', Colors.orange);
      return;
    }
    if (_currentStep == 1 && _selectedFacility == null) {
      _showSnack('Please select a receiving facility', Colors.orange);
      return;
    }
    if (_currentStep == 1 && _reasonController.text.trim().isEmpty) {
      _showSnack('Please enter a referral reason', Colors.orange);
      return;
    }

    setState(() => _currentStep++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevStep() {
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryDark,
            size: 20,
          ),
          onPressed: _prevStep,
        ),
        title: Text(
          'New Referral',
          style: TextStyle(
            color: primaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // ✅ BlocConsumer now listens to the ReferralBloc
      //    provided by CreateReferralPage above
      body: BlocConsumer<ReferralBloc, ReferralState>(
        listener: (context, state) {
          if (state is ReferralError) {
            _showSnack(state.message, Colors.red);
          } else if (state is ReferralCreated) {
            _showSnack(
              '✅ Referral created successfully!',
              const Color(0xFF2D6A4F),
            );
            // ✅ Pop immediately with result = true
            // so ReferralsPage knows to reload
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          final isLoading = state is ReferralLoading;

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
              _buildBottomActions(isLoading),
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

  // ─────────────────────────────────────────
  // Step 1: Select Patient
  // ─────────────────────────────────────────
  Widget _buildStepOne() {
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

          // Selected patient card
          if (_selectedPatient != null)
            _selectedPatientCard(_selectedPatient!),

          const SizedBox(height: 16),

          // Search
          TextField(
            controller: _searchController,
            onChanged: (query) {
              if (query.isEmpty) {
                context.read<PatientBloc>().add(const LoadPatientsEvent());
              } else {
                context.read<PatientBloc>().add(SearchPatientEvent(query));
              }
            },
            decoration: _inputDecoration(
              'Search by name, NUPI or phone...',
              Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 12),

          // Patient list
          BlocBuilder<PatientBloc, PatientState>(
            builder: (context, state) {
              if (state is PatientLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                );
              }

              if (state is PatientsLoaded) {
                if (state.patients.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No patients found.\nRegister a patient first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.patients.length,
                  itemBuilder: (context, index) {
                    final patient = state.patients[index];
                    final isSelected = _selectedPatient?.id == patient.id;

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
                            style:
                                const TextStyle(color: Colors.white),
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
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2D6A4F),
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Color(0xFFCBD5E1),
                              ),
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

  Widget _selectedPatientCard(Patient patient) {
    return Container(
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
              patient.firstName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'NUPI: ${patient.nupi} • ${patient.age} yrs',
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
            onPressed: () => setState(() => _selectedPatient = null),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Step 2: Select Facility
  // ─────────────────────────────────────────
  Widget _buildStepTwo() {
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
            'Search verified ClinicConnect facilities',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withOpacity(0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF0EA5E9), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only registered ClinicConnect facilities appear here. Patient data stays secure.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0369A1),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Selected facility card
          if (_selectedFacility != null)
            _selectedFacilityCard(_selectedFacility!)
          else ...[
            // Facility search
            TextField(
              controller: _facilitySearchController,
              onChanged: (query) {
                if (query.length >= 2) {
                  context
                      .read<FacilityBloc>()
                      .add(SearchFacilitiesEvent(query));
                }
              },
              decoration: _inputDecoration(
                'Search facility name or county...',
                Icons.search_rounded,
              ),
            ),
            const SizedBox(height: 12),

            // Facility results
            BlocBuilder<FacilityBloc, FacilityState>(
              builder: (context, state) {
                if (state is FacilityLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  );
                }

                if (state is FacilityError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (state is FacilitySearchLoaded) {
                  if (state.facilities.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 8),
                          Text(
                            'No facilities found.\nFacility must be registered on ClinicConnect.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.facilities.length,
                    itemBuilder: (context, index) {
                      final facility = state.facilities[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedFacility = facility;
                              _facilitySearchController.clear();
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D6A4F)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: Color(0xFF2D6A4F),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            facility.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${facility.type} • ${facility.county} County',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      );
                    },
                  );
                }

                // Initial state hint
                if (_facilitySearchController.text.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.local_hospital_outlined,
                            size: 40, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 8),
                        Text(
                          'Type to search for a facility',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
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
                        color: isSelected
                            ? color
                            : const Color(0xFFE2E8F0),
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

          // Referral reason
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Referral Reason *',
              hintText: 'Why is the patient being referred?',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.notes_rounded,
                    color: Color(0xFF1B4332), size: 20),
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
                borderSide:
                    const BorderSide(color: Color(0xFF2D6A4F), width: 2),
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Referral reason is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _selectedFacilityCard(Facility facility) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2D6A4F).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: Color(0xFF2D6A4F),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: Color(0xFF2D6A4F)),
                    const SizedBox(width: 4),
                    const Text(
                      'VERIFIED FACILITY',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF2D6A4F),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  facility.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${facility.type} • ${facility.county} County',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF2D6A4F)),
            onPressed: () => setState(() => _selectedFacility = null),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Step 3: Clinical Summary
  // ─────────────────────────────────────────
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
            'Provide clinical context for the receiving facility',
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
            label: 'Diagnoses',
            icon: Icons.sick_outlined,
            hint: 'e.g. Malaria, Hypertension...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          _buildField(
            controller: _medicationsController,
            label: 'Current Medications',
            icon: Icons.medication_outlined,
            hint: 'List current medications and doses...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          _buildField(
            controller: _instructionsController,
            label: 'Special Instructions',
            icon: Icons.info_outline_rounded,
            hint: 'Any special notes for receiving facility...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Summary review card
          if (_selectedPatient != null && _selectedFacility != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4332).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1B4332).withOpacity(0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REFERRAL SUMMARY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B4332),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summaryRow(Icons.person_rounded,
                      'Patient', _selectedPatient!.fullName),
                  _summaryRow(Icons.local_hospital_rounded,
                      'To', _selectedFacility!.name),
                  _summaryRow(Icons.flag_rounded,
                      'Priority', _priority.name.toUpperCase()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1B4332)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
          borderSide: const BorderSide(
              color: Color(0xFF2D6A4F), width: 2),
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

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
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
        borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 2),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Bottom Actions
  // ─────────────────────────────────────────
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
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : _prevStep,
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
                        _nextStep();
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