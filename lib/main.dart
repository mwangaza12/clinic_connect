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
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<AuthBloc>(),
      child: MaterialApp(
        title: 'ClinicConnect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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