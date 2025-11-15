import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart'; // Added import
import '../models/user.dart' as app_user; // Added import

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
  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Add listeners to update button state when fields change
    emailController.addListener(_updateButtonState);
    passwordController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    emailController.removeListener(_updateButtonState);
    passwordController.removeListener(_updateButtonState);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {}); // Trigger rebuild to update button state
  }

  bool get _isFormValid {
    return emailController.text.trim().isNotEmpty &&
        passwordController.text.trim().isNotEmpty;
  }

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter both email and password before continuing.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final authService = AuthService();
    String? error = await authService.login(email, password);
    setState(() {
      isLoading = false;
    });
    if (error == null) {
      // Call debug function before navigation
      await debugGuardianLogin();
      Navigator.pushReplacementNamed(context, '/guardian_dashboard');
    } else {
      setState(() {
        errorMessage = error;
      });
    }
  }

  // Create missing guardian profile if needed
  Future<void> ensureGuardianProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final existingProfile = await DatabaseService().getUserProfile();
      if (existingProfile == null) {
        print('⚠️ Guardian profile missing - creating now...');
        await DatabaseService().saveUserProfile(app_user.User(
          id: user.uid,
          email: user.email!,
          name: user.displayName ?? 'Guardian',
          role: 'guardian',
          createdAt: DateTime.now(),
        ));
        print('✅ Created missing guardian profile');
      } else {
        print('✅ Guardian profile already exists');
      }
    }
  }

  // After guardian login, debug what's happening
  Future<void> debugGuardianLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    print('=== GUARDIAN LOGIN DEBUG ===');
    print('🔐 Guardian logged in with UID: ${user?.uid}');
    print('📧 Guardian email: ${user?.email}');
    
    try {
      // Ensure guardian has a profile
      await ensureGuardianProfile();
      
      // Try to load guardian's own profile
      final profile = await DatabaseService().getUserProfile();
      print('✅ Guardian profile loaded: ${profile != null}');
      if (profile != null) {
        print('   - Name: ${profile.name}');
        print('   - Role: ${profile.role}');
      }
      
      // Try to query guardians collection
      final guardians = await DatabaseService().getLinkedUsersForGuardian(user?.email ?? '');
      print('✅ Guardian links found: ${guardians.length}');
      
      for (final guardian in guardians) {
        print('   - Linked user: ${guardian['name']} (${guardian['user_id']})');
      }
      
      print('=== DEBUG COMPLETE ===');
    } catch (e) {
      print('❌ Error during debug: $e');
      print('=== DEBUG FAILED ===');
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.orange[900] : Colors.orange[100])?.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'New guardian? Please register first before logging in.',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.orange[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  hintText: 'Email',
                  controller: emailController,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Password',
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'Login',
                      onPressed: _isFormValid ? _handleLogin : null,
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
                        await debugGuardianLogin(); // Added debug call
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
                        await debugGuardianLogin(); // Added debug call
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