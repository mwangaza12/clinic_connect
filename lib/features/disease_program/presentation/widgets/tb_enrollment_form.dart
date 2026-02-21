import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TbEnrollmentForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;

  const TbEnrollmentForm({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<TbEnrollmentForm> createState() => _TbEnrollmentFormState();
}

class _TbEnrollmentFormState extends State<TbEnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisDateController = TextEditingController();
  final _treatmentStartDateController = TextEditingController();
  final _weightController = TextEditingController();
  
  String? _tbType;
  String? _diseaseSite;
  String? _treatmentRegimen;
  String? _hivStatus;
  bool _onArt = false;
  String? _treatmentPhase;

  final List<String> _tbTypes = [
    'New',
    'Relapse',
    'Treatment after Failure',
    'Treatment after Loss to Follow-up',
    'Other',
  ];

  final List<String> _diseaseSites = [
    'Pulmonary',
    'Extra-pulmonary',
  ];

  final List<String> _regimens = [
    'Category I (2HRZE/4HR)',
    'Category II (2HRZES/1HRZE/5HRE)',
    'MDR-TB Regimen',
    'XDR-TB Regimen',
  ];

  final List<String> _hivStatuses = [
    'Positive',
    'Negative',
    'Unknown',
  ];

  final List<String> _phases = [
    'Intensive Phase',
    'Continuation Phase',
  ];

  @override
  void initState() {
    super.initState();
    _updateParent();
  }

  void _updateParent() {
    final data = {
      'diagnosisDate': _diagnosisDateController.text,
      'tbType': _tbType,
      'diseaseSite': _diseaseSite,
      'treatmentStartDate': _treatmentStartDateController.text,
      'treatmentRegimen': _treatmentRegimen,
      'weight': _weightController.text,
      'hivStatus': _hivStatus,
      'onArt': _onArt,
      'treatmentPhase': _treatmentPhase,
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
                FaIcon(FontAwesomeIcons.lungs, color: Color(0xFF2D6A4F)),
                SizedBox(width: 12),
                Text(
                  'TB Enrollment Details',
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

            // TB Type
            DropdownButtonFormField<String>(
              value: _tbType,
              decoration: InputDecoration(
                labelText: 'TB Type',
                prefixIcon: const Icon(Icons.category, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _tbTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _tbType = value;
                  _updateParent();
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select TB type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Disease Site
            DropdownButtonFormField<String>(
              value: _diseaseSite,
              decoration: InputDecoration(
                labelText: 'Disease Site',
                prefixIcon: const Icon(Icons.location_on, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _diseaseSites.map((site) {
                return DropdownMenuItem(
                  value: site,
                  child: Text(site),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _diseaseSite = value;
                  _updateParent();
                });
              },
            ),
            const SizedBox(height: 16),

            // Treatment Start Date
            TextFormField(
              controller: _treatmentStartDateController,
              decoration: InputDecoration(
                labelText: 'Treatment Start Date',
                hintText: 'YYYY-MM-DD',
                prefixIcon: const Icon(Icons.medical_services, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 16),

            // Treatment Regimen
            DropdownButtonFormField<String>(
              value: _treatmentRegimen,
              decoration: InputDecoration(
                labelText: 'Treatment Regimen',
                prefixIcon: const Icon(Icons.medication, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _regimens.map((regimen) {
                return DropdownMenuItem(
                  value: regimen,
                  child: Text(regimen),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _treatmentRegimen = value;
                  _updateParent();
                });
              },
            ),
            const SizedBox(height: 16),

            // Weight
            TextFormField(
              controller: _weightController,
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                hintText: '65.5',
                prefixIcon: const Icon(Icons.monitor_weight, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 16),

            // HIV Status
            DropdownButtonFormField<String>(
              value: _hivStatus,
              decoration: InputDecoration(
                labelText: 'HIV Status',
                prefixIcon: const Icon(Icons.health_and_safety, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _hivStatuses.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _hivStatus = value;
                  _updateParent();
                });
              },
            ),

            if (_hivStatus == 'Positive') ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('On ART'),
                value: _onArt,
                onChanged: (value) {
                  setState(() {
                    _onArt = value ?? false;
                    _updateParent();
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 16),

            // Treatment Phase
            DropdownButtonFormField<String>(
              value: _treatmentPhase,
              decoration: InputDecoration(
                labelText: 'Treatment Phase',
                prefixIcon: const Icon(Icons.timeline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _phases.map((phase) {
                return DropdownMenuItem(
                  value: phase,
                  child: Text(phase),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _treatmentPhase = value;
                  _updateParent();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _treatmentStartDateController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}