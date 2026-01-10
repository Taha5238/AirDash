import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../files/screens/file_explorer_view.dart';
import '../../profile/screens/profile_screen.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../notifications/services/notification_service.dart';
import 'home_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupRemoteNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupRemoteNotifications() {
     final user = FirebaseAuth.instance.currentUser;
     if (user != null) {
        _notificationSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .snapshots()
            .listen((snapshot) {
                for (var change in snapshot.docChanges) {
                    if (change.type == DocumentChangeType.added) {
                        final data = change.doc.data();
                        if (data != null) {
                            final title = data['title'] ?? 'Notification';
                            final body = data['body'] ?? '';
                            
                            // 1. Show Local Notification (Snackbar for now, or use Service)
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("$title: $body"),
                                    backgroundColor: Colors.red, 
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
                                )
                            );

                            // 2. Add to Local Hive History
                            NotificationService().addNotification(title: title, body: body);

                            // 3. Delete from Server (Mark as handled)
                            change.doc.reference.delete(); 
                        }
                    }
                }
            });
     }
  }

  List<Widget> get _pages => [
      HomeView(onNavigateToFiles: () {
          setState(() {
            _selectedIndex = 1;
          });
      }),
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
