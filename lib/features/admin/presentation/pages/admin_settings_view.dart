import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../notifications/data/services/notification_service.dart';

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  bool _isLoading = true;
  bool _registrationEnabled = true;
  bool _darkMode = false; // Local state only for now
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
    _darkMode = ThemeController().themeMode.value == ThemeMode.dark;
    // _notificationsEnabled is loaded in _fetchSettings to ensure Hive box is open
  }

  Future<void> _fetchSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_settings').get();
      if (doc.exists) {
        setState(() {
          _registrationEnabled = doc.data()?['registrationEnabled'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching settings: $e");
      setState(() => _isLoading = false);
    }
    
    // Load local settings (Safe for Hot Reload)
    try {
      if (!Hive.isBoxOpen('settingsBox')) {
        await Hive.openBox('settingsBox');
      }
      if (mounted) {
        setState(() {
           _notificationsEnabled = NotificationService().areNotificationsEnabled;
        });
      }
    } catch (e) {
      print("Error loading local settings: $e");
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await FirebaseFirestore.instance.collection('config').doc('app_settings').set(
        {key: value},
        SetOptions(merge: true),
      );
    } catch (e) {
      // Revert change on error
      setState(() => _registrationEnabled = !value);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save setting: Permission Denied.\nSee "FIREBASE_RULES.md" to fix this.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Settings',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        _SectionHeader(title: 'App Configuration'),
        SwitchListTile(
          title: const Text('Allow New User Registrations'),
          subtitle: const Text('Prevent new users from signing up'),
          secondary: const Icon(LucideIcons.userPlus),
          value: _registrationEnabled,
          onChanged: (val) {
             setState(() => _registrationEnabled = val);
             _updateSetting('registrationEnabled', val);
          },
        ),
         const Divider(),
        
        const SizedBox(height: 16),
        _SectionHeader(title: 'Admin Preferences'),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Toggle app theme'),
          secondary: const Icon(LucideIcons.moon),
          value: _darkMode,
          onChanged: (val) {
            setState(() => _darkMode = val);
            ThemeController().setTheme(val ? ThemeMode.dark : ThemeMode.light);
          },
        ),
        SwitchListTile(
          title: const Text('Push Notifications'),
          secondary: const Icon(LucideIcons.bell),
          value: _notificationsEnabled,
          onChanged: (val) {
             setState(() => _notificationsEnabled = val);
             NotificationService().setNotificationsEnabled(val);
          },
        ),
        const Divider(),

        const SizedBox(height: 16),
        _SectionHeader(title: 'System Information'),
        FutureBuilder<AggregateQuerySnapshot>(
          future: FirebaseFirestore.instance.collection('users').count().get(),
          builder: (context, snapshot) {
             final count = snapshot.data?.count ?? 0;
             return ListTile(
               leading: const Icon(LucideIcons.server),
               title: const Text('Total Users Registered'),
               trailing: Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
             );
          },
        ),
        const ListTile(
          leading: Icon(LucideIcons.info),
          title: Text('App Version'),
          trailing: Text('1.0.0'),
        ),
        const SizedBox(height: 32),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Colors.red.withOpacity(0.1),
          leading: const Icon(LucideIcons.logOut, color: Colors.red),
          title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          onTap: () async {
            await AuthService().signOut();
            if (context.mounted) {
               Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
               );
            }
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
