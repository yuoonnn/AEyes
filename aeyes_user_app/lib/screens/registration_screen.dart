import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String? successMessage;
  String? errorMessage;

  Future<void> _handleRegister() async {
    setState(() {
      isLoading = true;
      successMessage = null;
      errorMessage = null;
    });
    final authService = AuthService();
    String? error = await authService.register(
      nameController.text.trim(),
      emailController.text.trim(),
      passwordController.text.trim(),
    );
    setState(() {
      isLoading = false;
      if (error == null) {
        successMessage = 'Registration successful!';
      } else {
        errorMessage = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Register', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: CustomTextField(
                  hintText: 'Name',
                  controller: nameController,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: CustomTextField(
                  hintText: 'Email',
                  controller: emailController,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: CustomTextField(
                  hintText: 'Password',
                  controller: passwordController,
                  obscureText: true,
                ),
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const CircularProgressIndicator()
              else
                CustomButton(
                  label: 'Register',
                  onPressed: _handleRegister,
                ),
              if (successMessage != null) ...[
                const SizedBox(height: 16),
                Text(successMessage!, style: const TextStyle(color: Colors.green)),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              CustomButton(
                label: 'Already have an account? Login',
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Back to Role Selection',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 