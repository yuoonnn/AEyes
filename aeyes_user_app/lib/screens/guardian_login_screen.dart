import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';

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
    final authService = AuthService();
    String? error = await authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );
    setState(() {
      isLoading = false;
    });
    if (error == null) {
      Navigator.pushReplacementNamed(context, '/guardian_dashboard');
    } else {
      setState(() {
        errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = const Color(0xFF388E3C);
    final greenAccent = const Color(0xFF66BB6A);
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(title: const Text('Guardian Login')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                const Text('Guardian Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Sign in to manage your ward',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  hintText: 'Email',
                  controller: emailController,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Password',
                  controller: passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'Login',
                      onPressed: _handleLogin,
                      color: green,
                      textColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Sign in with Google',
                    onPressed: () async {
                      setState(() { isLoading = true; errorMessage = null; });
                      final authService = AuthService();
                      String? error = await authService.signInWithGoogle();
                      setState(() { isLoading = false; });
                      if (error == null) {
                        Navigator.pushReplacementNamed(context, '/guardian_dashboard');
                      } else {
                        setState(() { errorMessage = error; });
                      }
                    },
                    color: Colors.white,
                    textColor: green,
                    borderColor: greenAccent,
                    icon: Icons.login,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Sign in with Facebook',
                    onPressed: () async {
                      setState(() { isLoading = true; errorMessage = null; });
                      final authService = AuthService();
                      String? error = await authService.signInWithFacebook();
                      setState(() { isLoading = false; });
                      if (error == null) {
                        Navigator.pushReplacementNamed(context, '/guardian_dashboard');
                      } else {
                        setState(() { errorMessage = error; });
                      }
                    },
                    color: Colors.white,
                    textColor: Colors.blueAccent,
                    borderColor: Colors.blueAccent,
                    icon: Icons.facebook,
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
                  onPressed: () => Navigator.pushNamed(context, '/guardian_register'),
                  child: const Text("Don't have an account? Register as Guardian"),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Back to Role Selection',
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    textColor: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 