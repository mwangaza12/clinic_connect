import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/fhir/fhir_mapper.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../encounter/domain/entities/encounter.dart';
import '../../../encounter/presentation/bloc/encounter_bloc.dart';
import '../../../encounter/presentation/bloc/encounter_event.dart';
import '../../../encounter/presentation/bloc/encounter_state.dart';
import '../../../patient/domain/entities/patient.dart';
import '../../../referral/domain/entities/referral.dart';
import '../../../referral/presentation/bloc/referral_bloc.dart';
import '../../../referral/presentation/bloc/referral_event.dart';
import '../../../referral/presentation/bloc/referral_state.dart';

class FhirExportPage extends StatelessWidget {
  final Patient patient;

  const FhirExportPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final facilityId = authState is Authenticated
        ? authState.user.facilityId
        : '';

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<EncounterBloc>()
            ..add(LoadPatientEncountersEvent(patient.id)),
        ),
        BlocProvider(
          create: (_) => sl<ReferralBloc>()
            ..add(LoadReferralsEvent(facilityId)),
        ),
      ],
      child: _FhirExportView(patient: patient),
    );
  }
}

class _FhirExportView extends StatefulWidget {
  final Patient patient;
  const _FhirExportView({required this.patient});

  @override
  State<_FhirExportView> createState() => _FhirExportViewState();
}

class _FhirExportViewState extends State<_FhirExportView> {
  String? _generatedJson;
  Map<String, dynamic>? _bundle;
  bool _isGenerating = false;
  String _selectedView = 'summary';

  final Color primary = const Color(0xFF1B4332);

  void _generateBundle(
      List<Encounter> encounters, List<Referral> referrals) {
    setState(() => _isGenerating = true);

    // Filter referrals for this patient
    final patientReferrals = referrals
        .where((r) => r.patientNupi == widget.patient.nupi)
        .toList();

    final bundle = FhirMapper.toFhirBundle(
      patient: widget.patient,
      encounters: encounters,
      referrals: patientReferrals,
    );

    final errors = FhirMapper.validateBundle(bundle);

    setState(() {
      _bundle = bundle;
      _generatedJson = FhirMapper.toJson(bundle);
      _isGenerating = false;
    });

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Validation warnings: ${errors.join(', ')}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _copyToClipboard() {
    if (_generatedJson == null) return;
    Clipboard.setData(ClipboardData(text: _generatedJson!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ FHIR Bundle copied to clipboard'),
        backgroundColor: Color(0xFF2D6A4F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text(
          'FHIR R4 Export',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_generatedJson != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy JSON',
              onPressed: _copyToClipboard,
            ),
        ],
      ),
      body: BlocBuilder<EncounterBloc, EncounterState>(
        builder: (context, encounterState) {
          return BlocBuilder<ReferralBloc, ReferralState>(
            builder: (context, referralState) {
              final encounters = encounterState is EncountersLoaded
                  ? encounterState.encounters
                  : <Encounter>[];
              final referrals = referralState is ReferralsLoaded
                  ? [
                      ...referralState.outgoing,
                      ...referralState.incoming,
                    ]
                  : <Referral>[];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Header
                    _buildPatientHeader(),
                    const SizedBox(height: 20),

                    // Bundle Contents Preview
                    _buildContentsCard(encounters, referrals),
                    const SizedBox(height: 20),

                    // Generate Button
                    if (_bundle == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating
                              ? null
                              : () => _generateBundle(
                                  encounters, referrals),
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome_rounded),
                          label: Text(
                            _isGenerating
                                ? 'Generating...'
                                : 'Generate FHIR R4 Bundle',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                    // Generated Bundle View
                    if (_bundle != null) ...[
                      _buildBundleStats(),
                      const SizedBox(height: 16),
                      _buildViewToggle(),
                      const SizedBox(height: 16),
                      _selectedView == 'summary'
                          ? _buildSummaryView()
                          : _buildJsonView(),
                      const SizedBox(height: 16),
                      _buildActions(),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            radius: 30,
            child: Text(
              widget.patient.firstName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _headerChip('NUPI: ${widget.patient.nupi}'),
                    const SizedBox(width: 8),
                    _headerChip(
                        '${widget.patient.age} yrs • ${widget.patient.gender}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildContentsCard(
      List<Encounter> encounters, List<Referral> referrals) {
    final patientReferrals = referrals
        .where((r) => r.patientNupi == widget.patient.nupi)
        .toList();

    int vitalsCount = encounters
        .where((e) => e.vitals != null)
        .fold(0, (sum, e) => sum + FhirMapper.toFhirObservations(
              e.vitals!, e.id, widget.patient.id).length);

    int conditionsCount = encounters
        .fold(0, (sum, e) => sum + e.diagnoses.length);

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
          const Text(
            'BUNDLE WILL CONTAIN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _resourceChip(
                  '1', 'Patient', Icons.person_rounded,
                  const Color(0xFF6366F1)),
              _resourceChip(
                  '${encounters.length}', 'Encounters',
                  Icons.medical_services_rounded,
                  const Color(0xFF2D6A4F)),
              _resourceChip(
                  '$vitalsCount', 'Observations',
                  Icons.monitor_heart_rounded,
                  const Color(0xFF0EA5E9)),
              _resourceChip(
                  '$conditionsCount', 'Conditions',
                  Icons.sick_rounded,
                  const Color(0xFFF59E0B)),
              _resourceChip(
                  '${patientReferrals.length}', 'ServiceRequests',
                  Icons.send_rounded,
                  const Color(0xFFE11D48)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resourceChip(
      String count, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundleStats() {
    if (_bundle == null) return const SizedBox();
    final entries = (_bundle!['entry'] as List).length;
    final errors = FhirMapper.validateBundle(_bundle!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errors.isEmpty
            ? const Color(0xFF2D6A4F).withOpacity(0.08)
            : Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: errors.isEmpty
              ? const Color(0xFF2D6A4F).withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            errors.isEmpty
                ? Icons.check_circle_rounded
                : Icons.warning_rounded,
            color: errors.isEmpty
                ? const Color(0xFF2D6A4F)
                : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errors.isEmpty
                      ? 'Valid FHIR R4 Bundle'
                      : 'Bundle with warnings',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: errors.isEmpty
                        ? const Color(0xFF2D6A4F)
                        : Colors.orange,
                  ),
                ),
                Text(
                  '$entries FHIR resources • HL7 FHIR R4 compliant',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedView = 'summary'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedView == 'summary'
                      ? primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Summary View',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _selectedView == 'summary'
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedView = 'json'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedView == 'json'
                      ? primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Raw JSON',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _selectedView == 'json'
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    if (_bundle == null) return const SizedBox();
    final entries = _bundle!['entry'] as List;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final type =
          entry['resource']['resourceType'] as String;
      grouped.putIfAbsent(type, () => []).add(
          Map<String, dynamic>.from(entry['resource']));
    }

    return Column(
      children: grouped.entries.map((group) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFE2E8F0)),
          ),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getResourceIcon(group.key),
                color: primary,
                size: 20,
              ),
            ),
            title: Text(
              group.key,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              '${group.value.length} resource${group.value.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            children: group.value
                .map((resource) => _buildResourceTile(resource))
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResourceTile(Map<String, dynamic> resource) {
    final type = resource['resourceType'] as String;
    String subtitle = '';

    switch (type) {
      case 'Patient':
        subtitle =
            'NUPI: ${(resource['identifier'] as List?)?.first?['value'] ?? 'N/A'}';
        break;
      case 'Encounter':
        subtitle =
            'Status: ${resource['status']} • ${resource['class']?['display']}';
        break;
      case 'Observation':
        subtitle =
            resource['code']?['coding']?[0]?['display'] ?? '';
        break;
      case 'Condition':
        subtitle =
            resource['code']?['coding']?[0]?['display'] ?? '';
        break;
      case 'ServiceRequest':
        subtitle =
            'Priority: ${resource['priority']} • ${resource['status']}';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              resource['id']?.toString().substring(0, 8) ??
                  '',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FHIR R4 Bundle JSON',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _copyToClipboard,
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded,
                        color: Color(0xFF64748B), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // Show first 3000 chars to avoid performance issues
            _generatedJson!.length > 3000
                ? '${_generatedJson!.substring(0, 3000)}\n\n... (${_generatedJson!.length} chars total - copy to see full bundle)'
                : _generatedJson!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF86EFAC),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _bundle = null;
                _generatedJson = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Regenerate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.file_download_rounded),
            label: const Text(
              'Export Bundle',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getResourceIcon(String resourceType) {
    switch (resourceType) {
      case 'Patient':
        return Icons.person_rounded;
      case 'Encounter':
        return Icons.medical_services_rounded;
      case 'Observation':
        return Icons.monitor_heart_rounded;
      case 'Condition':
        return Icons.sick_rounded;
      case 'ServiceRequest':
        return Icons.send_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}