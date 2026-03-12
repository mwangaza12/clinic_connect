// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/constants/storage_keys.dart';
import 'core/services/hie_api_service.dart';
import 'core/sync/sync_manager.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/setup_wizard_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/onboarding/presentation/pages/splash_screen.dart';
import 'injection_container.dart' as di;

/// Resolved once before [runApp] so [AuthWrapper] can read it synchronously —
/// zero async gap, no loading spinner ever shown to the user.
late final bool appNeedsSetup;

Future<void> _initApp() async {
  await di.init();
  await SyncManager().init();

  const storage = FlutterSecureStorage();

  // Read all keys in parallel to keep startup fast.
  final results = await Future.wait([
    storage.read(key: StorageKeys.hieGatewayUrl),
    storage.read(key: StorageKeys.facilityApiKey),
    storage.read(key: StorageKeys.facilityId),
  ]);

  final savedUrl = results[0];
  final apiKey   = results[1];
  final facId    = results[2];

  HieApiService.init(
    savedUrl?.isNotEmpty == true
        ? savedUrl!
        : const String.fromEnvironment(
            'HIE_BACKEND_URL',
            defaultValue: 'https://hie-gateway.onrender.com',
          ),
  );

  // Cached globally so AuthWrapper never needs its own async check.
  appNeedsSetup =
      apiKey == null || apiKey.isEmpty || facId == null || facId.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  // Must be called first — before any async work — so the native splash is
  // held open and there is never a blank frame between platform and Flutter.
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        title: 'ClinicConnect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A4F)),
          useMaterial3: true,
        ),
        home: const RootNavigator(),
      ),
    );
  }
}

// ── RootNavigator ─────────────────────────────────────────────────────────────
//
// Flow:
//   1. Renders [SplashScreen] (the animated Flutter splash).
//   2. [SplashScreen] calls onComplete when its animation finishes.
//   3. We remove the *native* splash at that exact moment — one seamless
//      transition, no white/blank frames, no double-splash.
//   4. Switch to [AuthWrapper].

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  bool _splashDone = false;

  void _onSplashComplete() {
    // Dismiss the native splash now that the Flutter animated splash
    // has taken over — no double-splash, no white frame.
    FlutterNativeSplash.remove();
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    return const AuthWrapper();
  }
}

// ── AuthWrapper ───────────────────────────────────────────────────────────────
//
// [appNeedsSetup] is resolved before runApp, so this widget reads it
// synchronously — no async check, no loading state, no spinner, no green page.

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  /// Local mutable copy so completing setup clears the flag instantly.
  late bool _setupRequired = appNeedsSetup;

  @override
  Widget build(BuildContext context) {
    if (_setupRequired) {
      return SetupWizardPage(
        onComplete: () => setState(() => _setupRequired = false),
      );
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return HomePage(role: state.user.role);
        }
        return const LoginPage();
      },
    );
  }
}