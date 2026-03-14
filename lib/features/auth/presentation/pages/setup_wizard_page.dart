// lib/features/auth/presentation/pages/setup_wizard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/hie_api_service.dart';

class SetupWizardPage extends StatefulWidget {
  final Future<void> Function()? onComplete;
  const SetupWizardPage({super.key, this.onComplete});

  @override
  State<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends State<SetupWizardPage> {
  static const _storage    = FlutterSecureStorage();
  static const _primary    = Color(0xFF2D6A4F);

  final _formKey           = GlobalKey<FormState>();
  final _gatewayCtrl       = TextEditingController();
  final _facilityIdCtrl    = TextEditingController();
  final _apiKeyCtrl        = TextEditingController();

  bool    _saving          = false;
  bool    _showKey         = false;
  bool    _verified        = false;
  String? _statusMsg;
  bool    _statusOk        = false;
  String? _resolvedName;
  String? _resolvedCounty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gw  = await _storage.read(key: StorageKeys.hieGatewayUrl);
    final fid = await _storage.read(key: StorageKeys.facilityId);
    final key = await _storage.read(key: StorageKeys.facilityApiKey);
    final nm  = await _storage.read(key: StorageKeys.facilityName);
    if (!mounted) return;
    setState(() {
      _gatewayCtrl.text    = gw  ?? 'https://afyalink-hie.onrender.com';
      _facilityIdCtrl.text = fid ?? '';
      _apiKeyCtrl.text     = key ?? '';
      _resolvedName        = nm;
    });
  }

  @override
  void dispose() {
    _gatewayCtrl.dispose();
    _facilityIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: Fetch Firebase config from HIE Gateway ────────────────────────

  Future<void> _fetchAndVerify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving    = true;
      _statusMsg = null;
      _verified  = false;
      _resolvedName = null;
    });

    try {
      final gateway    = _gatewayCtrl.text.trim();
      final facilityId = _facilityIdCtrl.text.trim().toUpperCase();
      final apiKey     = _apiKeyCtrl.text.trim();

      // Init HIE service with the entered URL
      HieApiService.init(gateway);

      // Fetch Firebase credentials + facility info from gateway
      final result = await HieApiService.instance.getFacilityFirebaseConfig(
        facilityId: facilityId,
        apiKey:     apiKey,
      );

      if (!result.success || result.data == null) {
        setState(() {
          _statusOk  = false;
          _statusMsg = '❌ ${result.error ?? 'Could not reach facility'}';
        });
        return;
      }

      final data     = result.data!;
      final fbConfig = data['firebaseConfig'] as Map<String, dynamic>?;

      if (fbConfig == null || (fbConfig['apiKey'] as String?)?.isEmpty != false) {
        setState(() {
          _statusOk  = false;
          _statusMsg = '❌ Firebase not configured for this facility. Contact your MoH administrator.';
        });
        return;
      }

      // Initialize Firebase dynamically with the fetched credentials
      final error = await FirebaseConfig.initFromCredentials(
        apiKey:            fbConfig['apiKey']            as String,
        appId:             fbConfig['appId']             as String,
        projectId:         fbConfig['projectId']         as String,
        facilityId:        facilityId,
        facilityName:      data['facilityName']          as String? ?? facilityId,
        messagingSenderId: fbConfig['messagingSenderId'] as String?,
        storageBucket:     fbConfig['storageBucket']     as String?,
        authDomain:        fbConfig['authDomain']        as String?,
        county:            data['county']                as String?,
        subCounty:         data['subCounty']             as String?,
      );

      if (error != null) {
        setState(() {
          _statusOk  = false;
          _statusMsg = '❌ $error';
        });
        return;
      }

      // Save HIE Gateway credentials too
      await Future.wait([
        _storage.write(key: StorageKeys.hieGatewayUrl,  value: gateway),
        _storage.write(key: StorageKeys.facilityApiKey, value: apiKey),
      ]);

      setState(() {
        _statusOk     = true;
        _verified     = true;
        _resolvedName = data['facilityName'] as String? ?? facilityId;
        _resolvedCounty = data['county'] as String?;
        _statusMsg    = '✅ Connected — ${_resolvedName}';
      });

    } catch (e) {
      setState(() {
        _statusOk  = false;
        _statusMsg = '❌ $e';
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Step 2: Confirm and continue ─────────────────────────────────────────

  Future<void> _confirm() async {
    if (!_verified) {
      setState(() => _statusMsg = '⚠ Please verify your facility first');
      return;
    }
    setState(() => _saving = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('${_resolvedName ?? 'Facility'} set up successfully'),
          backgroundColor: _primary,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
        await widget.onComplete?.call();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(children: [
        Positioned(top: -100, right: -100,
            child: CircleAvatar(radius: 150,
                backgroundColor: _primary.withOpacity(0.05))),
        Positioned(bottom: -50, left: -50,
            child: CircleAvatar(radius: 100,
                backgroundColor: _primary.withOpacity(0.05))),
        SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: _primary.withOpacity(0.1),
                        blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      size: 50, color: _primary),
                )),
                const SizedBox(height: 32),

                const Text('ClinicConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A), letterSpacing: -1)),
                const SizedBox(height: 8),
                Text('Facility Setup', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey[600],
                        fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(
                  'Enter your facility credentials to connect to '
                  'your hospital\'s database.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
                ),
                const SizedBox(height: 40),

                // HIE Gateway URL
                _field(
                  label: 'HIE Gateway URL',
                  ctrl:  _gatewayCtrl,
                  icon:  Icons.cloud_outlined,
                  hint:  'https://afyalink-hie.onrender.com',
                  type:  TextInputType.url,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Gateway URL is required';
                    if (Uri.tryParse(v.trim())?.hasScheme != true)
                      return 'Enter a valid URL (include https://)';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Facility ID
                _field(
                  label: 'Facility ID',
                  ctrl:  _facilityIdCtrl,
                  icon:  Icons.domain_outlined,
                  hint:  'e.g. FAC-KE-001',
                  caps:  TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Facility ID is required' : null,
                ),
                const SizedBox(height: 20),

                // API Key
                _field(
                  label:   'Facility API Key',
                  ctrl:    _apiKeyCtrl,
                  icon:    Icons.key_outlined,
                  hint:    'FAC-XXXXXXXX (issued by MoH)',
                  obscure: !_showKey,
                  suffix:  IconButton(
                    icon: Icon(
                      _showKey ? Icons.visibility_off_outlined
                               : Icons.visibility_outlined,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'API Key is required' : null,
                ),
                const SizedBox(height: 24),

                // Status banner
                if (_statusMsg != null) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _statusOk
                          ? _primary.withOpacity(0.08)
                          : Colors.redAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _statusOk ? _primary : Colors.redAccent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusMsg!,
                            style: TextStyle(
                                color: _statusOk ? _primary : Colors.redAccent,
                                fontWeight: FontWeight.w600)),
                        if (_statusOk && _resolvedCounty != null) ...[
                          const SizedBox(height: 4),
                          Text(_resolvedCounty!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _primary.withOpacity(0.7))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Verify button
                OutlinedButton.icon(
                  onPressed: _saving ? null : _fetchAndVerify,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: Text(
                    _saving ? 'Connecting…' : 'Verify Facility',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: BorderSide(color: _primary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),

                // Continue button — only active after verification
                ElevatedButton(
                  onPressed: (_saving || !_verified) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:         _primary,
                    foregroundColor:         Colors.white,
                    disabledBackgroundColor: _primary.withOpacity(0.35),
                    padding:   const EdgeInsets.symmetric(vertical: 18),
                    elevation: 8,
                    shadowColor: _primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save & Continue',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 32),

                // Help card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: Colors.blueGrey[400]),
                        const SizedBox(width: 8),
                        Text('Where do I find these?',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: Colors.blueGrey[700])),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        '• Your Facility ID and API Key are issued by the MoH '
                        'administrator when your facility is registered.\n'
                        '• The app uses them to connect to your hospital\'s '
                        'private database automatically.\n'
                        '• This is entered once and stored securely on the device.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey[500],
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ))),
      ]),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? type,
    TextCapitalization caps = TextCapitalization.none,
    String? Function(String?)? validator,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: type,
          textCapitalization: caps,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: _primary),
            suffixIcon: suffix,
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 18, horizontal: 20),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: Colors.redAccent, width: 2)),
          ),
          validator: validator,
        ),
      ]);
}