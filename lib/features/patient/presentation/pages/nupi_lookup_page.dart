// lib/features/patient/presentation/pages/nupi_lookup_page.dart
//
// FIX: Was using PatientBloc (local Firestore search).
// Now uses LookupBloc which queries the shared patient_index —
// this is how cross-facility NUPI lookup actually works.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../referral/presentation/pages/create_referral_page.dart';
import '../bloc/lookup_bloc.dart';
import '../bloc/lookup_event.dart';
import '../bloc/lookup_state.dart';

class NupiLookupPage extends StatefulWidget {
  const NupiLookupPage({super.key});

  @override
  State<NupiLookupPage> createState() => _NupiLookupPageState();
}

class _NupiLookupPageState extends State<NupiLookupPage> {
  final TextEditingController _nupiController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nupiController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(BuildContext context) {
    final nupi = _nupiController.text.trim();
    if (nupi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a NUPI'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    // FIX: Use LookupBloc → PatientLookupDatasource → shared patient_index
    context.read<LookupBloc>().add(
          LookupPatientEvent(
            nupi: nupi,
            currentFacilityId: authState.user.facilityId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LookupBloc>(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NUPI Lookup',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Cross-Facility Patient Search',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        body: BlocBuilder<LookupBloc, LookupState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEF7EC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2D6A4F).withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF2D6A4F), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search for patients across all connected facilities using their National Unique Patient Identifier (NUPI)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0F5132),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _nupiController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Enter NUPI (e.g., KE-2024-100001)',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF2D6A4F)),
                        suffixIcon: _nupiController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() => _nupiController.clear());
                                  context.read<LookupBloc>().add(ClearLookupEvent());
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _performSearch(context),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state is LookupLoading
                          ? null
                          : () => _performSearch(context),
                      icon: state is LookupLoading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(state is LookupLoading ? 'Searching...' : 'Search NUPI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Results
                  if (state is LookupLoading)
                    _buildLoading()
                  else if (state is LookupError)
                    _buildError(state.message)
                  else if (state is LookupNotFound)
                    _buildNotFound()
                  else if (state is LookupFound)
                    _buildResult(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(Color(0xFF2D6A4F)),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching shared patient index...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE11D48), size: 40),
          const SizedBox(height: 12),
          const Text('Search Failed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_search_rounded, color: Color(0xFF64748B), size: 48),
          const SizedBox(height: 16),
          const Text('No Patient Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(
            'No patient with NUPI "${_nupiController.text}" found in the shared patient index.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, LookupFound state) {
    final result = state.result;
    final isLocal = result.isCurrentFacility;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLocal
                  ? const Color(0xFFDEF7EC)
                  : const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: (isLocal ? const Color(0xFF2D6A4F) : const Color(0xFF2563EB))
                      .withOpacity(0.1),
                  child: Icon(
                    isLocal ? Icons.home_outlined : Icons.account_balance_outlined,
                    color: isLocal ? const Color(0xFF2D6A4F) : const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isLocal ? const Color(0xFF2D6A4F) : const Color(0xFF2563EB))
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'NUPI: ${result.nupi}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isLocal ? const Color(0xFF2D6A4F) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLocal ? 'Registered at this facility' : 'Registered at ${result.facilityName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.local_hospital_outlined, 'Facility', result.facilityName),
                if (result.facilityCounty.isNotEmpty)
                  _infoRow(Icons.location_on_outlined, 'County', result.facilityCounty),

                const SizedBox(height: 4),

                // Privacy notice for cross-facility patients
                if (!isLocal)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Clinical records are private. Only the patient index entry is visible here. Use verify + federated chart to access full records with patient consent.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.brown[800],
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Create Referral button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      if (authState is Authenticated) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateReferralPage(user: authState.user),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Select the patient with NUPI ${result.nupi} from the patient list',
                            ),
                            backgroundColor: const Color(0xFF2D6A4F),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Create Referral'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}