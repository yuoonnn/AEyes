import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/main_scaffold.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';
import '../models/user.dart' as app_user;

class ProfileScreen extends StatefulWidget {
  final TTSService? ttsService;
  
  const ProfileScreen({Key? key, this.ttsService}) : super(key: key);

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
  bool isDeletingAccount = false;

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
          const SnackBar(
            content: Text('Guardian linked successfully!'),
          ),
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

  Future<void> _deleteGuardian(String guardianId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Guardian'),
        content: const Text(
          'Are you sure you want to remove this guardian? They will no longer be able to access your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);
    try {
      await _databaseService.deleteGuardian(guardianId);
      await _loadGuardians();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardian removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing guardian: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.grey[300] : Colors.black87,
        ) ??
        TextStyle(
          color: isDark ? Colors.grey[300] : Colors.black87,
          fontSize: 16,
        );
    final cancelColor = isDark ? Colors.grey[200] : Colors.grey[700];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account', style: titleStyle),
        content: Text(
          'Deleting your account will remove all of your data, linked guardians, messages, and devices. This action cannot be undone.\n\nAre you sure you want to continue?',
          style: contentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: cancelColor),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    setState(() {
      isDeletingAccount = true;
    });

    final result = await _authService.deleteCurrentAccount(isGuardian: false);

    if (!mounted) return;

    setState(() {
      isDeletingAccount = false;
    });

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _showLinkGuardianDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
    final cancelColor = isDark ? Colors.grey[200] : Colors.grey[700];

    // Clear controllers when opening dialog
    guardianNameController.clear();
    guardianEmailController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Link Guardian', style: titleStyle),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: cancelColor),
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
      currentIndex: 3,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.person, color: Color(0xFF388E3C)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            guardian['guardian_name'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            guardian['guardian_email'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Chip(
                                          label: Text(
                                            guardian['relationship_status'] == 'active'
                                                ? 'Active'
                                                : 'Pending',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          backgroundColor:
                                              guardian['relationship_status'] == 'active'
                                                  ? Colors.green.shade100
                                                  : Colors.orange.shade100,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () =>
                                              _deleteGuardian(guardian['guardian_id'] as String),
                                          tooltip: 'Remove guardian',
                                        ),
                                      ],
                                    ),
                                  ],
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
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Danger Zone',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Deleting your account will permanently remove your profile, linked guardians, devices, locations, and messages.',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: isDeletingAccount ? null : _confirmDeleteAccount,
                                    icon: isDeletingAccount
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.red,
                                            ),
                                          )
                                        : const Icon(Icons.delete_forever),
                                    label: Text(
                                      isDeletingAccount ? 'Deleting...' : 'Delete Account',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
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