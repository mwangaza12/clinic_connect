// lib/features/auth/presentation/pages/setup_wizard_page.dart
//
// First-launch setup wizard.
//
// The admin enters:
//   1. The HIE Gateway URL  (e.g. https://afyalink-hie.onrender.com)
//   2. The Facility ID       (e.g. FAC-001)
//   3. The Facility API Key  (issued by MoH when the facility was registered)
//
// These are persisted to FlutterSecureStorage so HieApiService can attach
// X-Facility-Id + X-Api-Key headers on every request, satisfying the
// requireFacility middleware on the HIE Gateway.
//
// The wizard also re-initialises HieApiService with the provided gateway URL.

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

  final _formKey         = GlobalKey<FormState>();
  final _gatewayCtrl     = TextEditingController();
  final _facilityIdCtrl  = TextEditingController();
  final _apiKeyCtrl      = TextEditingController();

  bool    _saving     = false;
  bool    _showApiKey = false;
  String? _testResult;
  bool    _testOk     = false;

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
      await _storage.write(key: StorageKeys.facilityId,    value: _facilityIdCtrl.text.trim());
      await _storage.write(key: StorageKeys.facilityApiKey,value: _apiKeyCtrl.text.trim());
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
        _storage.write(key: StorageKeys.hieGatewayUrl,  value: gateway),
        _storage.write(key: StorageKeys.facilityId,     value: facilityId),
        _storage.write(key: StorageKeys.facilityApiKey, value: apiKey),
      ]);

      HieApiService.init(gateway);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Setup saved — you can now log in'),
          backgroundColor: Colors.green,
        ));
        widget.onComplete?.call();
        if (context.mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Setup'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_hospital, size: 64, color: Color(0xFF1565C0)),
              const SizedBox(height: 12),
              const Text('AfyaLink HIE Configuration',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Enter the credentials provided by your MoH administrator.\n'
                'These allow this app to communicate with the Health Information Exchange.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),

              TextFormField(
                controller: _gatewayCtrl,
                decoration: const InputDecoration(
                  labelText:  'HIE Gateway URL',
                  hintText:   'https://afyalink-hie.onrender.com',
                  prefixIcon: Icon(Icons.cloud),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Gateway URL is required';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'Enter a valid URL (include https://)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _facilityIdCtrl,
                decoration: const InputDecoration(
                  labelText:  'Facility ID',
                  hintText:   'e.g. FAC-KE-001',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Facility ID is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _apiKeyCtrl,
                obscureText: !_showApiKey,
                decoration: InputDecoration(
                  labelText:  'Facility API Key',
                  hintText:   'FAC-XXXXXXXX (issued by MoH)',
                  prefixIcon: const Icon(Icons.key),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showApiKey = !_showApiKey),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'API Key is required' : null,
              ),
              const SizedBox(height: 24),

              if (_testResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testOk ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _testOk ? Colors.green : Colors.red),
                  ),
                  child: Text(_testResult!,
                    style: TextStyle(
                      color: _testOk ? Colors.green.shade700 : Colors.red.shade700)),
                ),
                const SizedBox(height: 16),
              ],

              OutlinedButton.icon(
                onPressed: _saving ? null : _test,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Test Connection'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Save & Continue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Where do I find these credentials?\n\n'
                '• Your MoH administrator registers your facility at the AfyaLink portal.\n'
                '• After registration they receive a Facility ID and an API Key.\n'
                '• These should be stored in your facility\'s records and entered here once.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
