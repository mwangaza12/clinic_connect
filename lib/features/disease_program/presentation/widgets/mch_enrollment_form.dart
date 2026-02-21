// lib/features/disease_program/presentation/widgets/mch_enrollment_form.dart

import 'package:flutter/material.dart';

class MchEnrollmentForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;

  const MchEnrollmentForm({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<MchEnrollmentForm> createState() => _MchEnrollmentFormState();
}

class _MchEnrollmentFormState extends State<MchEnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _eddController = TextEditingController();
  final _gravidityController = TextEditingController();
  final _parityController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  
  String? _serviceType;
  String? _riskLevel;
  bool _hasAncVisits = false;
  int _ancVisits = 0;
  bool _receivingIron = false;
  bool _receivingFolicAcid = false;
  bool _receivingIptp = false;
  bool _receivingTtv = false;

  final List<String> _serviceTypes = [
    'Antenatal Care (ANC)',
    'Postnatal Care (PNC)',
    'Family Planning',
    'Child Welfare',
    'Immunization',
  ];

  final List<String> _riskLevels = [
    'Low Risk',
    'Medium Risk',
    'High Risk',
  ];

  @override
  void initState() {
    super.initState();
    _updateParent();
  }

  void _updateParent() {
    final data = {
      'serviceType': _serviceType,
      'edd': _eddController.text,
      'gravidity': _gravidityController.text,
      'parity': _parityController.text,
      'height': _heightController.text,
      'weight': _weightController.text,
      'riskLevel': _riskLevel,
      'hasAncVisits': _hasAncVisits,
      'ancVisits': _ancVisits,
      'receivingIron': _receivingIron,
      'receivingFolicAcid': _receivingFolicAcid,
      'receivingIptp': _receivingIptp,
      'receivingTtv': _receivingTtv,
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
                Icon(Icons.pregnant_woman, color: Color(0xFF2D6A4F)),
                SizedBox(width: 12),
                Text(
                  'MCH Enrollment Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Service Type
            DropdownButtonFormField<String>(
              value: _serviceType,
              decoration: InputDecoration(
                labelText: 'Service Type',
                prefixIcon: const Icon(Icons.medical_services, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _serviceTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _serviceType = value;
                  _updateParent();
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select service type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // EDD (if ANC)
            if (_serviceType == 'Antenatal Care (ANC)') ...[
              TextFormField(
                controller: _eddController,
                decoration: InputDecoration(
                  labelText: 'Expected Delivery Date (EDD)',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => _updateParent(),
              ),
              const SizedBox(height: 16),

              // Gravidity and Parity
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gravidityController,
                      decoration: InputDecoration(
                        labelText: 'Gravidity',
                        hintText: 'Number of pregnancies',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateParent(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _parityController,
                      decoration: InputDecoration(
                        labelText: 'Parity',
                        hintText: 'Number of births',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateParent(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Height and Weight
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    decoration: InputDecoration(
                      labelText: 'Height (cm)',
                      hintText: '165',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateParent(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: '65',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateParent(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Risk Level
            DropdownButtonFormField<String>(
              value: _riskLevel,
              decoration: InputDecoration(
                labelText: 'Risk Level',
                prefixIcon: const Icon(Icons.warning, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _riskLevels.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _riskLevel = value;
                  _updateParent();
                });
              },
            ),
            const SizedBox(height: 16),

            // ANC Visits
            CheckboxListTile(
              title: const Text('Has had ANC visits'),
              value: _hasAncVisits,
              onChanged: (value) {
                setState(() {
                  _hasAncVisits = value ?? false;
                  if (!_hasAncVisits) {
                    _ancVisits = 0;
                  }
                  _updateParent();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            if (_hasAncVisits) ...[
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Number of ANC Visits',
                  prefixIcon: const Icon(Icons.numbers, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _ancVisits = int.tryParse(value) ?? 0;
                  _updateParent();
                },
              ),
              const SizedBox(height: 16),
            ],

            // Interventions
            const Text(
              'Interventions Received:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            
            CheckboxListTile(
              title: const Text('Iron Supplementation'),
              value: _receivingIron,
              onChanged: (value) {
                setState(() {
                  _receivingIron = value ?? false;
                  _updateParent();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            CheckboxListTile(
              title: const Text('Folic Acid'),
              value: _receivingFolicAcid,
              onChanged: (value) {
                setState(() {
                  _receivingFolicAcid = value ?? false;
                  _updateParent();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            CheckboxListTile(
              title: const Text('Intermittent Preventive Treatment (IPTp)'),
              value: _receivingIptp,
              onChanged: (value) {
                setState(() {
                  _receivingIptp = value ?? false;
                  _updateParent();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            CheckboxListTile(
              title: const Text('Tetanus Toxoid Vaccination (TTV)'),
              value: _receivingTtv,
              onChanged: (value) {
                setState(() {
                  _receivingTtv = value ?? false;
                  _updateParent();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _eddController.dispose();
    _gravidityController.dispose();
    _parityController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}