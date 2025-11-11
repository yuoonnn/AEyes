import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user.dart' as app_user;

class GuardianRegistrationScreen extends StatefulWidget {
  const GuardianRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<GuardianRegistrationScreen> createState() => _GuardianRegistrationScreenState();
}

class _GuardianRegistrationScreenState extends State<GuardianRegistrationScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  Future<void> _handleRegistration() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authService = AuthService();
      
      // FIXED: Correct parameter order - name, email, password
      String? error = await authService.register(
        nameController.text.trim(),    // First parameter: name
        emailController.text.trim(),   // Second parameter: email  
        passwordController.text.trim(), // Third parameter: password
      );

      if (error != null) {
        setState(() {
          isLoading = false;
          errorMessage = error;
        });
        return;
      }

      // Save guardian profile to Firestore
      final databaseService = DatabaseService();
      final user = app_user.User(
        id: authService.currentUserId ?? '',
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
        role: 'guardian',
      );

      await databaseService.saveUserProfile(user);

      // Navigate to guardian dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/guardian_dashboard');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Registration failed: $e';
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = const Color(0xFF388E3C);

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(title: const Text('Guardian Registration')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Register as Guardian',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an account to monitor your ward',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  hintText: 'Full Name *',
                  controller: nameController,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Email *',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress, // Now supported
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Password *',
                  controller: passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Phone (optional)',
                  controller: phoneController,
                  keyboardType: TextInputType.phone, // Now supported
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Address (optional)',
                  controller: addressController,
                ),
                const SizedBox(height: 24),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'Register',
                      onPressed: _handleRegistration,
                      color: green,
                      textColor: Colors.white,
                    ),
                  ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}