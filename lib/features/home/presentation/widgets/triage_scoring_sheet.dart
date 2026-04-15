// lib/features/home/presentation/widgets/triage_scoring_sheet.dart
//
// Triage Scoring Bottom Sheet — National Early Warning Score 2 (NEWS2)
//
// Nurses open this from the TriageQueueCard by tapping a "Score" button.
// It reads vitals already captured during check-in, computes the NEWS2 score,
// flags risk level, and lets the nurse update the Firestore record with the
// final score + recommended action.
//
// NEWS2 parameters scored:
//   Respiration rate  3/2/1/0 points
//   SpO₂ scale 1      3/2/1/0 points
//   Systolic BP        3/2/0/1/2/3 points
//   Pulse              3/1/0/1/2 points
//   Consciousness      0 (alert) or 3 (CVPU)
//   Temperature        3/1/0/1/2 points
//
// Risk bands:
//   0      → Low clinical risk
//   1–4    → Low–medium risk
//   5–6    → Medium risk (urgent review)
//   ≥7     → High risk (emergency review)
//   Any single parameter ≥3 → Low-medium risk escalation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/firebase_config.dart';

class TriageScoringSheet extends StatefulWidget {
  /// Firestore document ID of the triage_queue entry
  final String queueDocId;

  /// Current vitals snapshot from check-in
  final Map<String, dynamic> vitals;

  /// Patient name for display
  final String patientName;

  const TriageScoringSheet({
    super.key,
    required this.queueDocId,
    required this.vitals,
    required this.patientName,
  });

  static Future<void> show(
    BuildContext context, {
    required String queueDocId,
    required Map<String, dynamic> vitals,
    required String patientName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TriageScoringSheet(
        queueDocId:  queueDocId,
        vitals:      vitals,
        patientName: patientName,
      ),
    );
  }

  @override
  State<TriageScoringSheet> createState() => _TriageScoringSheetState();
}

class _TriageScoringSheetState extends State<TriageScoringSheet> {
  // Overridable parameters (default from vitals captured at check-in)
  late int?    _rrpm;    // respiration rate per minute
  late int?    _spo2;    // SpO₂ %
  late double? _temp;    // °C
  late int?    _sys;     // systolic BP mmHg
  late int?    _hr;      // heart rate bpm
  bool         _conscious = true;  // true = Alert, false = CVPU
  bool         _oxygen    = false; // on supplemental oxygen?
  bool         _saving    = false;

  final _rrCtrl   = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _sysCtrl  = TextEditingController();
  final _hrCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    final v   = widget.vitals;
    _rrpm     = (v['respiration_rate'] as num?)?.toInt();
    _spo2     = (v['oxygen_saturation'] as num?)?.toInt();
    _temp     = (v['temperature'] as num?)?.toDouble();
    _sys      = (v['systolic_bp']  as num?)?.toInt();
    _hr       = (v['pulse_rate']   as num?)?.toInt();

    if (_rrpm  != null) _rrCtrl.text   = '$_rrpm';
    if (_spo2  != null) _spo2Ctrl.text = '$_spo2';
    if (_temp  != null) _tempCtrl.text = '$_temp';
    if (_sys   != null) _sysCtrl.text  = '$_sys';
    if (_hr    != null) _hrCtrl.text   = '$_hr';
  }

  @override
  void dispose() {
    for (final c in [_rrCtrl, _spo2Ctrl, _tempCtrl, _sysCtrl, _hrCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── NEWS2 scoring ──────────────────────────────────────────────

  int get _rrScore {
    final r = _rrpm;
    if (r == null) return 0;
    if (r <= 8)  return 3;
    if (r <= 11) return 1;
    if (r <= 20) return 0;
    if (r <= 24) return 2;
    return 3;
  }

  int get _spo2Score {
    final s = _spo2;
    if (s == null) return 0;
    if (!_oxygen) {
      if (s >= 96) return 0;
      if (s >= 94) return 1;
      if (s >= 92) return 2;
      return 3;
    } else {
      // Scale 2 — on supplemental oxygen
      if (s >= 97) return 3;
      if (s >= 95) return 2;
      if (s >= 93) return 1;
      return 0;
    }
  }

  int get _tempScore {
    final t = _temp;
    if (t == null) return 0;
    if (t <= 35.0)  return 3;
    if (t <= 36.0)  return 1;
    if (t <= 38.0)  return 0;
    if (t <= 39.0)  return 1;
    return 2;
  }

  int get _sysScore {
    final s = _sys;
    if (s == null) return 0;
    if (s <= 90)  return 3;
    if (s <= 100) return 2;
    if (s <= 110) return 1;
    if (s <= 219) return 0;
    return 3;
  }

  int get _hrScore {
    final h = _hr;
    if (h == null) return 0;
    if (h <= 40)  return 3;
    if (h <= 50)  return 1;
    if (h <= 90)  return 0;
    if (h <= 110) return 1;
    if (h <= 130) return 2;
    return 3;
  }

  int get _consciousnessScore => _conscious ? 0 : 3;

  int get totalScore =>
      _rrScore + _spo2Score + _tempScore + _sysScore +
      _hrScore + _consciousnessScore;

  bool get _anyParameterAtThree =>
      _rrScore >= 3 || _spo2Score >= 3 || _tempScore >= 3 ||
      _sysScore >= 3 || _hrScore  >= 3 || _consciousnessScore >= 3;

  _RiskBand get riskBand {
    final s = totalScore;
    if (s == 0) {
      return const _RiskBand('Low Risk', Color(0xFF22C55E),
          'Routine monitoring. Reassess minimum 12-hourly.');
    }
    if (s <= 4 && !_anyParameterAtThree) {
      return const _RiskBand('Low–Medium Risk', Color(0xFF3B82F6),
          'Increased monitoring. Nurse to inform doctor. Reassess 4–6 hourly.');
    }
    if (s <= 6 || _anyParameterAtThree) {
      return const _RiskBand('Medium Risk', Color(0xFFF59E0B),
          'Urgent review by ward doctor. Consider higher level of care.');
    }
    return const _RiskBand('HIGH RISK 🚨', Color(0xFFEF4444),
        'Emergency assessment. Senior clinician NOW. Consider ICU referral.');
  }

  // ── Save to Firestore ──────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updatedVitals = {
        ...widget.vitals,
        if (_rrpm  != null) 'respiration_rate':  _rrpm,
        if (_spo2  != null) 'oxygen_saturation':  _spo2,
        if (_temp  != null) 'temperature':         _temp,
        if (_sys   != null) 'systolic_bp':         _sys,
        if (_hr    != null) 'pulse_rate':          _hr,
        'on_oxygen': _oxygen,
      };

      await FirebaseConfig.facilityDb
          .collection('triage_queue')
          .doc(widget.queueDocId)
          .update({
        'vitals':              updatedVitals,
        'news2_score':         totalScore,
        'news2_risk':          riskBand.label,
        'news2_scored_at':     FieldValue.serverTimestamp(),
        'updated_at':          FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, totalScore);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final band = riskBand;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize:     0.6,
      maxChildSize:     0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.monitor_heart_rounded,
                      color: Color(0xFF00796B), size: 20),
                  const SizedBox(width: 8),
                  const Text('NEWS2 Triage Score',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                Text(widget.patientName,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 13)),
              ]),
            ),

            // Score summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: band.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: band.color.withOpacity(0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: band.color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$totalScore',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(band.label,
                          style: TextStyle(
                              color: band.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(band.action,
                          style: const TextStyle(
                              color: Color(0xFF475569), fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),

            // Parameters
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  _SectionLabel('Vital Parameters'),
                  const SizedBox(height: 8),

                  _ScoredRow(
                    label: 'Respiration Rate',
                    unit: 'breaths/min',
                    controller: _rrCtrl,
                    score: _rrScore,
                    onChanged: (v) =>
                        setState(() => _rrpm = int.tryParse(v)),
                    icon: Icons.air_rounded,
                  ),
                  const SizedBox(height: 8),

                  _ScoredRow(
                    label: 'SpO₂',
                    unit: '%',
                    controller: _spo2Ctrl,
                    score: _spo2Score,
                    onChanged: (v) =>
                        setState(() => _spo2 = int.tryParse(v)),
                    icon: Icons.bloodtype_rounded,
                  ),
                  const SizedBox(height: 8),

                  _ScoredRow(
                    label: 'Temperature',
                    unit: '°C',
                    controller: _tempCtrl,
                    score: _tempScore,
                    onChanged: (v) =>
                        setState(() => _temp = double.tryParse(v)),
                    icon: Icons.thermostat_rounded,
                    decimal: true,
                  ),
                  const SizedBox(height: 8),

                  _ScoredRow(
                    label: 'Systolic BP',
                    unit: 'mmHg',
                    controller: _sysCtrl,
                    score: _sysScore,
                    onChanged: (v) =>
                        setState(() => _sys = int.tryParse(v)),
                    icon: Icons.favorite_rounded,
                  ),
                  const SizedBox(height: 8),

                  _ScoredRow(
                    label: 'Heart Rate / Pulse',
                    unit: 'bpm',
                    controller: _hrCtrl,
                    score: _hrScore,
                    onChanged: (v) =>
                        setState(() => _hr = int.tryParse(v)),
                    icon: Icons.timeline_rounded,
                  ),
                  const SizedBox(height: 16),

                  _SectionLabel('Clinical Assessment'),
                  const SizedBox(height: 8),

                  // Consciousness
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.psychology_rounded,
                              size: 16, color: Color(0xFF00796B)),
                          const SizedBox(width: 6),
                          const Text('Consciousness',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const Spacer(),
                          _ScoreBadge(_consciousnessScore),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: _ToggleButton(
                              label: 'Alert',
                              selected: _conscious,
                              color: Colors.green,
                              onTap: () =>
                                  setState(() => _conscious = true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ToggleButton(
                              label: 'CVPU',
                              selected: !_conscious,
                              color: Colors.red,
                              onTap: () =>
                                  setState(() => _conscious = false),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Supplemental oxygen
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.air_outlined,
                          size: 16, color: Color(0xFF00796B)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('Supplemental Oxygen',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                      Switch.adaptive(
                        value: _oxygen,
                        activeColor: const Color(0xFF00796B),
                        onChanged: (v) =>
                            setState(() => _oxygen = v),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // Save button
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Save NEWS2 Score ($totalScore)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scored parameter row ────────────────────────────────────────────────────

class _ScoredRow extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final int score;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final bool decimal;

  const _ScoredRow({
    required this.label,
    required this.unit,
    required this.controller,
    required this.score,
    required this.onChanged,
    required this.icon,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF00796B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: decimal),
                onChanged: onChanged,
                decoration: InputDecoration(
                  suffixText: unit,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: Color(0xFF00796B), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ScoreBadge(score),
      ]),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge(this.score);

  Color get _color {
    if (score == 0) return Colors.grey;
    if (score <= 2) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: _color.withOpacity(score == 0 ? 0.08 : 0.12),
      shape: BoxShape.circle,
      border: Border.all(color: _color.withOpacity(0.3)),
    ),
    child: Center(
      child: Text(
        '$score',
        style: TextStyle(
            color: _color,
            fontWeight: FontWeight.w900,
            fontSize: 13),
      ),
    ),
  );
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool   selected;
  final Color  color;
  final VoidCallback onTap;
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? color : Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w700,
              fontSize: 13),
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.8),
  );
}

// ── Risk band ──────────────────────────────────────────────────────────────

class _RiskBand {
  final String label;
  final Color  color;
  final String action;
  const _RiskBand(this.label, this.color, this.action);
}