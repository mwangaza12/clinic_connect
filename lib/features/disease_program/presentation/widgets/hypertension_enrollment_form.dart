// lib/features/disease_program/presentation/widgets/hypertension_enrollment_form.dart

import 'package:flutter/material.dart';

class HypertensionEnrollmentForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;

  const HypertensionEnrollmentForm({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<HypertensionEnrollmentForm> createState() => _HypertensionEnrollmentFormState();
}

class _HypertensionEnrollmentFormState extends State<HypertensionEnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisDateController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  
  String? _riskCategory;
  String? _medicationAdherence;
  bool _hasComplications = false;
  List<String> _selectedComplications = [];

  final List<String> _riskCategories = [
    'Low Risk',
    'Moderate Risk',
    'High Risk',
    'Very High Risk',
  ];

  final List<String> _adherenceLevels = [
    'Good (≥95%)',
    'Fair (80-94%)',
    'Poor (<80%)',
  ];

  final List<String> _complications = [
    'Stroke',
    'Heart Attack',
    'Heart Failure',
    'Kidney Disease',
    'Vision Loss',
    'None',
  ];

  @override
  void initState() {
    super.initState();
    _updateParent();
  }

  void _updateParent() {
    final data = {
      'diagnosisDate': _diagnosisDateController.text,
      'systolic': _systolicController.text,
      'diastolic': _diastolicController.text,
      'heartRate': _heartRateController.text,
      'riskCategory': _riskCategory,
      'medicationAdherence': _medicationAdherence,
      'hasComplications': _hasComplications,
      'complications': _selectedComplications,
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
                Icon(Icons.favorite, color: Color(0xFF2D6A4F)),
                SizedBox(width: 12),
                Text(
                  'Hypertension Enrollment Details',
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

            // Blood Pressure Readings
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _systolicController,
                    decoration: InputDecoration(
                      labelText: 'Systolic (mmHg)',
                      hintText: '120',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateParent(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _diastolicController,
                    decoration: InputDecoration(
                      labelText: 'Diastolic (mmHg)',
                      hintText: '80',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateParent(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Heart Rate
            TextFormField(
              controller: _heartRateController,
              decoration: InputDecoration(
                labelText: 'Heart Rate (bpm)',
                hintText: '72',
                prefixIcon: const Icon(Icons.favorite, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 16),

            // Risk Category
            DropdownButtonFormField<String>(
              initialValue: _riskCategory,
              decoration: InputDecoration(
                labelText: 'Risk Category',
                prefixIcon: const Icon(Icons.warning, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _riskCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _riskCategory = value;
                  _updateParent();
                });
              },
            ),
            const SizedBox(height: 16),

            // Medication Adherence
            DropdownButtonFormField<String>(
              value: _medicationAdherence,
              decoration: InputDecoration(
                labelText: 'Medication Adherence',
                prefixIcon: const Icon(Icons.medication, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _adherenceLevels.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _medicationAdherence = value;
                  _updateParent();
                });
              },
            ),
            const SizedBox(height: 16),

            // Complications
            CheckboxListTile(
              title: const Text('Has Complications'),
              value: _hasComplications,
              onChanged: (value) {
                setState(() {
                  _hasComplications = value ?? false;
                  if (!_hasComplications) {
                    _selectedComplications = ['None'];
                  }
                  _updateParent();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            if (_hasComplications) ...[
              const SizedBox(height: 8),
              const Text(
                'Select Complications:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._complications.where((c) => c != 'None').map((complication) {
                return CheckboxListTile(
                  title: Text(complication),
                  value: _selectedComplications.contains(complication),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedComplications.add(complication);
                      } else {
                        _selectedComplications.remove(complication);
                      }
                      _updateParent();
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    super.dispose();
  }
}