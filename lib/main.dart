// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/services/hie_api_service.dart';
import 'core/sync/sync_manager.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the facility's own Firebase project (Auth + Firestore)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // NOTE: initSharedIndex() removed — the shared patient/facility index is
  // now served by the AfyaLink HIE Gateway Express API (HieApiService).
  // No second Firebase project is needed.

  await di.init();
  await SyncManager().init();

  // ── AfyaLink HIE Integration ───────────────────────────────────────────
  // Replace this URL with your deployed Render backend URL.
  // For local development use: http://10.0.2.2:4000  (Android emulator)
  //                       or:  http://localhost:4000   (iOS simulator)
  HieApiService.init(
    const String.fromEnvironment(
      'HIE_BACKEND_URL',
      defaultValue: 'https://clinic-connect-sxct.onrender.com',
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}