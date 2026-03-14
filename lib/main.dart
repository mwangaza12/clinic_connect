// lib/main.dart
//
// Single entry point — one APK for all facilities.
// Firebase initializes dynamically from saved credentials on cold start.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/config/firebase_config.dart';
import 'core/constants/storage_keys.dart';
import 'core/services/hie_api_service.dart';
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

  final results = await Future.wait([
    storage.read(key: StorageKeys.hieGatewayUrl),
    storage.read(key: StorageKeys.facilityApiKey),
    storage.read(key: StorageKeys.facilityId),
  ]);

  final gatewayUrl = results[0];
  final apiKey     = results[1];
  final facilityId = results[2];

  // Init HIE service — needed even before Firebase (for setup wizard)
  HieApiService.init(
    gatewayUrl?.isNotEmpty == true
        ? gatewayUrl!
        : const String.fromEnvironment(
            'HIE_BACKEND_URL',
            defaultValue: 'https://hie-gateway.onrender.com',
          ),
  );

  // Try to restore Firebase from saved credentials (no network call)
  final firebaseReady = await FirebaseConfig.restoreFromStorage();

  // Setup is required if Firebase isn't ready or gateway creds are missing
  appNeedsSetup = !firebaseReady ||
      apiKey     == null || apiKey.isEmpty     ||
      facilityId == null || facilityId.isEmpty;

  // Only init DI and SyncManager when Firebase is ready
  if (!appNeedsSetup) {
    await di.init();
    await SyncManager().init();
  }
}

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // No Firebase.initializeApp() here — done dynamically in FirebaseConfig
  await _initApp();

  runApp(const ClinicConnectApp());
}

// ── App ───────────────────────────────────────────────────────────────────────

class ClinicConnectApp extends StatelessWidget {
  const ClinicConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'ClinicConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A4F)),
        useMaterial3: true,
      ),
      home: const RootNavigator(),
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
        onComplete: () async {
          // Firebase is ready now — initialize DI and SyncManager
          await di.init();
          await SyncManager().init();
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