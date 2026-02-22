// lib/features/disease_program/presentation/pages/program_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/disease_program.dart';
import '../bloc/program_bloc.dart';
import '../bloc/program_event.dart';
import '../bloc/program_state.dart';

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

            return Column(
              children: [
                // Stats Cards
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildStatsGrid(stats),
                      const SizedBox(height: 16),
                      _buildProgramFilter(),
                    ],
                  ),
                ),

                // Enrollments List
                Expanded(
                  child: filteredEnrollments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter != null
                                    ? 'No patients enrolled in ${_selectedFilter!.code}'
                                    : 'No program enrollments yet',
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredEnrollments.length,
                          itemBuilder: (context, index) {
                            final enrollment = filteredEnrollments[index];
                            return _buildEnrollmentCard(enrollment);
                          },
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            program.code,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
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

  Widget _buildEnrollmentCard(ProgramEnrollment enrollment) {
    final colors = {
      DiseaseProgram.hivArt: Colors.red,
      DiseaseProgram.ncdDiabetes: Colors.blue,
      DiseaseProgram.hypertension: Colors.orange,
      DiseaseProgram.malaria: Colors.green,
      DiseaseProgram.tb: Colors.purple,
      DiseaseProgram.mch: Colors.pink,
    };

    final color = colors[enrollment.program]!;

    return Container(
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
        ],
      ),
    );
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