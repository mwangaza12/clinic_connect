// lib/features/disease_program/presentation/pages/enroll_patient_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/disease_program.dart';
import '../bloc/program_bloc.dart';
import '../bloc/program_event.dart';
import '../bloc/program_state.dart';
// All non-HIV enrollment forms live in diabetes_enrollment_form.dart
// (Hypertension, Malaria, TB, MCH classes are all defined there too).
import '../widgets/diabetes_enrollment_form.dart';
import '../widgets/hiv_enrollment_form.dart';

class EnrollPatientPage extends StatefulWidget {
  final String patientNupi;
  final String patientName;
  final String facilityId;

  /// When provided, the page is in edit mode — program is pre-selected
  /// and existing clinical data seeds the form via _formData.
  final ProgramEnrollment? initialEnrollment;

  const EnrollPatientPage({
    super.key,
    required this.patientNupi,
    required this.patientName,
    required this.facilityId,
    this.initialEnrollment,
  });

  @override
  State<EnrollPatientPage> createState() => _EnrollPatientPageState();
}

class _EnrollPatientPageState extends State<EnrollPatientPage> {
  DiseaseProgram? _selectedProgram;
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};

  bool get _isEditing => widget.initialEnrollment != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEnrollment;
    if (e != null) {
      _selectedProgram = e.program;
      if (e.programSpecificData != null) {
        _formData.addAll(e.programSpecificData!);
      }
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
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Enrollment' : 'Enroll in Disease Program',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              widget.patientName,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: BlocListener<ProgramBloc, ProgramState>(
        listener: (context, state) {
          if (state is EnrollmentSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF2D6A4F),
              ),
            );
            Navigator.pop(context, true);
          } else if (state is ProgramError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<ProgramBloc, ProgramState>(
          builder: (context, state) {
            if (state is ProgramLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Program Selection Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.medical_services_rounded,
                                color: Color(0xFF2D6A4F),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Select Disease Program',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: DiseaseProgram.values.map((program) {
                              final isSelected =
                                  _selectedProgram == program;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedProgram = program;
                                    _formData.clear();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF2D6A4F)
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF2D6A4F)
                                          : const Color(0xFFE2E8F0),
                                      width: 2,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    program.code,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Program-specific form + enroll button
                    if (_selectedProgram != null) ...[
                      _buildProgramSpecificForm(_selectedProgram!),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: state is ProgramLoading
                              ? null
                              : _handleEnrollment,
                          icon:
                              const Icon(Icons.check_circle_rounded),
                          label: Text(
                              _isEditing
                                  ? 'Update ${_selectedProgram!.code}'
                                  : 'Enroll in ${_selectedProgram!.code}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A4F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgramSpecificForm(DiseaseProgram program) {
    // In edit mode _formData is pre-seeded from the existing enrollment's
    // programSpecificData. Pass it as initialData so form controllers
    // pre-populate their fields.
    final init = _isEditing && _formData.isNotEmpty
        ? Map<String, dynamic>.from(_formData)
        : null;

    switch (program) {
      case DiseaseProgram.hivArt:
        return HivEnrollmentForm(
            onDataChanged: (data) => _formData.addAll(data),
            initialData: init);
      case DiseaseProgram.ncdDiabetes:
        return DiabetesEnrollmentForm(
            onDataChanged: (data) => _formData.addAll(data),
            initialData: init);
      case DiseaseProgram.hypertension:
        return HypertensionEnrollmentForm(
            onDataChanged: (data) => _formData.addAll(data),
            initialData: init);
      case DiseaseProgram.malaria:
        return MalariaEnrollmentForm(
            onDataChanged: (data) => _formData.addAll(data),
            initialData: init);
      case DiseaseProgram.tb:
        return TbEnrollmentForm(
            onDataChanged: (data) => _formData.addAll(data),
            initialData: init);
      case DiseaseProgram.mch:
        return MchEnrollmentForm(
            onDataChanged: (data) => _formData.addAll(data),
            initialData: init);
    }
  }

  void _handleEnrollment() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      final existing = widget.initialEnrollment;
      final enrollment = ProgramEnrollment(
        id:                  existing?.id ?? const Uuid().v4(),
        patientNupi:         widget.patientNupi,
        patientName:         widget.patientName,
        facilityId:          widget.facilityId,
        program:             _selectedProgram!,
        status:              existing?.status ?? ProgramEnrollmentStatus.active,
        enrollmentDate:      existing?.enrollmentDate ?? DateTime.now(),
        programSpecificData: _formData.isEmpty ? null : Map.from(_formData),
        createdAt:           existing?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        context.read<ProgramBloc>().add(UpdateEnrollment(enrollment));
      } else {
        context.read<ProgramBloc>().add(EnrollPatientInProgram(enrollment));
      }
    }
  }
}