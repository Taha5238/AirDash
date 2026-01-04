import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import 'admin_analytics_view.dart';
import 'admin_settings_view.dart';
import 'user_management_view.dart';
import 'admin_file_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminAnalyticsView(),
    const UserManagementView(),
    const AdminFileView(),
    const AdminSettingsView(),
  ];

  void _handleLogout() {
    AuthService().signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.layoutDashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.users),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.files),
            label: 'All Files',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
