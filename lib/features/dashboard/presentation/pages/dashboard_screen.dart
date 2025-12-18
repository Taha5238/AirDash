import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../files/presentation/pages/file_explorer_view.dart';
import '../../../various/presentation/pages/profile_screen.dart';
import 'home_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeView(),
    const FileExplorerView(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);
    final bool isTablet = ResponsiveLayout.isTablet(context);
    final bool showRail = isDesktop || isTablet;

    return Scaffold(
      body: Row(
        children: [
          if (showRail)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(LucideIcons.layoutDashboard),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.folder),
                  label: Text('Files'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.user),
                  label: Text('Profile'),
                ),
              ],
            ),
          if (showRail) const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: (!showRail)
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(LucideIcons.layoutDashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.folder),
                  label: 'Files',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.user),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}
