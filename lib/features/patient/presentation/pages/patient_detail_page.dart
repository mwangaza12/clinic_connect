import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/patient.dart';

class PatientDetailPage extends StatelessWidget {
  final Patient patient;

  const PatientDetailPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1B4332),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          patient.firstName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        patient.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'NUPI: ${patient.nupi}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Quick Info Row
                Row(
                  children: [
                    Expanded(
                      child: _quickInfoCard(
                        Icons.cake_outlined,
                        '${patient.age} years',
                        'Age',
                        const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickInfoCard(
                        patient.gender == 'male'
                            ? Icons.male_rounded
                            : Icons.female_rounded,
                        patient.gender.toUpperCase(),
                        'Gender',
                        patient.gender == 'male'
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFEC4899),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickInfoCard(
                        Icons.bloodtype_outlined,
                        patient.bloodGroup ?? 'N/A',
                        'Blood',
                        const Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Personal Information
                _sectionTitle('Personal Information'),
                const SizedBox(height: 12),
                _infoCard([
                  _infoRow(Icons.fingerprint, 'NUPI', patient.nupi),
                  _infoRow(Icons.person_outline, 'Full Name', patient.fullName),
                  _infoRow(
                    Icons.calendar_today_outlined,
                    'Date of Birth',
                    DateFormat('dd MMMM yyyy').format(patient.dateOfBirth),
                  ),
                  _infoRow(Icons.phone_outlined, 'Phone', patient.phoneNumber),
                  if (patient.email != null)
                    _infoRow(Icons.email_outlined, 'Email', patient.email!),
                ]),
                const SizedBox(height: 20),

                // Address
                _sectionTitle('Residential Address'),
                const SizedBox(height: 12),
                _infoCard([
                  _infoRow(Icons.map_outlined, 'County', patient.county),
                  _infoRow(Icons.location_city_outlined, 'Sub-County', patient.subCounty),
                  _infoRow(Icons.explore_outlined, 'Ward', patient.ward),
                  _infoRow(Icons.home_outlined, 'Village', patient.village),
                ]),
                const SizedBox(height: 20),

                // Next of Kin
                if (patient.nextOfKinName != null) ...[
                  _sectionTitle('Next of Kin'),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow(Icons.contacts_outlined, 'Name', patient.nextOfKinName!),
                    if (patient.nextOfKinPhone != null)
                      _infoRow(Icons.phone_outlined, 'Phone', patient.nextOfKinPhone!),
                    if (patient.nextOfKinRelationship != null)
                      _infoRow(Icons.people_outline, 'Relationship',
                          patient.nextOfKinRelationship!),
                  ]),
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                _sectionTitle('Clinical Actions'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        context,
                        Icons.medical_services_outlined,
                        'New Visit',
                        const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionButton(
                        context,
                        Icons.send_outlined,
                        'Refer Patient',
                        const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        context,
                        Icons.history_outlined,
                        'Visit History',
                        const Color(0xFF2D6A4F),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionButton(
                        context,
                        Icons.science_outlined,
                        'Lab Results',
                        const Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickInfoCard(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map(
              (entry) => Column(
                children: [
                  entry.value,
                  if (entry.key < children.length - 1)
                    const Divider(
                      height: 1,
                      indent: 56,
                      color: Color(0xFFE2E8F0),
                    ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2D6A4F)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label - Coming soon!')),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}