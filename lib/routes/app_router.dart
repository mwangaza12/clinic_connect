import 'package:flutter/material.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/patient/presentation/pages/patient_registration_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomePage());
      
      case '/patient/register':
        return MaterialPageRoute(builder: (_) => const PatientRegistrationPage());
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}