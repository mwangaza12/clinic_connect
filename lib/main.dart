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

Future<void> runClinicApp() async {
  await di.init();
  await SyncManager().init();

  const storage = FlutterSecureStorage();
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
        home: const RootNavigator(),
      ),
    );
  }
}

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  bool _splashDone = false;

  void _onSplashComplete() {
    if (mounted) {
      setState(() {
        _splashDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show splash immediately — no blank screen while checking storage
    if (!_splashDone) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checkingSetup = true;
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    const storage = FlutterSecureStorage();
    final apiKey = await storage.read(key: StorageKeys.facilityApiKey);
    final facId = await storage.read(key: StorageKeys.facilityId);
    if (mounted) {
      setState(() {
        _needsSetup = apiKey == null || apiKey.isEmpty || facId == null || facId.isEmpty;
        _checkingSetup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSetup) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A3C2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF52B788)),
        ),
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