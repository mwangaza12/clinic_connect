// lib/features/disease_program/presentation/widgets/hiv_enrollment_form.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HivEnrollmentForm extends StatefulWidget {
  const HivEnrollmentForm({super.key, required void Function(dynamic data) onDataChanged});

  @override
  State<HivEnrollmentForm> createState() => _HivEnrollmentFormState();
}

class _HivEnrollmentFormState extends State<HivEnrollmentForm> {
  final _diagnosisDateController = TextEditingController();
  final _arvStartDateController = TextEditingController();
  final _cd4CountController = TextEditingController();
  final _viralLoadController = TextEditingController();
  final _viralLoadDateController = TextEditingController();
  final _nextAppointmentController = TextEditingController();

  String? _whoStage;
  String? _arvRegimen;
  String? _viralLoadStatus;
  bool _onTbProphylaxis = false;
  bool _onCotrimoxazole = false;

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _arvStartDateController.dispose();
    _cd4CountController.dispose();
    _viralLoadController.dispose();
    _viralLoadDateController.dispose();
    _nextAppointmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2D6A4F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(date);
    }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medical_information_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'HIV/ART Program Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // HIV Diagnosis Date
          TextFormField(
            controller: _diagnosisDateController,
            decoration: InputDecoration(
              labelText: 'HIV Diagnosis Date *',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            readOnly: true,
            onTap: () => _selectDate(context, _diagnosisDateController),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Diagnosis date required' : null,
          ),
          const SizedBox(height: 16),

          // WHO Clinical Stage
          DropdownButtonFormField<String>(
            value: _whoStage,
            decoration: InputDecoration(
              labelText: 'WHO Clinical Stage *',
              prefixIcon: const Icon(Icons.stairs_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            items: ['Stage 1', 'Stage 2', 'Stage 3', 'Stage 4']
                .map((stage) => DropdownMenuItem(
                      value: stage,
                      child: Text(stage),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _whoStage = value),
            validator: (value) => value == null ? 'WHO stage required' : null,
          ),
          const SizedBox(height: 16),

          // CD4 Count
          TextFormField(
            controller: _cd4CountController,
            decoration: InputDecoration(
              labelText: 'Current CD4 Count (cells/μL)',
              prefixIcon: const Icon(Icons.bloodtype),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              helperText: 'Normal range: 500-1200 cells/μL',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // ARV Regimen
          DropdownButtonFormField<String>(
            value: _arvRegimen,
            decoration: InputDecoration(
              labelText: 'ARV Regimen *',
              prefixIcon: const Icon(Icons.medication_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            items: [
              'TDF/3TC/DTG',
              'TDF/3TC/EFV',
              'ABC/3TC/DTG',
              'AZT/3TC/NVP',
              'Other',
            ]
                .map((regimen) => DropdownMenuItem(
                      value: regimen,
                      child: Text(regimen),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _arvRegimen = value),
            validator: (value) => value == null ? 'ARV regimen required' : null,
          ),
          const SizedBox(height: 16),

          // ARV Start Date
          TextFormField(
            controller: _arvStartDateController,
            decoration: InputDecoration(
              labelText: 'ARV Start Date *',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            readOnly: true,
            onTap: () => _selectDate(context, _arvStartDateController),
            validator: (value) =>
                value?.isEmpty ?? true ? 'ARV start date required' : null,
          ),
          const SizedBox(height: 16),

          // Viral Load Status
          DropdownButtonFormField<String>(
            value: _viralLoadStatus,
            decoration: InputDecoration(
              labelText: 'Viral Load Status',
              prefixIcon: const Icon(Icons.science_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            items: ['Suppressed (<50 copies/mL)', 'Detectable', 'Pending']
                .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _viralLoadStatus = value),
          ),
          const SizedBox(height: 16),

          // Viral Load Value
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _viralLoadController,
                  decoration: InputDecoration(
                    labelText: 'Last Viral Load (copies/mL)',
                    prefixIcon: const Icon(Icons.analytics_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _viralLoadDateController,
                  decoration: InputDecoration(
                    labelText: 'VL Date',
                    prefixIcon: const Icon(Icons.calendar_today, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  readOnly: true,
                  onTap: () => _selectDate(context, _viralLoadDateController),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Prophylaxis Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prophylaxis',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text(
                    'On TB Prophylaxis (Isoniazid)',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: _onTbProphylaxis,
                  onChanged: (value) {
                    setState(() => _onTbProphylaxis = value ?? false);
                  },
                  activeColor: const Color(0xFF2D6A4F),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text(
                    'On Cotrimoxazole Prophylaxis',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: _onCotrimoxazole,
                  onChanged: (value) {
                    setState(() => _onCotrimoxazole = value ?? false);
                  },
                  activeColor: const Color(0xFF2D6A4F),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Next Appointment
          TextFormField(
            controller: _nextAppointmentController,
            decoration: InputDecoration(
              labelText: 'Next Appointment Date *',
              prefixIcon: const Icon(Icons.event_available),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            readOnly: true,
            onTap: () => _selectDate(context, _nextAppointmentController),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Next appointment required' : null,
          ),
        ],
      ),
    );
  }
}