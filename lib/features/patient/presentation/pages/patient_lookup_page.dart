import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../referral/presentation/pages/create_referral_page.dart';
import '../bloc/lookup_bloc.dart';
import '../bloc/lookup_event.dart';
import '../bloc/lookup_state.dart';

class PatientLookupPage extends StatelessWidget {
  const PatientLookupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LookupBloc>(),
      child: const _PatientLookupView(),
    );
  }
}

class _PatientLookupView extends StatefulWidget {
  const _PatientLookupView();

  @override
  State<_PatientLookupView> createState() =>
      _PatientLookupViewState();
}

class _PatientLookupViewState
    extends State<_PatientLookupView> {
  final _nupiController = TextEditingController();
  final Color primary = const Color(0xFF1B4332);

  @override
  void dispose() {
    _nupiController.dispose();
    super.dispose();
  }

  void _search() {
    final nupi = _nupiController.text.trim();
    if (nupi.isEmpty) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    context.read<LookupBloc>().add(
          LookupPatientEvent(
            nupi: nupi,
            currentFacilityId:
                authState.user.facilityId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cross-Facility Lookup',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4332)
                    .withOpacity(0.06),
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1B4332)
                      .withOpacity(0.15),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.hub_rounded,
                    color: Color(0xFF1B4332),
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'National Patient Index',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            color: Color(0xFF1B4332),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Search any patient registered at a ClinicConnect facility using their NUPI number.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF374151),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // NUPI Search
            Text(
              'Enter NUPI Number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nupiController,
                    keyboardType:
                        TextInputType.text,
                    textCapitalization:
                        TextCapitalization.characters,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. KE-2024-123456',
                      prefixIcon: Icon(
                        Icons.badge_rounded,
                        color: primary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                                14),
                        borderSide: BorderSide(
                            color:
                                Colors.grey[200]!),
                      ),
                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                                14),
                        borderSide: BorderSide(
                            color:
                                Colors.grey[200]!),
                      ),
                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                                14),
                        borderSide: BorderSide(
                            color: primary,
                            width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(
                        18),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(
                      Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Results
            BlocBuilder<LookupBloc, LookupState>(
              builder: (context, state) {
                if (state is LookupLoading) {
                  return _buildSearching();
                }

                if (state is LookupNotFound) {
                  return _buildNotFound();
                }

                if (state is LookupError) {
                  return _buildError(
                      state.message);
                }

                if (state is LookupFound) {
                  return _buildResult(
                      context, state);
                }

                return _buildInitialHint();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearching() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 16),
            Text(
              'Searching national patient index...',
              style: TextStyle(
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 48,
            color: Color(0xFFCBD5E1),
          ),
          SizedBox(height: 12),
          Text(
            'Patient not found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'No patient with this NUPI is registered\non any ClinicConnect facility.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialHint() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // How it works section
        const Text(
          'HOW IT WORKS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        _hintStep(
          '1',
          'Enter NUPI',
          'Type the patient\'s National Unique Patient Identifier',
          Icons.badge_rounded,
        ),
        _hintStep(
          '2',
          'Locate Facility',
          'System checks which facility registered the patient',
          Icons.location_on_rounded,
        ),
        _hintStep(
          '3',
          'View Summary',
          'See basic demographics — no clinical data shared',
          Icons.person_rounded,
        ),
        _hintStep(
          '4',
          'Create Referral',
          'Send a formal FHIR referral to the patient\'s facility',
          Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _hintStep(
    String number,
    String title,
    String sub,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(icon,
              color: primary.withOpacity(0.4),
              size: 20),
        ],
      ),
    );
  }

  Widget _buildResult(
      BuildContext context, LookupFound state) {
    final result = state.result;
    final summary = state.summary;
    final authState = context.read<AuthBloc>().state;

    // Calculate age if DOB available
    String ageDisplay = '';
    if (summary?['date_of_birth'] != null) {
      try {
        final dob = summary!['date_of_birth']
                is DateTime
            ? summary['date_of_birth'] as DateTime
            : (summary['date_of_birth']
                    as dynamic)
                .toDate();
        final age =
            DateTime.now().year - dob.year;
        ageDisplay = '$age yrs';
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Found badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF2D6A4F)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2D6A4F),
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'Patient Found in National Index',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D6A4F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Patient Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF2D6A4F)
                  .withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Patient header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        primary.withOpacity(0.1),
                    child: Text(
                      summary?['full_name']
                                  ?.toString()
                                  .isNotEmpty ==
                              true
                          ? summary!['full_name']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary?['full_name'] ??
                              'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            _infoBadge(
                              'NUPI: ${result.nupi}',
                              const Color(0xFF6366F1),
                            ),
                            if (ageDisplay
                                .isNotEmpty)
                              _infoBadge(
                                ageDisplay,
                                const Color(
                                    0xFF0EA5E9),
                              ),
                            if (summary?['gender'] !=
                                null)
                              _infoBadge(
                                summary!['gender']
                                    .toString()
                                    .toUpperCase(),
                                const Color(
                                    0xFF2D6A4F),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(
                  color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Facility info
              const Text(
                'REGISTERED AT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: result.isCurrentFacility
                          ? const Color(0xFF2D6A4F)
                              .withOpacity(0.1)
                          : const Color(0xFF0EA5E9)
                              .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_hospital_rounded,
                      color: result.isCurrentFacility
                          ? const Color(0xFF2D6A4F)
                          : const Color(0xFF0EA5E9),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.facilityName,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${result.facilityCounty} County',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (result.isCurrentFacility)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F)
                            .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(
                                20),
                      ),
                      child: const Text(
                        'This Facility',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2D6A4F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),

              // Privacy note
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius:
                      BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: Color(0xFFD97706),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Clinical records are private. Only basic demographics shown. Full records remain at the registering facility.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Actions
        if (!result.isCurrentFacility &&
            authState is Authenticated) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateReferralPage(
                      user: authState.user,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text(
                'Create Referral for This Patient',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ] else if (result.isCurrentFacility) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F)
                  .withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2D6A4F),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Patient is registered at your facility',
                  style: TextStyle(
                    color: Color(0xFF2D6A4F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}