import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'help_support_screen.dart';
import 'privacy_policy_screen.dart';
import 'upgrade_screen.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../auth/presentation/pages/verification_screen.dart';
import '../../../../core/theme/theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: AuthService().getUserStream(),
      builder: (context, snapshot) {
        // Base user info from Auth (fallback)
        final authUser = FirebaseAuth.instance.currentUser;
        String userName = authUser?.displayName ?? 'User';
        String userEmail = authUser?.email ?? 'No Email';
        String? photoUrl = authUser?.photoURL;
        String phoneNumber = ''; // Default
        bool isVerified = authUser?.emailVerified ?? false;

        // Overlay Firestore data if available
        if (snapshot.hasData && snapshot.data!.exists) {
           final data = snapshot.data!.data() as Map<String, dynamic>;
           userName = data['name'] ?? userName;
           // userEmail = data['email'] ?? userEmail; // Usually same
           photoUrl = data['photoUrl'] ?? photoUrl;
           phoneNumber = data['phoneNumber'] ?? '';
        }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Card (Purple Gradient)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)], // Example gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                   BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0,10))
                ],
              ),
              child: Row(
                children: [
                   Stack(
                     children: [
                       CircleAvatar(
                         radius: 35,
                         backgroundColor: Colors.white,
                         child: CircleAvatar(
                           radius: 32,

                           backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                           child: photoUrl == null ? const Icon(LucideIcons.user, size: 30, color: Colors.grey) : null,
                         ),
                       ),
                       Positioned(
                         bottom: 0,
                         right: 0,
                         child: GestureDetector(
                           onTap: () => _showImagePicker(context),
                           child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: const BoxDecoration(
                               color: Colors.white,
                               shape: BoxShape.circle,
                             ),
                             child: const Icon(LucideIcons.camera, size: 14, color: Colors.black87),
                           ),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           userName,
                           style: GoogleFonts.outfit(
                             color: Colors.white,
                             fontSize: 20,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         Text(
                           isVerified ? 'Verified Account' : 'Unverified Account',
                           style: GoogleFonts.outfit(
                             color: Colors.white.withOpacity(0.8),
                             fontSize: 14,
                           ),
                         ),
                       ],
                     ),
                   ),
                   IconButton(
                     icon: const Icon(LucideIcons.edit2, color: Colors.white),
                     onPressed: () {
                        // TODO: Edit Profile Dialog
                        _showEditProfileDialog(context, userName, phoneNumber, authUser);
                     },
                   )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // GENERAL Section
            _buildSectionHeader(context, "GENERAL"),
            _buildSettingsTile(
              context,
              icon: LucideIcons.user,
              title: "Personal Information",
              onTap: () => _showEditProfileDialog(context, userName, phoneNumber, authUser),
            ),
             _buildSettingsTile(
              context,
              icon: LucideIcons.crown,
              title: "Upgrade to Pro",
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                child: Text('PRO', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen())),
            ),
            _buildSettingsTile(
              context,
              icon: LucideIcons.badgeCheck,
              title: "Verify Account",
              onTap: () async {
                  if (authUser != null && !authUser.emailVerified) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VerificationScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already verified.')));
                  }
              },
            ),
             _buildSettingsTile(
              context,
              icon: LucideIcons.lock,
              title: "Change Password",
              onTap: () {
                  if (userEmail.isNotEmpty) {
                    AuthService().resetPassword(userEmail);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent to $userEmail')));
                  }
              },
            ),

            const SizedBox(height: 20),

            // APPEARANCE Section
            _buildSectionHeader(context, "APPEARANCE"),
            ValueListenableBuilder(
              valueListenable: ThemeController().themeMode,
              builder: (context, themeMode, _) {
                 final isDark = themeMode == ThemeMode.dark;
                 return _buildSettingsTile(
                   context,
                   icon: LucideIcons.moon,
                   title: "Dark Mode",
                   trailing: Switch(
                     value: isDark,
                     activeColor: Theme.of(context).colorScheme.primary,
                     onChanged: (_) => ThemeController().toggleTheme(),
                   ),
                 );
              },
            ),

            const SizedBox(height: 20),

            // SUPPORT Section
            _buildSectionHeader(context, "SUPPORT"),
            _buildSettingsTile(
              context,
              icon: LucideIcons.helpCircle,
              title: "Help & Support",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
            ),
             _buildSettingsTile(
              context,
              icon: LucideIcons.shieldCheck,
              title: "Privacy Policy",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),

            const SizedBox(height: 30),
             // Logout
            ListTile(
               contentPadding: EdgeInsets.zero,
               onTap: () async {
                 await AuthService().signOut();
                 Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                 );
               },
               leading: Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: Colors.red.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(10),
                 ),
                 child: const Icon(LucideIcons.logOut, color: Colors.red),
               ),
               title: Text(
                 "Log Out",
                 style: GoogleFonts.outfit(
                   fontWeight: FontWeight.w600,
                   fontSize: 16,
                   color: Colors.red,
                 ),
               ),
            ),
             const SizedBox(height: 20),
             Center(child: Text("Version 1.0.0", style: TextStyle(color: Colors.grey[400]))),
          ],
        ),
      ),
    );

      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: trailing ?? Icon(LucideIcons.chevronRight, size: 20, color: Colors.grey[400]),
      ),
    );
  }

  Future<void> _showImagePicker(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change Profile Photo', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerOption(context, icon: LucideIcons.camera, label: 'Camera', source: ImageSource.camera),
                _buildPickerOption(context, icon: LucideIcons.image, label: 'Gallery', source: ImageSource.gallery),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption(BuildContext context, {required IconData icon, required String label, required ImageSource source}) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context); // Close sheet
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
        
        if (image != null) {
          _uploadImage(context, File(image.path));
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _uploadImage(BuildContext context, File file) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AuthService().updateProfilePicture(file);
      Navigator.pop(context); // Close loader
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
      
      // Force Rebuild/Update UI? 
      // Since it's a StatelessWidget, we might rely on the AuthService stream or just navigate/replace.
      // Or better, convert ProfileScreen to StatefulWidget to setState or rely on AuthChanges.
      // For now, let's just show the success message. The user object in build() is synchronous. 
      // A quick hack for a StatelessWidget to refresh is to push replacement or just let user re-enter.
      // Ideally, ProfileScreen should listen to Auth stream.
    } catch (e) {
      Navigator.pop(context); // Close loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showEditProfileDialog(BuildContext context, String currentName, String currentPhone, User? user) {
      if (user == null) return;
      final nameController = TextEditingController(text: currentName);
      final phoneController = TextEditingController(text: currentPhone);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
           title: const Text('Edit Profile'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               TextField(
                 controller: nameController,
                 decoration: const InputDecoration(labelText: 'Display Name'),
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: phoneController,
                 decoration: const InputDecoration(labelText: 'Phone Number'),
                 keyboardType: TextInputType.phone,
               ),
             ],
           ),
           actions: [
             TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
             FilledButton(
               onPressed: () async {
                  try {
                    // Update Name
                    if (nameController.text != currentName) {
                       await user.updateDisplayName(nameController.text);
                       await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                         'name': nameController.text
                       });
                    }
                    
                    // Update Phone (Firestore only)
                    if (phoneController.text != currentPhone) {
                       await AuthService().updatePhoneNumber(phoneController.text);
                    }

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
               },
               child: const Text('Save'),
             ),
           ],
        ),
      );
  }
}
