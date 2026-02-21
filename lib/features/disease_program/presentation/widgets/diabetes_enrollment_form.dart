// lib/features/disease_program/presentation/widgets/diabetes_enrollment_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DiabetesEnrollmentForm extends StatefulWidget {
  const DiabetesEnrollmentForm({super.key, required void Function(dynamic data) onDataChanged});

  @override
  State<DiabetesEnrollmentForm> createState() => _DiabetesEnrollmentFormState();
}

class _DiabetesEnrollmentFormState extends State<DiabetesEnrollmentForm> {
  final _diagnosisDateController = TextEditingController();
  final _hba1cController = TextEditingController();
  final _fbsController = TextEditingController();
  final _rbsController = TextEditingController();
  final _medicationController = TextEditingController();
  final _insulinRegimenController = TextEditingController();
  final _nextAppointmentController = TextEditingController();

  String? _diabetesType;
  bool _onInsulin = false;

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _hba1cController.dispose();
    _fbsController.dispose();
    _rbsController.dispose();
    _medicationController.dispose();
    _insulinRegimenController.dispose();
    _nextAppointmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Diabetes Program Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<String>(
            value: _diabetesType,
            decoration: const InputDecoration(labelText: 'Diabetes Type *', border: OutlineInputBorder()),
            items: ['Type 1', 'Type 2', 'Gestational'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
            onChanged: (value) => setState(() => _diabetesType = value),
            validator: (value) => value == null ? 'Type required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _diagnosisDateController,
            decoration: const InputDecoration(labelText: 'Diagnosis Date *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _diagnosisDateController),
            validator: (value) => value?.isEmpty ?? true ? 'Date required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _hba1cController,
            decoration: const InputDecoration(labelText: 'HbA1c (%)', border: OutlineInputBorder(), helperText: 'Target: <7%'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: TextFormField(
                controller: _fbsController,
                decoration: const InputDecoration(labelText: 'FBS (mg/dL)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _rbsController,
                decoration: const InputDecoration(labelText: 'RBS (mg/dL)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              )),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _medicationController,
            decoration: const InputDecoration(labelText: 'Medication', border: OutlineInputBorder(), hintText: 'e.g., Metformin 500mg BD'),
          ),
          const SizedBox(height: 16),
          
          CheckboxListTile(
            title: const Text('On Insulin'),
            value: _onInsulin,
            onChanged: (value) => setState(() => _onInsulin = value ?? false),
            contentPadding: EdgeInsets.zero,
          ),
          
          if (_onInsulin) ...[
            TextFormField(
              controller: _insulinRegimenController,
              decoration: const InputDecoration(labelText: 'Insulin Regimen', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
          ],
          
          TextFormField(
            controller: _nextAppointmentController,
            decoration: const InputDecoration(labelText: 'Next Appointment *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _nextAppointmentController),
            validator: (value) => value?.isEmpty ?? true ? 'Appointment required' : null,
          ),
        ],
      ),
    );
  }
}

// ==================== HYPERTENSION ====================
class HypertensionEnrollmentForm extends StatefulWidget {
  const HypertensionEnrollmentForm({super.key, required void Function(dynamic data) onDataChanged});

  @override
  State<HypertensionEnrollmentForm> createState() => _HypertensionEnrollmentFormState();
}

class _HypertensionEnrollmentFormState extends State<HypertensionEnrollmentForm> {
  final _diagnosisDateController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _medicationController = TextEditingController();
  final _nextAppointmentController = TextEditingController();
  
  String? _stage;

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _medicationController.dispose();
    _nextAppointmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Hypertension Program', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          
          TextFormField(
            controller: _diagnosisDateController,
            decoration: const InputDecoration(labelText: 'Diagnosis Date *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _diagnosisDateController),
            validator: (value) => value?.isEmpty ?? true ? 'Date required' : null,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: TextFormField(
                controller: _systolicController,
                decoration: const InputDecoration(labelText: 'Systolic (mmHg) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _diastolicController,
                decoration: const InputDecoration(labelText: 'Diastolic (mmHg) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              )),
            ],
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _stage,
            decoration: const InputDecoration(labelText: 'Stage', border: OutlineInputBorder()),
            items: ['Stage 1 (130-139/80-89)', 'Stage 2 (≥140/≥90)', 'Hypertensive Crisis (>180/>120)']
                .map((stage) => DropdownMenuItem(value: stage, child: Text(stage, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (value) => setState(() => _stage = value),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _medicationController,
            decoration: const InputDecoration(labelText: 'Medication', border: OutlineInputBorder(), hintText: 'e.g., Amlodipine 5mg OD'),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _nextAppointmentController,
            decoration: const InputDecoration(labelText: 'Next Appointment *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _nextAppointmentController),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}

// ==================== MALARIA ====================
class MalariaEnrollmentForm extends StatefulWidget {
  const MalariaEnrollmentForm({super.key, required void Function(dynamic data) onDataChanged});

  @override
  State<MalariaEnrollmentForm> createState() => _MalariaEnrollmentFormState();
}

class _MalariaEnrollmentFormState extends State<MalariaEnrollmentForm> {
  final _symptomsDateController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _followUpController = TextEditingController();
  
  String? _testType;
  String? _severity;

  @override
  void dispose() {
    _symptomsDateController.dispose();
    _treatmentController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bug_report, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Malaria Treatment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          
          TextFormField(
            controller: _symptomsDateController,
            decoration: const InputDecoration(labelText: 'Symptoms Start Date *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _symptomsDateController),
            validator: (value) => value?.isEmpty ?? true ? 'Date required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _testType,
            decoration: const InputDecoration(labelText: 'Test Type *', border: OutlineInputBorder()),
            items: ['RDT (Rapid Diagnostic Test)', 'Microscopy'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
            onChanged: (value) => setState(() => _testType = value),
            validator: (value) => value == null ? 'Test type required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _severity,
            decoration: const InputDecoration(labelText: 'Severity *', border: OutlineInputBorder()),
            items: ['Uncomplicated', 'Severe'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (value) => setState(() => _severity = value),
            validator: (value) => value == null ? 'Severity required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _treatmentController,
            decoration: const InputDecoration(labelText: 'Treatment *', border: OutlineInputBorder(), hintText: 'e.g., AL (Artemether-Lumefantrine)'),
            validator: (value) => value?.isEmpty ?? true ? 'Treatment required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _followUpController,
            decoration: const InputDecoration(labelText: 'Follow-up Date *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _followUpController),
            validator: (value) => value?.isEmpty ?? true ? 'Follow-up required' : null,
          ),
        ],
      ),
    );
  }
}

// ==================== TB ====================
class TbEnrollmentForm extends StatefulWidget {
  const TbEnrollmentForm({super.key, required void Function(dynamic data) onDataChanged});

  @override
  State<TbEnrollmentForm> createState() => _TbEnrollmentFormState();
}

class _TbEnrollmentFormState extends State<TbEnrollmentForm> {
  final _diagnosisDateController = TextEditingController();
  final _treatmentStartController = TextEditingController();
  final _dotProviderController = TextEditingController();
  final _nextAppointmentController = TextEditingController();
  
  String? _tbType;
  String? _category;

  @override
  void dispose() {
    _diagnosisDateController.dispose();
    _treatmentStartController.dispose();
    _dotProviderController.dispose();
    _nextAppointmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.coronavirus, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('TB Program', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          
          TextFormField(
            controller: _diagnosisDateController,
            decoration: const InputDecoration(labelText: 'Diagnosis Date *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _diagnosisDateController),
            validator: (value) => value?.isEmpty ?? true ? 'Date required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _tbType,
            decoration: const InputDecoration(labelText: 'TB Type *', border: OutlineInputBorder()),
            items: ['Pulmonary TB', 'Extra-pulmonary TB'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
            onChanged: (value) => setState(() => _tbType = value),
            validator: (value) => value == null ? 'Type required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
            items: ['New', 'Relapse', 'Treatment Failure', 'MDR-TB'].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (value) => setState(() => _category = value),
            validator: (value) => value == null ? 'Category required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _treatmentStartController,
            decoration: const InputDecoration(labelText: 'Treatment Start Date *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _treatmentStartController),
            validator: (value) => value?.isEmpty ?? true ? 'Date required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _dotProviderController,
            decoration: const InputDecoration(labelText: 'DOT Provider', border: OutlineInputBorder(), helperText: 'Directly Observed Therapy Provider'),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _nextAppointmentController,
            decoration: const InputDecoration(labelText: 'Next Appointment *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _nextAppointmentController),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}

// ==================== MCH ====================
class MchEnrollmentForm extends StatefulWidget {
  const MchEnrollmentForm({super.key, required void Function(dynamic data) onDataChanged});

  @override
  State<MchEnrollmentForm> createState() => _MchEnrollmentFormState();
}

class _MchEnrollmentFormState extends State<MchEnrollmentForm> {
  final _lmpController = TextEditingController();
  final _eddController = TextEditingController();
  final _gravidaController = TextEditingController();
  final _parityController = TextEditingController();
  final _nextAncController = TextEditingController();
  
  String? _programType;
  String? _hivStatus;
  bool _onPmtct = false;

  @override
  void dispose() {
    _lmpController.dispose();
    _eddController.dispose();
    _gravidaController.dispose();
    _parityController.dispose();
    _nextAncController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.child_care, color: Colors.pink, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('MCH Program', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<String>(
            value: _programType,
            decoration: const InputDecoration(labelText: 'Program Type *', border: OutlineInputBorder()),
            items: ['Antenatal Care (ANC)', 'Postnatal Care (PNC)', 'Child Wellness'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
            onChanged: (value) => setState(() => _programType = value),
            validator: (value) => value == null ? 'Type required' : null,
          ),
          const SizedBox(height: 16),
          
          if (_programType == 'Antenatal Care (ANC)') ...[
            TextFormField(
              controller: _lmpController,
              decoration: const InputDecoration(labelText: 'Last Menstrual Period (LMP) *', border: OutlineInputBorder()),
              readOnly: true,
              onTap: () => _selectDate(context, _lmpController),
              validator: (value) => value?.isEmpty ?? true ? 'LMP required' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _eddController,
              decoration: const InputDecoration(labelText: 'Expected Delivery Date (EDD) *', border: OutlineInputBorder()),
              readOnly: true,
              onTap: () => _selectDate(context, _eddController),
              validator: (value) => value?.isEmpty ?? true ? 'EDD required' : null,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _gravidaController,
                  decoration: const InputDecoration(labelText: 'Gravida', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _parityController,
                  decoration: const InputDecoration(labelText: 'Parity', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                )),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          DropdownButtonFormField<String>(
            value: _hivStatus,
            decoration: const InputDecoration(labelText: 'HIV Status', border: OutlineInputBorder()),
            items: ['Negative', 'Positive', 'Unknown'].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
            onChanged: (value) => setState(() => _hivStatus = value),
          ),
          const SizedBox(height: 16),
          
          if (_hivStatus == 'Positive')
            CheckboxListTile(
              title: const Text('On PMTCT'),
              subtitle: const Text('Prevention of Mother-to-Child Transmission', style: TextStyle(fontSize: 11)),
              value: _onPmtct,
              onChanged: (value) => setState(() => _onPmtct = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
          
          TextFormField(
            controller: _nextAncController,
            decoration: const InputDecoration(labelText: 'Next Visit Date *', border: OutlineInputBorder()),
            readOnly: true,
            onTap: () => _selectDate(context, _nextAncController),
            validator: (value) => value?.isEmpty ?? true ? 'Visit date required' : null,
          ),
        ],
      ),
    );
  }
}