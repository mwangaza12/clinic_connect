import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../../core/config/facility_info.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/sync/connectivity_manager.dart';
import '../../domain/entities/user.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginView();
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _obscurePassword = true;
  bool _isOnline = true;
  bool _hasSavedCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _checkSavedCredentials();
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityManager().checkConnectivity();
    if (mounted) setState(() => _isOnline = online);
  }

  Future<void> _checkSavedCredentials() async {
    try {
      final savedUser = await _secureStorage.read(key: 'offline_user');
      if (savedUser != null && mounted) {
        setState(() => _hasSavedCredentials = true);
      }
    } catch (e) {
      debugPrint('Error checking saved credentials: $e');
    }
  }

  Future<void> _saveCredentialsOffline(User user) async {
    try {
      // Save user data securely for offline login
      final userJson = jsonEncode({
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'role': user.role,
        'facilityId': user.facilityId,
        'facilityName': user.facilityName,
        'lastLogin': DateTime.now().toIso8601String(),
      });
      await _secureStorage.write(key: 'offline_user', value: userJson);
      await _secureStorage.write(key: 'offline_password', value: _passwordController.text);
    } catch (e) {
      debugPrint('Error saving offline credentials: $e');
    }
  }

  Future<void> _offlineLogin() async {
    try {
      final savedUserJson = await _secureStorage.read(key: 'offline_user');
      final savedPassword = await _secureStorage.read(key: 'offline_password');
      
      if (savedUserJson != null && savedPassword != null) {
        final userData = jsonDecode(savedUserJson);
        
        // Verify password matches saved one
        if (savedPassword == _passwordController.text) {
          final user = User(
            id: userData['id'],
            email: userData['email'],
            name: userData['name'],
            role: userData['role'],
            facilityId: userData['facilityId'],
            facilityName: userData['facilityName'],
          );
          
          // Set FacilityInfo
          FacilityInfo().set(
            facilityId: user.facilityId,
            facilityName: user.facilityName,
          );
          
          // Emit Authenticated state
          if (mounted) {
            context.read<AuthBloc>().add(OfflineLoginSuccess(user));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid offline credentials'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No saved offline session found'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Offline login error: $e');
    }
  }

  Future<void> _clearOfflineCredentials() async {
    await _secureStorage.delete(key: 'offline_user');
    await _secureStorage.delete(key: 'offline_password');
    if (mounted) {
      setState(() => _hasSavedCredentials = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      if (!_isOnline) {
        // Try offline login first
        _offlineLogin();
      } else {
        // Online login
        context.read<AuthBloc>().add(
              LoginRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2D6A4F);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          
          if (state is Authenticated) {
            // Save credentials for offline use when online login succeeds
            _saveCredentialsOffline(state.user);
            
            // Set the FacilityInfo singleton
            FacilityInfo().set(
              facilityId: state.user.facilityId,
              facilityName: state.user.facilityName,
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Background Decorative Elements
              Positioned(
                top: -100,
                right: -100,
                child: CircleAvatar(radius: 150, backgroundColor: primaryColor.withOpacity(0.05)),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: CircleAvatar(radius: 100, backgroundColor: primaryColor.withOpacity(0.05)),
              ),
              
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Offline/Online Status Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _isOnline ? const Color(0xFFD4EDDA) : const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isOnline ? const Color(0xFF28A745) : const Color(0xFFFFCA28),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                  color: _isOnline ? const Color(0xFF155724) : const Color(0xFF856404),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isOnline
                                        ? 'You are online. Login with your credentials.'
                                        : _hasSavedCredentials
                                            ? 'You are offline. You can login using your saved session.'
                                            : 'You are offline. No saved session found.',
                                    style: TextStyle(
                                      color: _isOnline ? const Color(0xFF155724) : const Color(0xFF856404),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (!_isOnline && _hasSavedCredentials)
                                  TextButton(
                                    onPressed: _clearOfflineCredentials,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF856404)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Brand Logo Section
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.local_hospital_rounded, size: 50, color: primaryColor),
                            ),
                          ),
                          const SizedBox(height: 32),

                          Text(
                            'ClinicConnect',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Interoperable EHR for Kenya',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blueGrey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Email Field
                          _buildInputField(
                            label: 'Email Address',
                            controller: _emailController,
                            icon: Icons.email_outlined,
                            hint: 'your.email@facility.ke',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter your email';
                              if (!_isOnline && _hasSavedCredentials) {
                                // Offline mode with saved credentials - email is optional for validation
                                return null;
                              }
                              if (!value.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          _buildInputField(
                            label: 'Password',
                            controller: _passwordController,
                            icon: Icons.lock_outlined,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF64748B),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter your password';
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),
                          
                          // Offline Mode Hint
                          if (!_isOnline && _hasSavedCredentials)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F3FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFF004085), size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Offline mode: Enter your password to access your last saved session.',
                                        style: TextStyle(
                                          color: Color(0xFF004085),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isOnline ? () {} : null,
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: _isOnline ? primaryColor : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          ElevatedButton(
                            onPressed: state is AuthLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 8,
                              shadowColor: primaryColor.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: state is AuthLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    !_isOnline && _hasSavedCredentials ? 'Offline Login' : 'Login to Dashboard',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),

                          if (!_isOnline && !_hasSavedCredentials) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8D7DA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.error_outline, color: Color(0xFF721C24)),
                                  SizedBox(height: 8),
                                  Text(
                                    'No offline session available. Please connect to the internet to login.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF721C24),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Modern Input Builder
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: const Color(0xFF2D6A4F)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}