// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

// Called by flavor entry points after Firebase + storage is pre-seeded.
// main_facility_a.dart and main_facility_b.dart call this after:
//   1. Firebase.initializeApp() with their own FirebaseOptions
//   2. Writing facilityId, facilityApiKey, hieGatewayUrl to secure storage
// AuthWrapper._checkSetup() then finds keys already set → skips SetupWizard.
Future<void> runClinicApp() async {
  await di.init();
  await SyncManager().init();

  const storage  = FlutterSecureStorage();
  final savedUrl = await storage.read(key: StorageKeys.hieGatewayUrl);

  HieApiService.init(
    savedUrl?.isNotEmpty == true
        ? savedUrl!
        : const String.fromEnvironment(
            'HIE_BACKEND_URL',
            defaultValue: 'https://hie-gateway.onrender.com',
          ),
  );

  runApp(const ClinicConnectApp());
}

// Default entry point — used by plain `flutter run`
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await runClinicApp();
}

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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A4F)),
          useMaterial3: true,
        ),
        // SplashScreen is the first route. It either:
        //   a) pops to AuthWrapper after 2.5s (onboarding already seen), or
        //   b) navigates to OnboardingPage (first launch), which then pops
        //      back to AuthWrapper on "Get Started".
        home: const _RootNavigator(),
      ),
    );
  }
}

/// Wraps AuthWrapper in a Navigator so SplashScreen and OnboardingPage
/// can push/pop without touching the app's main navigation stack.
class _RootNavigator extends StatelessWidget {
  const _RootNavigator();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => Stack(
          children: const [
            AuthWrapper(),           // always rendered underneath
            SplashScreen(),          // slides over on top; pops when done
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checkingSetup = true;
  bool _needsSetup    = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    const storage = FlutterSecureStorage();
    final apiKey  = await storage.read(key: StorageKeys.facilityApiKey);
    final facId   = await storage.read(key: StorageKeys.facilityId);
    if (mounted) {
      setState(() {
        _needsSetup    = apiKey == null || apiKey.isEmpty || facId == null || facId.isEmpty;
        _checkingSetup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSetup) {
      // Minimal loading state — splash screen is covering this anyway
      return const Scaffold(
        backgroundColor: Color(0xFF1A3C2E),
        body: SizedBox.shrink(),
      );
    }
    if (_needsSetup) {
      return SetupWizardPage(
        onComplete: () => setState(() => _needsSetup = false),
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