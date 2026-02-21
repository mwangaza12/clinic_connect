// lib/features/disease_program/presentation/widgets/malaria_enrollment_form.dart

import 'package:flutter/material.dart';

class MalariaEnrollmentForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;

  const MalariaEnrollmentForm({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<MalariaEnrollmentForm> createState() => _MalariaEnrollmentFormState();
}

class _MalariaEnrollmentFormState extends State<MalariaEnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisDateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _parasiteCountController = TextEditingController();
  
  String? _malariaType;
  String? _severity;
  String? _diagnosisMethod;
  bool _receivedTreatment = false;
  String? _treatmentOutcome;

  final List<String> _malariaTypes = [
    'P. falciparum',
    'P. vivax',
    'P. malariae',
    'P. ovale',
    'Mixed',
  ];

  final List<String> _severityLevels = [
    'Uncomplicated',
    'Severe',
  ];

  final List<String> _diagnosisMethods = [
    'RDT',
    'Microscopy',
    'PCR',
  ];

  final List<String> _outcomes = [
    'Improved',
    'Completed Treatment',
    'Referred',
    'Defaulted',
  ];

  @override
  void initState() {
    super.initState();
    _updateParent();
  }

  void _updateParent() {
    final data = {
      'diagnosisDate': _diagnosisDateController.text,
      'malariaType': _malariaType,
      'severity': _severity,
      'temperature': _temperatureController.text,
      'parasiteCount': _parasiteCountController.text,
      'diagnosisMethod': _diagnosisMethod,
      'receivedTreatment': _receivedTreatment,
      'treatmentOutcome': _treatmentOutcome,
    };
    widget.onDataChanged(data);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bug_report, color: Color(0xFF2D6A4F)),
                SizedBox(width: 12),
                Text(
                  'Malaria Enrollment Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Diagnosis Date
            TextFormField(
              controller: _diagnosisDateController,
              decoration: InputDecoration(
                labelText: 'Diagnosis Date',
                hintText: 'YYYY-MM-DD',
                prefixIcon: const Icon(Icons.calendar_today, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => _updateParent(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter diagnosis date';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Malaria Type
            DropdownButtonFormField<String>(
              value: _malariaType,
              decoration: InputDecoration(
                labelText: 'Malaria Type',
                prefixIcon: const Icon(Icons.biotech, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _malariaTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _malariaType = value;
                  _updateParent();
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select malaria type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Severity
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: InputDecoration(
                labelText: 'Severity',
                prefixIcon: const Icon(Icons.warning, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _severityLevels.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _severity = value;
                  _updateParent();
                });
              },
            ),
            const SizedBox(height: 16),

            // Temperature
            TextFormField(
              controller: _temperatureController,
              decoration: InputDecoration(
                labelText: 'Temperature (°C)',
                hintText: '38.5',
                prefixIcon: const Icon(Icons.thermostat, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 16),

            // Parasite Count
            TextFormField(
              controller: _parasiteCountController,
              decoration: InputDecoration(
                labelText: 'Parasite Count (/μL)',
                hintText: '5000',
                prefixIcon: const Icon(Icons.science, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 16),

            // Diagnosis Method
            DropdownButtonFormField<String>(
              value: _diagnosisMethod,
              decoration: InputDecoration(
                labelText: 'Diagnosis Method',
                prefixIcon: const Icon(Icons.medical_information, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _diagnosisMethods.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _diagnosisMethod = value;
                  _updateParent();
                });
              },
            ),
            const SizedBox(height: 16),

            // Treatment Received
            CheckboxListTile(
              title: const Text('Received Treatment'),
              value: _receivedTreatment,
              onChanged: (value) {
                setState(() {
                  _receivedTreatment = value ?? false;
                  if (!_receivedTreatment) {
                    _treatmentOutcome = null;
                  }
                  _updateParent();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            if (_receivedTreatment) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _treatmentOutcome,
                decoration: InputDecoration(
                  labelText: 'Treatment Outcome',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _outcomes.map((outcome) {
                  return DropdownMenuItem(
                    value: outcome,
                    child: Text(outcome),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _treatmentOutcome = value;
                    _updateParent();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _temperatureController.dispose();
    _parasiteCountController.dispose();
    super.dispose();
  }
}