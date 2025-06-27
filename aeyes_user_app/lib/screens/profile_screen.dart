import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/main_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController(text: 'John Doe');
  final TextEditingController emailController = TextEditingController(text: 'test@example.com');
  final TextEditingController phoneController = TextEditingController(text: '+1234567890');
  final TextEditingController addressController = TextEditingController(text: '123 Main St, City');
  bool isEditing = false;
  String? successMessage;

  void _toggleEdit() {
    setState(() {
      isEditing = !isEditing;
      successMessage = null;
    });
  }

  void _saveProfile() {
    setState(() {
      isEditing = false;
      successMessage = 'Profile updated successfully!';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('User Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CustomTextField(
                        hintText: 'Name',
                        controller: nameController,
                        obscureText: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CustomTextField(
                        hintText: 'Email',
                        controller: emailController,
                        obscureText: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CustomTextField(
                        hintText: 'Phone',
                        controller: phoneController,
                        obscureText: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CustomTextField(
                        hintText: 'Address',
                        controller: addressController,
                        obscureText: false,
                      ),
                    ),
                    const SizedBox(height: 24),
                    isEditing
                        ? CustomButton(
                            label: 'Save',
                            onPressed: _saveProfile,
                          )
                        : CustomButton(
                            label: 'Edit',
                            onPressed: _toggleEdit,
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 