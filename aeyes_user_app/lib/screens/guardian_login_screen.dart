import 'package:flutter/material.dart';

class GuardianLoginScreen extends StatefulWidget {
  const GuardianLoginScreen({Key? key}) : super(key: key);

  @override
  State<GuardianLoginScreen> createState() => _GuardianLoginScreenState();
}

class _GuardianLoginScreenState extends State<GuardianLoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await Future.delayed(const Duration(seconds: 1)); // Mock delay
    setState(() {
      isLoading = false;
    });
    if (emailController.text == 'guardian@example.com' && passwordController.text == 'password123') {
      Navigator.pushReplacementNamed(context, '/guardian_dashboard');
    } else {
      setState(() {
        errorMessage = 'Invalid email or password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Login')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Guardian Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        child: const Text('Login'),
                      ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {}, // To be implemented: guardian registration
                  child: const Text("Don't have an account? Register as Guardian"),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Role Selection'),
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 