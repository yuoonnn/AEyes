import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/main_scaffold.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user.dart' as app_user;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  bool isEditing = false;
  String? successMessage;
  bool isLoading = true;
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> linkedGuardians = [];
  final TextEditingController guardianEmailController = TextEditingController();
  final TextEditingController guardianNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadGuardians();
  }

  @override
  void dispose() {
    guardianEmailController.dispose();
    guardianNameController.dispose();
    super.dispose();
  }

  Future<void> _loadGuardians() async {
    try {
      final guardians = await _databaseService.getGuardians();
      setState(() {
        linkedGuardians = guardians;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _linkGuardian() async {
    if (guardianEmailController.text.trim().isEmpty || 
        guardianNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter guardian email and name')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await _databaseService.linkGuardian(
        guardianEmail: guardianEmailController.text.trim(),
        guardianName: guardianNameController.text.trim(),
      );
      
      guardianEmailController.clear();
      guardianNameController.clear();
      await _loadGuardians();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardian link request sent!')),
        );
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showLinkGuardianDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Guardian'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                hintText: 'Guardian Name',
                controller: guardianNameController,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                hintText: 'Guardian Email',
                controller: guardianEmailController,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isLoading ? null : _linkGuardian,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
            ),
            child: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        // Try to load from Firestore first
        final userProfile = await _databaseService.getUserProfile();
        
        if (userProfile != null) {
          // Load from Firestore
          setState(() {
            nameController.text = userProfile.name;
            emailController.text = userProfile.email;
            phoneController.text = userProfile.phone ?? '';
            addressController.text = userProfile.address ?? '';
            isLoading = false;
          });
        } else {
          // No Firestore data, use Firebase Auth data
          setState(() {
            nameController.text = firebaseUser.displayName ?? '';
            emailController.text = firebaseUser.email ?? '';
            phoneController.text = firebaseUser.phoneNumber ?? '';
            addressController.text = '';
            isLoading = false;
          });
          
          // Create initial profile in Firestore
          await _databaseService.saveUserProfile(
            app_user.User(
              id: firebaseUser.uid,
              name: firebaseUser.displayName ?? '',
              email: firebaseUser.email ?? '',
              phone: firebaseUser.phoneNumber,
            ),
          );
        }
      } catch (e) {
        // Fallback to Firebase Auth if Firestore fails
        setState(() {
          nameController.text = firebaseUser.displayName ?? '';
          emailController.text = firebaseUser.email ?? '';
          phoneController.text = firebaseUser.phoneNumber ?? '';
          addressController.text = '';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      isEditing = !isEditing;
      successMessage = null;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        // Update Firebase Auth display name
        await firebaseUser.updateDisplayName(nameController.text.trim());
        
        // Update email if changed (requires re-authentication for security)
        if (emailController.text.trim() != firebaseUser.email) {
          // Note: Email changes require re-authentication in production
          // For now, we'll just update it in Firestore
        }
        
        // Save to Firestore
        await _databaseService.saveUserProfile(
          app_user.User(
            id: firebaseUser.uid,
            name: nameController.text.trim(),
            email: emailController.text.trim(),
            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
            address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
            role: 'user',
          ),
        );
        
        // Reload Firebase Auth user
        await firebaseUser.reload();
        
        setState(() {
          isEditing = false;
          isLoading = false;
          successMessage = 'Profile updated successfully!';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        successMessage = 'Error updating profile: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
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
              onPressed: () async {
                await _authService.logout();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
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
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Profile Picture Section
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade300,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF388E3C),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            nameController.text.isEmpty 
                                ? 'User' 
                                : nameController.text,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emailController.text.isEmpty 
                                ? 'No email' 
                                : emailController.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 24),
                          _buildProfileField(
                            icon: Icons.person,
                            label: 'Full Name',
                            child: CustomTextField(
                              hintText: 'Enter your name',
                              controller: nameController,
                              obscureText: false,
                              enabled: isEditing,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildProfileField(
                            icon: Icons.email,
                            label: 'Email',
                            child: CustomTextField(
                              hintText: 'Enter your email',
                              controller: emailController,
                              obscureText: false,
                              enabled: isEditing,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildProfileField(
                            icon: Icons.phone,
                            label: 'Phone Number',
                            child: CustomTextField(
                              hintText: 'Enter your phone number',
                              controller: phoneController,
                              obscureText: false,
                              enabled: isEditing,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildProfileField(
                            icon: Icons.location_on,
                            label: 'Address',
                            child: CustomTextField(
                              hintText: 'Enter your address',
                              controller: addressController,
                              obscureText: false,
                              enabled: isEditing,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Guardian Linking Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shield, color: const Color(0xFF388E3C)),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Linked Guardians',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF388E3C)),
                                onPressed: _showLinkGuardianDialog,
                                tooltip: 'Link Guardian',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (linkedGuardians.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'No guardians linked. Click + to add a guardian.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          else
                            ...linkedGuardians.map((guardian) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.person, color: Color(0xFF388E3C)),
                                title: Text(guardian['guardian_name'] ?? 'Unknown'),
                                subtitle: Text(guardian['guardian_email'] ?? ''),
                                trailing: Chip(
                                  label: Text(
                                    guardian['relationship_status'] == 'active' 
                                        ? 'Active' 
                                        : 'Pending',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: guardian['relationship_status'] == 'active'
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                ),
                              ),
                            )),
                          if (successMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: successMessage!.contains('Error')
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                successMessage!,
                                style: TextStyle(
                                  color: successMessage!.contains('Error') ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          isEditing
                              ? CustomButton(
                                  label: isLoading ? 'Saving...' : 'Save',
                                  onPressed: isLoading ? () {} : () => _saveProfile(),
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
  
  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
} 