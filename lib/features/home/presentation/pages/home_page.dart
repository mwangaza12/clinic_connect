// lib/features/home/presentation/pages/home_page.dart
//
// Thin router. Reads the [role] passed from AuthWrapper and
// delegates to the matching shell page.
//
// Add a new role? Add one case here + create its shell file.

import 'package:flutter/material.dart';
import 'admin_shell_page.dart';
import 'doctor_shell_page.dart';
import 'nurse_shell_page.dart';

class HomePage extends StatelessWidget {
  final String role;
  const HomePage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case 'admin':
        return const AdminShellPage();
      case 'nurse':
        return const NurseShellPage();
      case 'doctor':
      default:
        return const DoctorShellPage();
    }
  }
}