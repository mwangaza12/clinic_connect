// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/config/firebase_config.dart';
import 'core/constants/storage_keys.dart';
import 'core/services/hie_api_service.dart';
import 'core/services/backend_api_service.dart';
import 'core/sync/sync_manager.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/setup_wizard_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/onboarding/presentation/pages/splash_screen.dart';
import 'injection_container.dart' as di;

late final bool appNeedsSetup;

Future<void> _initApp() async {
  const storage = FlutterSecureStorage();

  // Read all credentials and URLs saved during setup
  final results = await Future.wait([
    storage.read(key: StorageKeys.hieGatewayUrl),
    storage.read(key: StorageKeys.facilityApiKey),
    storage.read(key: StorageKeys.facilityId),
    storage.read(key: StorageKeys.facilityBackendUrl),  // ← NEW
  ]);

  final savedGatewayUrl  = results[0];
  final apiKey           = results[1];
  final facilityId       = results[2];
  final savedBackendUrl  = results[3];  // ← NEW

  // HieApiService is used ONLY for the setup wizard (getFacilityFirebaseConfig)
  // and the two pure parse helpers. It always points at the HIE gateway.
  HieApiService.init(
    savedGatewayUrl?.isNotEmpty == true
        ? savedGatewayUrl!
        : const String.fromEnvironment(
            'HIE_GATEWAY_URL',                          // ← renamed from HIE_BACKEND_URL
            defaultValue: 'https://hie-gateway.onrender.com',
          ),
  );

  // BackendApiService handles ALL patient/encounter/referral/facility calls.
  // It points at THIS facility's own backend (e.g. clinic-connect-sxct.onrender.com).
  // Restored from secure storage on cold start — set during setup wizard.
  if (savedBackendUrl != null && savedBackendUrl.isNotEmpty) {
    BackendApiService.init(savedBackendUrl);
  }
  // If savedBackendUrl is null the setup wizard hasn't run yet — that's fine,
  // BackendApiService.instanceAsync will throw a clear StateError if anything
  // tries to use it before setup, which won't happen because appNeedsSetup
  // gates the rest of the app behind the setup wizard.

  // Try to restore Firebase from previously saved credentials
  final firebaseReady = await FirebaseConfig.restoreFromStorage();

  appNeedsSetup = !firebaseReady ||
      apiKey          == null || apiKey.isEmpty     ||
      facilityId      == null || facilityId.isEmpty ||
      savedBackendUrl == null || savedBackendUrl.isEmpty;  // ← also require backend URL

  // Always init DI — BlocProvider in ClinicConnectApp needs it at build time.
  await di.init();
  await SyncManager().init();
}

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // No static Firebase.initializeApp() here —
  // Firebase is initialized dynamically inside FirebaseConfig.restoreFromStorage()
  // using credentials saved during the setup wizard.

  await _initApp();

  runApp(const ClinicConnectApp());
}

// ── App ───────────────────────────────────────────────────────────────────────

class ClinicConnectApp extends StatelessWidget {
  const ClinicConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<AuthBloc>(),
      child: MaterialApp(
        title:                      'ClinicConnect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A4F)),
          useMaterial3: true,
        ),
        home: const RootNavigator(),
      ),
    );
  }
}

// ── RootNavigator ─────────────────────────────────────────────────────────────

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});
  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  bool _splashDone = false;

  void _onSplashComplete() {
    FlutterNativeSplash.remove();
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) return SplashScreen(onComplete: _onSplashComplete);
    return const AuthWrapper();
  }
}

// ── AuthWrapper ───────────────────────────────────────────────────────────────

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late bool _setupRequired = appNeedsSetup;

  @override
  Widget build(BuildContext context) {
    if (_setupRequired) {
      return SetupWizardPage(
        // After setup wizard completes, Firebase is now initialized.
        // We don't need to re-init DI — it's already running.
        // We just need to rebuild so AuthWrapper shows LoginPage.
        onComplete: () async {
          if (mounted) setState(() => _setupRequired = false);
        },
      );
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) return HomePage(role: state.user.role);
        return const LoginPage();
      },
    );
  }
}