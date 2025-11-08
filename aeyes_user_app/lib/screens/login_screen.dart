import 'package:flutter/material.dart';
import 'package:aeyes_user_app/l10n/app_localizations.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      Navigator.pushNamed(context, '/home');
    } else {
      setState(() {
        errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = const Color(0xFF388E3C); // Pampanga State Agricultural University inspired
    final greenAccent = const Color(0xFF66BB6A);
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with fade-in
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Image.asset(
                    'assets/AEye Logo.png',
                    height: 100,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeToAEyes,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: green,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.signInToContinue,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: CustomTextField(
                  hintText: l10n.email,
                  controller: emailController,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: CustomTextField(
                  hintText: l10n.password,
                  controller: passwordController,
                  obscureText: true,
                ),
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const CircularProgressIndicator()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: l10n.login,
                      onPressed: _handleLogin,
                      color: green,
                      textColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: l10n.signInWithGoogle,
                    onPressed: () async {
                      setState(() { isLoading = true; errorMessage = null; });
                      final authService = AuthService();
                      String? error = await authService.signInWithGoogle();
                      setState(() { isLoading = false; });
                      if (error == null) {
                        Navigator.pushNamed(context, '/home');
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
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: l10n.signInWithFacebook,
                    onPressed: () async {
                      setState(() { isLoading = true; errorMessage = null; });
                      final authService = AuthService();
                      String? error = await authService.signInWithFacebook();
                      setState(() { isLoading = false; });
                      if (error == null) {
                        Navigator.pushNamed(context, '/home');
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
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Container(
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
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: l10n.dontHaveAccount,
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    color: greenAccent,
                    textColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: l10n.backToRoleSelection,
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    textColor: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
} 