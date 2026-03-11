// lib/features/auth/presentation/pages/setup_wizard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/hie_api_service.dart';

class SetupWizardPage extends StatefulWidget {
  final VoidCallback? onComplete;
  const SetupWizardPage({super.key, this.onComplete});

  @override
  State<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends State<SetupWizardPage> {
  static const _storage = FlutterSecureStorage();

  final _formKey        = GlobalKey<FormState>();
  final _gatewayCtrl    = TextEditingController();
  final _facilityIdCtrl = TextEditingController();
  final _apiKeyCtrl     = TextEditingController();

  bool    _saving     = false;
  bool    _showApiKey = false;
  String? _testResult;
  bool    _testOk     = false;

  static const _primaryColor = Color(0xFF2D6A4F);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gateway    = await _storage.read(key: StorageKeys.hieGatewayUrl);
    final facilityId = await _storage.read(key: StorageKeys.facilityId);
    final apiKey     = await _storage.read(key: StorageKeys.facilityApiKey);
    if (!mounted) return;
    setState(() {
      _gatewayCtrl.text    = gateway    ?? 'https://afyalink-hie.onrender.com';
      _facilityIdCtrl.text = facilityId ?? '';
      _apiKeyCtrl.text     = apiKey     ?? '';
    });
  }

  @override
  void dispose() {
    _gatewayCtrl.dispose();
    _facilityIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _testResult = null; });
    try {
      HieApiService.init(_gatewayCtrl.text.trim());
      await _storage.write(key: StorageKeys.facilityId,     value: _facilityIdCtrl.text.trim());
      await _storage.write(key: StorageKeys.facilityApiKey, value: _apiKeyCtrl.text.trim());
      final result = await HieApiService.instance.getFacilities();
      setState(() {
        _testOk     = result.success;
        _testResult = result.success
            ? '✅ Connected — ${result.data?["count"] ?? 0} facilities found'
            : '❌ ${result.error}';
      });
    } catch (e) {
      setState(() { _testOk = false; _testResult = '❌ $e'; });
    } finally {
      setState(() { _saving = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; });
    try {
      final gateway    = _gatewayCtrl.text.trim();
      final facilityId = _facilityIdCtrl.text.trim();
      final apiKey     = _apiKeyCtrl.text.trim();

      await Future.wait([
        _storage.write(key: StorageKeys.hieGatewayUrl,   value: gateway),
        _storage.write(key: StorageKeys.facilityId,      value: facilityId),
        _storage.write(key: StorageKeys.facilityApiKey,  value: apiKey),
      ]);

      HieApiService.init(gateway);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Setup saved — you can now log in'),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      }
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Same decorative circles as LoginPage
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: _primaryColor.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: _primaryColor.withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo — same style as LoginPage
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            size: 50,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      const Text(
                        'ClinicConnect',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Facility Setup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blueGrey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the credentials provided by your MoH administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // HIE Gateway URL
                      _buildInputField(
                        label: 'HIE Gateway URL',
                        controller: _gatewayCtrl,
                        icon: Icons.cloud_outlined,
                        hint: 'https://afyalink-hie.onrender.com',
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Gateway URL is required';
                          final uri = Uri.tryParse(v.trim());
                          if (uri == null || !uri.hasScheme) return 'Enter a valid URL (include https://)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Facility ID
                      _buildInputField(
                        label: 'Facility ID',
                        controller: _facilityIdCtrl,
                        icon: Icons.badge_outlined,
                        hint: 'e.g. FAC-KE-001',
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Facility ID is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // API Key
                      _buildInputField(
                        label: 'Facility API Key',
                        controller: _apiKeyCtrl,
                        icon: Icons.key_outlined,
                        hint: 'FAC-XXXXXXXX (issued by MoH)',
                        obscureText: !_showApiKey,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showApiKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () => setState(() => _showApiKey = !_showApiKey),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'API Key is required' : null,
                      ),
                      const SizedBox(height: 24),

                      // Test result banner
                      if (_testResult != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _testOk
                                ? const Color(0xFF2D6A4F).withOpacity(0.08)
                                : Colors.redAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _testOk ? _primaryColor : Colors.redAccent,
                            ),
                          ),
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              color: _testOk ? _primaryColor : Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Test Connection button
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _test,
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text(
                          'Test Connection',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: BorderSide(color: _primaryColor.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Save & Continue — matches login's ElevatedButton exactly
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 8,
                          shadowColor: _primaryColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),

                      const SizedBox(height: 32),

                      // Help note
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
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16, color: Colors.blueGrey[400]),
                                const SizedBox(width: 8),
                                Text(
                                  'Where do I find these credentials?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '• Your MoH administrator registers your facility at the AfyaLink portal.\n'
                              '• After registration they receive a Facility ID and an API Key.\n'
                              '• These should be stored in your facility\'s records and entered here once.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey[500],
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, color: _primaryColor),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}