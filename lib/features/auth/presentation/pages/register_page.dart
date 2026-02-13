import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _facilityNameController = TextEditingController();
  String _selectedRole = 'doctor';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _facilityNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'facility_id':
            'facility_${DateTime.now().millisecondsSinceEpoch}',
        'facility_name': _facilityNameController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Account created! Please login.'),
            backgroundColor: const Color(0xFF2D6A4F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already registered';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2D6A4F);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Account', 
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Decorative background circles
          Positioned(top: -50, left: -50, child: CircleAvatar(radius: 80, backgroundColor: primaryColor.withOpacity(0.05))),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Setup Your Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Join the interoperable health network in Kenya.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                    ),
                    const SizedBox(height: 32),

                    _buildFieldLabel('Full Name'),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Dr. John Mwangi',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),

                    _buildFieldLabel('Work Email'),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'john@facility.ke',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildFieldLabel('Password'),
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Min. 6 characters',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Password too short' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildFieldLabel('Your Professional Role'),
                    _buildDropdownField(),
                    const SizedBox(height: 20),

                    _buildFieldLabel('Healthcare Facility'),
                    _buildTextField(
                      controller: _facilityNameController,
                      hint: 'Kijiji Health Center',
                      icon: Icons.local_hospital_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter facility name' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          children: [
                            TextSpan(text: "Already have an account? "),
                            TextSpan(text: "Login", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF2D6A4F), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 16),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.work_outline_rounded, color: Color(0xFF2D6A4F), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 2)),
      ),
      items: const [
        DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
        DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
        DropdownMenuItem(value: 'lab_tech', child: Text('Lab Technician')),
        DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist')),
        DropdownMenuItem(value: 'admin', child: Text('Administrator')),
      ],
      onChanged: (value) => setState(() => _selectedRole = value!),
    );
  }
}