// lib/features/disease_program/presentation/pages/program_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../../patient/data/datasources/patient_local_datasource.dart';
import '../../../patient/domain/entities/patient.dart';
import '../../../patient/presentation/bloc/patient_bloc.dart';
import '../../../patient/presentation/bloc/patient_event.dart';
import '../../../patient/presentation/bloc/patient_state.dart';
import '../../domain/entities/disease_program.dart';
import '../bloc/program_bloc.dart';
import '../bloc/program_event.dart';
import '../bloc/program_state.dart';
import 'enroll_patient_page.dart';
import 'enrollment_detail_page.dart';

class ProgramDashboardPage extends StatefulWidget {
  final String facilityId;
  final DiseaseProgram? initialFilter; // Optional initial filter

  const ProgramDashboardPage({
    super.key,
    required this.facilityId,
    this.initialFilter, // Optional
  });

  @override
  State<ProgramDashboardPage> createState() => _ProgramDashboardPageState();
}

class _ProgramDashboardPageState extends State<ProgramDashboardPage> {
  DiseaseProgram? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter; // Set initial filter if provided
    context.read<ProgramBloc>().add(LoadFacilityEnrollments(widget.facilityId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Disease Programs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              context.read<ProgramBloc>().add(LoadFacilityEnrollments(widget.facilityId));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickPatientAndEnroll,
        backgroundColor: const Color(0xFF2D6A4F),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          'Enroll Patient',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: BlocBuilder<ProgramBloc, ProgramState>(
        builder: (context, state) {
          if (state is ProgramLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProgramError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ProgramBloc>().add(LoadFacilityEnrollments(widget.facilityId));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is EnrollmentsLoaded) {
            final enrollments = state.enrollments;

            // Filter by program if selected
            final filteredEnrollments = _selectedFilter != null
                ? enrollments.where((e) => e.program == _selectedFilter).toList()
                : enrollments;

            // Calculate stats
            final stats = _calculateStats(enrollments);

            // Single CustomScrollView — header and list scroll together.
            // No Column+Expanded so there is nothing to overflow on small screens.
            return CustomScrollView(
              slivers: [
                // Stats + filter header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    color: Colors.white,
                    child: Column(
                      children: [
                        _buildStatsGrid(stats),
                        const SizedBox(height: 12),
                        _buildProgramFilter(),
                      ],
                    ),
                  ),
                ),

                // Empty state
                if (filteredEnrollments.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medical_services_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFilter != null
                                ? 'No patients enrolled in ${_selectedFilter!.code}'
                                : 'No program enrollments yet',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Enrollment cards — bottom padding clears the FAB
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildEnrollmentCard(
                            context, filteredEnrollments[index]),
                        childCount: filteredEnrollments.length,
                      ),
                    ),
                  ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // Opens a searchable bottom sheet to pick a patient, then pushes
  // EnrollPatientPage with the selected patient's NUPI and name.
  Future<void> _pickPatientAndEnroll() async {
    final patient = await showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) =>
            sl<PatientBloc>()..add(const LoadPatientsByFacilityEvent()),
        child: _PatientPickerSheet(facilityId: widget.facilityId),
      ),
    );

    if (patient == null || !mounted) return;

    final enrolled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProgramBloc>(),
          child: EnrollPatientPage(
            patientNupi: patient.nupi,
            patientName: patient.fullName,
            facilityId:  widget.facilityId,
          ),
        ),
      ),
    );

    if (enrolled == true && mounted) {
      context
          .read<ProgramBloc>()
          .add(LoadFacilityEnrollments(widget.facilityId));
    }
  }

  Widget _buildStatsGrid(Map<DiseaseProgram, int> stats) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: DiseaseProgram.values.map((program) {
        final count = stats[program] ?? 0;
        return _buildStatCard(program, count);
      }).toList(),
    );
  }

  Widget _buildStatCard(DiseaseProgram program, int count) {
    final colors = {
      DiseaseProgram.hivArt: Colors.red,
      DiseaseProgram.ncdDiabetes: Colors.blue,
      DiseaseProgram.hypertension: Colors.orange,
      DiseaseProgram.malaria: Colors.green,
      DiseaseProgram.tb: Colors.purple,
      DiseaseProgram.mch: Colors.pink,
    };

    final color = colors[program]!;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            program.code,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgramFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', null),
          ...DiseaseProgram.values.map((program) => _buildFilterChip(program.code, program)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, DiseaseProgram? program) {
    final isSelected = _selectedFilter == program;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? program : null;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF2D6A4F),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: isSelected ? const Color(0xFF2D6A4F) : Colors.grey[300]!),
      ),
    );
  }

  Widget _buildEnrollmentCard(BuildContext context, ProgramEnrollment enrollment) {
    final colors = {
      DiseaseProgram.hivArt: Colors.red,
      DiseaseProgram.ncdDiabetes: Colors.blue,
      DiseaseProgram.hypertension: Colors.orange,
      DiseaseProgram.malaria: Colors.green,
      DiseaseProgram.tb: Colors.purple,
      DiseaseProgram.mch: Colors.pink,
    };

    final color = colors[enrollment.program]!;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnrollmentDetailPage(enrollment: enrollment),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  enrollment.program.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              _buildStatusBadge(enrollment.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            enrollment.patientName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NUPI: ${enrollment.patientNupi}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                'Enrolled: ${DateFormat('dd MMM yyyy').format(enrollment.enrollmentDate)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          if (enrollment.programSpecificData != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _buildProgramSpecificInfo(enrollment),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'View details',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: color),
            ],
          ),
        ],
      ),
    ), // InkWell child
    ); // InkWell
  }

  Widget _buildStatusBadge(ProgramEnrollmentStatus status) {
    final colors = {
      ProgramEnrollmentStatus.active: Colors.green,
      ProgramEnrollmentStatus.completed: Colors.blue,
      ProgramEnrollmentStatus.defaulted: Colors.orange,
      ProgramEnrollmentStatus.transferred: Colors.purple,
      ProgramEnrollmentStatus.died: Colors.red,
    };

    final color = colors[status]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProgramSpecificInfo(ProgramEnrollment enrollment) {
    final data = enrollment.programSpecificData!;

    switch (enrollment.program) {
      case DiseaseProgram.hivArt:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['arvRegimen'] != null)
              _infoRow('ARV Regimen', data['arvRegimen']),
            if (data['viralLoadStatus'] != null)
              _infoRow('Viral Load', data['viralLoadStatus']),
          ],
        );
      case DiseaseProgram.ncdDiabetes:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['diabetesType'] != null)
              _infoRow('Type', data['diabetesType']),
            if (data['hba1c'] != null)
              _infoRow('HbA1c', '${data['hba1c']}%'),
          ],
        );
      case DiseaseProgram.hypertension:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['baselineSystolic'] != null && data['baselineDiastolic'] != null)
              _infoRow('BP', '${data['baselineSystolic']}/${data['baselineDiastolic']} mmHg'),
            if (data['stage'] != null)
              _infoRow('Stage', data['stage']),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Map<DiseaseProgram, int> _calculateStats(List<ProgramEnrollment> enrollments) {
    final stats = <DiseaseProgram, int>{};
    for (final program in DiseaseProgram.values) {
      stats[program] = enrollments.where((e) => e.program == program).length;
    }
    return stats;
  }
}
// ─── Patient picker bottom sheet ─────────────────────────────────────────────

class _PatientPickerSheet extends StatefulWidget {
  final String facilityId;
  const _PatientPickerSheet({required this.facilityId});

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Patient> _sqliteExtras = [];

  static const _primary = Color(0xFF2D6A4F);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchLocal(String q) async {
    if (q.isEmpty) {
      if (mounted) setState(() => _sqliteExtras = []);
      return;
    }
    final ds    = sl<PatientLocalDatasource>();
    final all   = await ds.getAllPatients();
    final lower = q.toLowerCase();
    final hits  = all
        .where((p) =>
            '${p.firstName} ${p.lastName}'.toLowerCase().contains(lower) ||
            p.nupi.toLowerCase().contains(lower) ||
            p.phoneNumber.contains(lower))
        .toList();
    if (mounted) setState(() => _sqliteExtras = hits.cast<Patient>());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select patient to enroll',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) {
                  if (v.isEmpty) {
                    context
                        .read<PatientBloc>()
                        .add(const LoadPatientsByFacilityEvent());
                  } else {
                    context
                        .read<PatientBloc>()
                        .add(SearchPatientEvent(v));
                  }
                  _searchLocal(v);
                },
                decoration: InputDecoration(
                  hintText: 'Search by name, NUPI or phone…',
                  hintStyle:
                      TextStyle(fontSize: 13, color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _primary, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 16, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            context.read<PatientBloc>().add(
                                const LoadPatientsByFacilityEvent());
                            setState(() => _sqliteExtras = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const Divider(height: 1),
            // Patient list
            Expanded(
              child: BlocBuilder<PatientBloc, PatientState>(
                builder: (_, state) {
                  if (state is PatientLoading) {
                    return const Center(
                        child: CircularProgressIndicator.adaptive());
                  }

                  final blocList =
                      state is PatientsLoaded ? state.patients : <Patient>[];
                  final seen    = <String>{};
                  final merged  = <Patient>[];
                  for (final p in [...blocList, ..._sqliteExtras]) {
                    if (seen.add(p.nupi)) merged.add(p);
                  }

                  if (merged.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No patients found',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: merged.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey[100]),
                    itemBuilder: (_, i) {
                      final p = merged[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        onTap: () => Navigator.pop(context, p),
                        leading: CircleAvatar(
                          backgroundColor: p.gender == 'female'
                              ? const Color(0xFFEC4899).withOpacity(0.12)
                              : const Color(0xFF2D6A4F).withOpacity(0.12),
                          child: Text(
                            p.firstName.isNotEmpty
                                ? p.firstName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: p.gender == 'female'
                                  ? const Color(0xFFEC4899)
                                  : _primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          p.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${p.age} yrs  •  ${p.nupi}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                        trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}