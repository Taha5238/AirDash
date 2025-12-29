import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../../core/theme/theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String userName = user?.displayName ?? 'User';
    final String userEmail = user?.email ?? 'No Email';
    final bool isVerified = user?.emailVerified ?? false;

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
                   CircleAvatar(
                     radius: 35,
                     backgroundColor: Colors.white,
                     child: CircleAvatar(
                       radius: 32,
                       backgroundImage: NetworkImage(user?.photoURL ?? 'https://i.pravatar.cc/300'),
                       child: user?.photoURL == null ? const Icon(LucideIcons.user, size: 30) : null,
                     ),
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
                        _showEditProfileDialog(context, userName, user);
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
              onTap: () => _showEditProfileDialog(context, userName, user),
            ),
            _buildSettingsTile(
              context,
              icon: LucideIcons.badgeCheck,
              title: "Verify Account",
              onTap: () async {
                  if (user != null && !user.emailVerified) {
                    await user.sendEmailVerification();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent!')));
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
              onTap: () {},
            ),
             _buildSettingsTile(
              context,
              icon: LucideIcons.shieldCheck,
              title: "Privacy Policy",
              onTap: () {},
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

  void _showEditProfileDialog(BuildContext context, String currentName, User? user) {
      if (user == null) return;
      final controller = TextEditingController(text: currentName);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
           title: const Text('Edit Profile'),
           content: TextField(
             controller: controller,
             decoration: const InputDecoration(labelText: 'Display Name'),
           ),
           actions: [
             TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
             FilledButton(
               onPressed: () async {
                  try {
                    await user.updateDisplayName(controller.text);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated! (Switch tabs to see changes)')));
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
