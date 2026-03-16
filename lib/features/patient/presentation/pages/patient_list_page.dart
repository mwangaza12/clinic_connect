// lib/features/patient/presentation/pages/patient_list_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/patient.dart';
import '../bloc/patient_bloc.dart';
import '../bloc/patient_event.dart';
import '../bloc/patient_state.dart';
import 'patient_registration_page.dart';
import 'patient_detail_page.dart';
import 'patient_lookup_page.dart';

class PatientListPage extends StatelessWidget {
  const PatientListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PatientBloc>()..add(const LoadPatientsByFacilityEvent()),
      child: const PatientListView(),
    );
  }
}

class PatientListView extends StatefulWidget {
  const PatientListView({super.key});

  @override
  State<PatientListView> createState() => _PatientListViewState();
}

class _PatientListViewState extends State<PatientListView> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  final Color primaryGreen = const Color(0xFF1B4332);
  final Color slateBg = const Color(0xFFF1F5F9);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int _getAge(DateTime dob) => DateTime.now().year - dob.year;

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      if (query.isEmpty) {
        // Reload all patients when search is cleared
        context.read<PatientBloc>().add(
          const LoadPatientsByFacilityEvent(),
        );
      } else {
        // Only search if query has at least 3 characters
        if (query.length >= 3) {
          context.read<PatientBloc>().add(
            SearchPatientEvent(query),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slateBg,
      appBar: _buildProfessionalHeader(context),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildPatientContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PatientRegistrationPage()),
        ).then((_) {
          // Reload list when registration page pops
          if (context.mounted) {
            context
                .read<PatientBloc>()
                .add(const LoadPatientsByFacilityEvent());
          }
        }),
        backgroundColor: primaryGreen,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          'REGISTER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildProfessionalHeader(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Registry',
            style: TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const Text(
            'Interoperable Health Records',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.manage_search_rounded, color: primaryGreen),
          tooltip: 'Cross-Facility NUPI Lookup',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PatientLookupPage()),
          ),
        ),
        IconButton(
          icon: Icon(Icons.filter_list_rounded, color: primaryGreen),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by NUPI, Name or Phone...',
          prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    context.read<PatientBloc>().add(
                      const LoadPatientsByFacilityEvent(),
                    );
                  },
                )
              : null,
          filled: true,
          fillColor: slateBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildPatientContent() {
    return BlocBuilder<PatientBloc, PatientState>(
      builder: (context, state) {
        if (state is PatientLoading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        
        if (state is PatientsLoaded) {
          if (state.patients.isEmpty) {
            return _buildEmptyState(
              message: _searchController.text.isEmpty
                  ? 'No Patient Records Found'
                  : 'No patients match "${_searchController.text}"',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.patients.length,
            itemBuilder: (context, index) =>
                _buildMedicalCard(state.patients[index]),
          );
        }
        
        if (state is PatientError) {
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 60, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading patients',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<PatientBloc>().add(
                          const LoadPatientsByFacilityEvent(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        return _buildEmptyState();
      },
    );
  }

  Widget _buildMedicalCard(Patient patient) {
    final String fullName = '${patient.firstName} ${patient.lastName}';
    final int age = _getAge(patient.dateOfBirth);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Gender-coded vertical bar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: patient.gender.toLowerCase() == 'male'
                    ? Colors.blue[700]
                    : Colors.pink[400],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Main content
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientDetailPage(patient: patient),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: patient.nupi.startsWith('PENDING-')
                                ? _pendingNupiBadge()
                                : _badge(patient.nupi, primaryGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _dataPoint(Icons.cake_outlined, '$age yrs'),
                          _dataPoint(Icons.phone_outlined, patient.phoneNumber),
                          _dataPoint(
                            Icons.location_on_outlined,
                            '${patient.village}, ${patient.county}',
                            maxWidth: 160,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Chevron
            Container(
              width: 40,
              decoration: BoxDecoration(
                color: slateBg.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _pendingNupiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.sync_outlined, size: 10, color: Color(0xFF94A3B8)),
          SizedBox(width: 4),
          Text(
            'NUPI PENDING',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataPoint(IconData icon, String text, {double? maxWidth}) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      );
    }
    return content;
  }

  Widget _buildEmptyState({String? message}) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
            children: [
              Icon(Icons.folder_open_rounded, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                message ?? 'No Patient Records Found',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    context.read<PatientBloc>().add(
                      const LoadPatientsByFacilityEvent(),
                    );
                  },
                  child: const Text('Clear Search'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}