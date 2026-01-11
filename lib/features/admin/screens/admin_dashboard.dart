import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import 'admin_analytics_view.dart';
import 'admin_settings_view.dart';
import 'user_management_view.dart';
import 'admin_file_view.dart';
import 'admin_backup_view.dart';
import 'admin_community_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
    const AdminAnalyticsView(),
    const UserManagementView(),
    const AdminFileView(),
    const AdminCommunityView(), // New Community Tab
    const AdminBackupView(), 
    const AdminSettingsView(),
  ];

  void _handleLogout() {
    AuthService().signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard Overview';
      case 1: return 'User Management';
      case 2: return 'File Explorer';
      case 3: return 'Community Management';
      case 4: return 'System Backups';
      case 5: return 'Settings';
      default: return 'Admin Panel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(LucideIcons.shield, size: 32, color: Colors.blue),
              ),
              accountName: const Text("Admin Console"),
              accountEmail: Text(AuthService().currentUserEmail ?? "admin@airdash.com"),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(0, 'Overview', LucideIcons.layoutDashboard),
                  _buildDrawerItem(1, 'Users', LucideIcons.users),
                  _buildDrawerItem(2, 'All Files', LucideIcons.files),
                  _buildDrawerItem(3, 'Communities', LucideIcons.globe),
                  _buildDrawerItem(4, 'Backups', LucideIcons.cloud),
                  const Divider(),
                  _buildDrawerItem(5, 'Settings', LucideIcons.settings),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.logOut, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _handleLogout,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    final bool isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context); // Close drawer
      },
    );
  }
}
