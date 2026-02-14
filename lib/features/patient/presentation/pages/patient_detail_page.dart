import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../../encounter/domain/entities/encounter.dart';
import '../../../encounter/presentation/bloc/encounter_bloc.dart';
import '../../../encounter/presentation/bloc/encounter_event.dart';
import '../../../encounter/presentation/bloc/encounter_state.dart';
import '../../../encounter/presentation/pages/create_encounter_page.dart';
import '../../../encounter/presentation/pages/encounter_detail_page.dart';
import '../../domain/entities/patient.dart';
import '../../../fhir/presentation/pages/fhir_export_page.dart';

class PatientDetailPage extends StatelessWidget {
  final Patient patient;
  const PatientDetailPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EncounterBloc>()
        ..add(LoadPatientEncountersEvent(patient.id)),
      child: _PatientDetailView(patient: patient),
    );
  }
}

class _PatientDetailView extends StatefulWidget {
  final Patient patient;
  const _PatientDetailView({required this.patient});

  @override
  State<_PatientDetailView> createState() => _PatientDetailViewState();
}

class _PatientDetailViewState extends State<_PatientDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _primary = Color(0xFF1B4332);
  static const Color _bg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Compact Fixed Header ──────────────────
            _buildHeader(context, p),

            // ── Tab Bar ───────────────────────────────
            _buildTabBar(),

            // ── Tab Content ───────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ProfileTab(patient: p),
                  _VisitHistoryTab(patient: p),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateEncounterPage(patient: p),
            ),
          );
          if (created == true && context.mounted) {
            context
                .read<EncounterBloc>()
                .add(LoadPatientEncountersEvent(p.id));
          }
        },
        backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Visit',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Header — compact, information-dense
  // ─────────────────────────────────────────
  Widget _buildHeader(BuildContext context, Patient p) {
    final initials = '${p.firstName[0]}${p.lastName[0]}'.toUpperCase();
    final genderColor = p.gender == 'female'
        ? const Color(0xFFEC4899)
        : const Color(0xFF3B82F6);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Top row: back + actions
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: _primary),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              _actionIcon(Icons.edit_outlined, 'Edit', () {}),
              const SizedBox(width: 8),
              _actionIcon(Icons.share_outlined, 'Share', () {}),
              const SizedBox(width: 8),
              _actionIcon(Icons.more_vert_rounded, 'More', () {}),
            ],
          ),
          const SizedBox(height: 12),

          // Patient identity row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with gender color ring
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: genderColor, width: 3),
                ),
                child: CircleAvatar(
                  backgroundColor: _primary.withOpacity(0.08),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + identifiers
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _identifierChip(
                          Icons.fingerprint_rounded,
                          p.nupi,
                          const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 6),
                        _identifierChip(
                          p.gender == 'female'
                              ? Icons.female_rounded
                              : Icons.male_rounded,
                          '${p.age}y ${p.gender[0].toUpperCase()}',
                          genderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${p.county} County',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.phone_outlined,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          p.phoneNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats strip
          BlocBuilder<EncounterBloc, EncounterState>(
            builder: (context, state) {
              final visitCount = state is EncountersLoaded
                  ? state.encounters.length
                  : 0;

              // Last visit date
              String lastVisit = 'None';
              if (state is EncountersLoaded &&
                  state.encounters.isNotEmpty) {
                lastVisit = DateFormat('dd MMM')
                    .format(state.encounters.first.encounterDate);
              }

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _primary.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    _statCell(
                      '$visitCount',
                      'Visits',
                      Icons.medical_services_outlined,
                      const Color(0xFF6366F1),
                    ),
                    _statDivider(),
                    _statCell(
                      p.bloodGroup ?? 'N/A',
                      'Blood',
                      Icons.bloodtype_outlined,
                      const Color(0xFFE11D48),
                    ),
                    _statDivider(),
                    _statCell(
                      lastVisit,
                      'Last Visit',
                      Icons.calendar_today_outlined,
                      const Color(0xFF2D6A4F),
                    ),
                    _statDivider(),
                    _statCell(
                      p.chronicConditions.isNotEmpty
                          ? '${p.chronicConditions.length}'
                          : '0',
                      'Conditions',
                      Icons.health_and_safety_outlined,
                      const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _identifierChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 36,
      color: _primary.withOpacity(0.1),
    );
  }

  Widget _actionIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _primary),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Tab Bar
  // ─────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _primary,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: _primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline_rounded, size: 16),
                SizedBox(width: 6),
                Text('Profile'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_edu_rounded, size: 16),
                SizedBox(width: 6),
                Text('Visit History'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final Patient patient;
  const _ProfileTab({required this.patient});

  static const Color _accent = Color(0xFF2D6A4F);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alerts banner (allergies / chronic conditions)
          if (patient.allergies.isNotEmpty ||
              patient.chronicConditions.isNotEmpty)
            _alertsBanner(),

          const SizedBox(height: 12),
          _sectionCard(
            title: 'Personal Information',
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF6366F1),
            rows: [
              _InfoRow(Icons.fingerprint, 'NUPI', patient.nupi),
              _InfoRow(Icons.badge_outlined, 'Full Name',
                  patient.fullName),
              _InfoRow(
                  Icons.calendar_today_outlined,
                  'Date of Birth',
                  DateFormat('dd MMMM yyyy')
                      .format(patient.dateOfBirth)),
              _InfoRow(Icons.phone_outlined, 'Phone',
                  patient.phoneNumber),
              if (patient.email != null)
                _InfoRow(Icons.email_outlined, 'Email',
                    patient.email!),
              if (patient.bloodGroup != null)
                _InfoRow(Icons.bloodtype_outlined, 'Blood Group',
                    patient.bloodGroup!),
            ],
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: 'Residential Address',
            icon: Icons.location_on_outlined,
            iconColor: const Color(0xFF0EA5E9),
            rows: [
              _InfoRow(Icons.map_outlined, 'County', patient.county),
              _InfoRow(Icons.location_city_outlined, 'Sub-County',
                  patient.subCounty),
              _InfoRow(
                  Icons.explore_outlined, 'Ward', patient.ward),
              _InfoRow(
                  Icons.home_outlined, 'Village', patient.village),
            ],
          ),

          if (patient.nextOfKinName != null) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Next of Kin',
              icon: Icons.contacts_outlined,
              iconColor: const Color(0xFFF59E0B),
              rows: [
                _InfoRow(Icons.person_outline, 'Name',
                    patient.nextOfKinName!),
                if (patient.nextOfKinPhone != null)
                  _InfoRow(Icons.phone_outlined, 'Phone',
                      patient.nextOfKinPhone!),
                if (patient.nextOfKinRelationship != null)
                  _InfoRow(Icons.people_outline, 'Relationship',
                      patient.nextOfKinRelationship!),
              ],
            ),
          ],

          // Clinical quick actions
          const SizedBox(height: 16),
          _sectionLabel('Clinical Actions'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _clinicalAction(
                  context,
                  Icons.send_rounded,
                  'Refer',
                  const Color(0xFFF59E0B),
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Go to Referrals tab')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _clinicalAction(
                  context,
                  Icons.science_outlined,
                  'Lab Order',
                  const Color(0xFF6366F1),
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _clinicalAction(
                  context,
                  Icons.medication_outlined,
                  'Prescribe',
                  const Color(0xFF0EA5E9),
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FhirExportPage(patient: patient),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B4332).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1B4332).withOpacity(0.2),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.file_download_rounded,
                          color: Color(0xFF1B4332), size: 24),
                      SizedBox(height: 8),
                      Text(
                        'FHIR Export',
                        style: TextStyle(
                          color: Color(0xFF1B4332),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertsBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: Color(0xFFF59E0B)),
              SizedBox(width: 6),
              Text(
                'CLINICAL ALERTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (patient.allergies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Allergies: ${patient.allergies.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (patient.chronicConditions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Chronic: ${patient.chronicConditions.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_InfoRow> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Rows
          ...rows.asMap().entries.map(
                (entry) => Column(
                  children: [
                    _buildRow(entry.value),
                    if (entry.key < rows.length - 1)
                      const Divider(
                        height: 1,
                        indent: 52,
                        color: Color(0xFFF1F5F9),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildRow(_InfoRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(row.icon, size: 16, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  row.value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clinicalAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}

// ─────────────────────────────────────────
// Visit History Tab
// ─────────────────────────────────────────
class _VisitHistoryTab extends StatelessWidget {
  final Patient patient;
  const _VisitHistoryTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EncounterBloc, EncounterState>(
      builder: (context, state) {
        if (state is EncounterLoading) {
          return const Center(
              child: CircularProgressIndicator.adaptive());
        }

        if (state is EncounterError) {
          return _buildError(context, state.message);
        }

        if (state is EncountersLoaded) {
          if (state.encounters.isEmpty) return _buildEmpty();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: state.encounters.length,
            itemBuilder: (context, index) {
              final encounter = state.encounters[index];
              return _encounterCard(context, encounter, index);
            },
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _encounterCard(
      BuildContext context, Encounter encounter, int index) {
    final typeColor = encounter.type == EncounterType.emergency
        ? const Color(0xFFE11D48)
        : encounter.type == EncounterType.inpatient
            ? const Color(0xFF6366F1)
            : encounter.type == EncounterType.referral
                ? const Color(0xFFF59E0B)
                : const Color(0xFF2D6A4F);

    final primaryDx = encounter.diagnoses
        .where((d) => d.isPrimary)
        .firstOrNull;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EncounterDetailPage(encounter: encounter),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Color strip + icon
              Container(
                width: 52,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      encounter.type == EncounterType.emergency
                          ? Icons.emergency_rounded
                          : encounter.type ==
                                  EncounterType.inpatient
                              ? Icons.bed_outlined
                              : Icons.chair_alt_outlined,
                      color: typeColor,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd\nMMM')
                          .format(encounter.encounterDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: typeColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge + time
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              encounter.type.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(
                                encounter.encounterDate),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Chief complaint
                      Text(
                        encounter.chiefComplaint ??
                            'No chief complaint recorded',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Primary diagnosis
                      if (primaryDx != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1)
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                primaryDx.code,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                primaryDx.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Vitals row
                      if (encounter.vitals != null)
                        _vitalsStrip(encounter.vitals!),

                      // Footer
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 12,
                                  color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                encounter.clinicianName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          if (encounter.disposition != null)
                            _dispositionBadge(
                                encounter.disposition!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Chevron
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vitalsStrip(Vitals vitals) {
    final items = <Map<String, dynamic>>[];

    if (vitals.bpDisplay != null) {
      items.add({
        'icon': Icons.favorite_outline,
        'value': vitals.bpDisplay!,
        'color': const Color(0xFFE11D48),
      });
    }
    if (vitals.temperature != null) {
      items.add({
        'icon': Icons.thermostat_outlined,
        'value': '${vitals.temperature}°C',
        'color': const Color(0xFFF59E0B),
      });
    }
    if (vitals.oxygenSaturation != null) {
      items.add({
        'icon': Icons.air_outlined,
        'value': '${vitals.oxygenSaturation}%',
        'color': const Color(0xFF0EA5E9),
      });
    }
    if (vitals.pulseRate != null) {
      items.add({
        'icon': Icons.monitor_heart_outlined,
        'value': '${vitals.pulseRate}bpm',
        'color': const Color(0xFF8B5CF6),
      });
    }

    if (items.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items
          .take(3)
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (item['color'] as Color).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 10,
                      color: item['color'] as Color,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item['value'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: item['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _dispositionBadge(Disposition disposition) {
    final color = disposition == Disposition.discharged
        ? const Color(0xFF2D6A4F)
        : disposition == Disposition.admitted
            ? const Color(0xFF6366F1)
            : disposition == Disposition.referred
                ? const Color(0xFFF59E0B)
                : const Color(0xFFE11D48);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        disposition.name.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              size: 48,
              color: Color(0xFF2D6A4F),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Visits Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "New Visit" to record\nthe first encounter',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Color(0xFFE11D48)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context
                .read<EncounterBloc>()
                .add(LoadPatientEncountersEvent(patient.id)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4332),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}