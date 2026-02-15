import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Color primary = const Color(0xFF1B4332);

  // ── Settings State ──────────────────────
  bool _offlineModeEnabled = true;
  bool _referralNotifications = true;
  bool _syncOnWifiOnly = false;
  String _selectedLanguage = 'English';
  String _syncInterval = '15 min';
  bool _isClearing = false;
  String _storageUsed = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    try {
      final db = sl<DatabaseHelper>();
      final patients = await db.database.then(
        (d) => d.rawQuery('SELECT COUNT(*) as c FROM patients'),
      );
      final encounters = await db.database.then(
        (d) => d.rawQuery(
            'SELECT COUNT(*) as c FROM encounters'),
      );
      final queue = await db.database.then(
        (d) => d.rawQuery(
            'SELECT COUNT(*) as c FROM sync_queue'),
      );

      final pCount =
          patients.first['c'] as int? ?? 0;
      final eCount =
          encounters.first['c'] as int? ?? 0;
      final qCount = queue.first['c'] as int? ?? 0;

      if (mounted) {
        setState(() {
          _storageUsed =
              '$pCount patients • $eCount encounters • $qCount queued';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _storageUsed = 'Unable to calculate');
      }
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Clear Local Cache',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This removes locally cached data. '
          'Synced records remain safe in Firebase. '
          'Unsynced records will be lost.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('CANCEL',
                style: TextStyle(
                    fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isClearing = true);

    try {
      final db = sl<DatabaseHelper>();
      final d = await db.database;
      await d.delete('sync_queue');
      await _calculateStorage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cache cleared successfully'),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _forcSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Syncing all pending records...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      await sl<SyncManager>().syncNow();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sync complete'),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
      await _calculateStorage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          'Settings',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 1. Offline & Sync ─────────────
          _sectionTitle('OFFLINE & SYNC'),
          _settingsCard([
            _toggleRow(
              Icons.wifi_off_rounded,
              'Offline Mode',
              'Work without internet connection',
              _offlineModeEnabled,
              (v) => setState(
                  () => _offlineModeEnabled = v),
            ),
            _divider(),
            _toggleRow(
              Icons.wifi_rounded,
              'Sync on WiFi Only',
              'Save mobile data in the field',
              _syncOnWifiOnly,
              (v) =>
                  setState(() => _syncOnWifiOnly = v),
            ),
            _divider(),
            _dropdownRow(
              Icons.timer_rounded,
              'Sync Interval',
              'How often to push pending records',
              _syncInterval,
              ['5 min', '15 min', '30 min', '1 hour'],
              (v) => setState(
                  () => _syncInterval = v ?? '15 min'),
            ),
            _divider(),
            _actionRow(
              Icons.sync_rounded,
              'Force Sync Now',
              'Push all pending records to Firebase',
              _forcSync,
              color: primary,
            ),
          ]),
          const SizedBox(height: 20),

          // ── 2. Language ────────────────────
          _sectionTitle('LANGUAGE'),
          _settingsCard([
            _dropdownRow(
              Icons.language_rounded,
              'App Language',
              'Interface display language',
              _selectedLanguage,
              ['English', 'Kiswahili'],
              (v) => setState(
                  () => _selectedLanguage = v ?? 'English'),
            ),
          ]),
          const SizedBox(height: 20),

          // ── 3. Notifications ───────────────
          _sectionTitle('NOTIFICATIONS'),
          _settingsCard([
            _toggleRow(
              Icons.notifications_rounded,
              'Referral Alerts',
              'Notify when referrals are received',
              _referralNotifications,
              (v) => setState(
                  () => _referralNotifications = v),
            ),
            _divider(),
            _toggleRow(
              Icons.sync_alt_rounded,
              'Sync Completed',
              'Notify when records finish syncing',
              true,
              (_) {},
            ),
            _divider(),
            _toggleRow(
              Icons.warning_amber_rounded,
              'Sync Failures',
              'Alert when records fail to sync',
              true,
              (_) {},
            ),
          ]),
          const SizedBox(height: 20),

          // ── 4. Data & Storage ──────────────
          _sectionTitle('DATA & STORAGE'),
          _settingsCard([
            _infoRow(
              Icons.storage_rounded,
              'Local Database',
              _storageUsed,
            ),
            _divider(),
            _actionRow(
              Icons.delete_outline_rounded,
              'Clear Sync Queue',
              'Remove pending unsynced items',
              _isClearing ? null : _clearCache,
              color: Colors.orange,
              trailing: _isClearing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    )
                  : null,
            ),
            _divider(),
            _actionRow(
              Icons.refresh_rounded,
              'Recalculate Storage',
              'Refresh local storage statistics',
              _calculateStorage,
              color: primary,
            ),
          ]),
          const SizedBox(height: 20),

          // ── 5. About & System ─────────────
          _sectionTitle('ABOUT & SYSTEM'),
          _settingsCard([
            _infoRow(
              Icons.info_outline_rounded,
              'App Version',
              'ClinicConnect v1.2.0 • Build 2026.02',
            ),
            _divider(),
            _infoRow(
              Icons.verified_rounded,
              'FHIR Compliance',
              'HL7 FHIR R4 — Patient, Encounter, Observation, Condition, ServiceRequest',
            ),
            _divider(),
            _infoRow(
              Icons.hub_rounded,
              'Architecture',
              'Federated — IHE XDS / OpenHIE compatible',
            ),
            _divider(),
            _infoRow(
              Icons.flag_rounded,
              'NUPI Standard',
              'Kenya National Unique Patient Identifier',
            ),
            _divider(),
            _infoRow(
              Icons.code_rounded,
              'Built With',
              'Flutter • Firebase • Dart • SQLite',
            ),
            _divider(),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is Authenticated) {
                  return _infoRow(
                    Icons.local_hospital_rounded,
                    'Connected Facility',
                    state.user.facilityName,
                  );
                }
                return const SizedBox();
              },
            ),
          ]),
          const SizedBox(height: 20),

          // ── FHIR Compliance Badge ──────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: primary.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Icon(Icons.verified_rounded,
                    color: primary, size: 32),
                const SizedBox(height: 10),
                Text(
                  'HL7 FHIR R4 Compliant',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This system implements internationally\nrecognised health data exchange standards\nfor Kenya\'s federated healthcare network.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _fhirChip('FHIR R4',
                        const Color(0xFF6366F1)),
                    _fhirChip(
                        'LOINC', const Color(0xFF0EA5E9)),
                    _fhirChip('SNOMED CT',
                        const Color(0xFF2D6A4F)),
                    _fhirChip(
                        'ICD-10', const Color(0xFFF59E0B)),
                    _fhirChip(
                        'NUPI', const Color(0xFFEC4899)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 4, bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  Widget _toggleRow(
    IconData icon,
    String title,
    String sub,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: primary, size: 18),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: primary,
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow(
    IconData icon,
    String title,
    String sub,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: primary, size: 18),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            items: options
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    IconData icon,
    String title,
    String sub,
    VoidCallback? onTap, {
    Color? color,
    Widget? trailing,
  }) {
    final c = color ?? primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.withOpacity(0.07),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: c.withOpacity(0.5),
                ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Color(0xFFF1F5F9),
      );

  Widget _fhirChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: color.withOpacity(0.3)),
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