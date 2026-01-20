import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart'; // Added
import '../../../core/utils/responsive_layout.dart';
import '../../files/screens/file_explorer_view.dart';
import '../../profile/screens/profile_screen.dart';
import 'dart:async';
import 'dart:convert'; // Added for base64Decode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Added
import '../../notifications/services/notification_service.dart';
import '../../notifications/models/notification_model.dart'; // Added
import '../../notifications/screens/notification_screen.dart'; // Added
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
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("$title: $body"),
                                    backgroundColor: Colors.red, 
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
                                )
                            );

                            NotificationService().addNotification(title: title, body: body);

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

  String _getPageTitle() {
      switch (_selectedIndex) {
          case 0: return 'Dashboard';
          case 1: return 'Your Files';
          case 2: return 'Profile';
          default: return 'AirDash';
      }
  }

  List<Widget> _buildActions() {
      if (_selectedIndex == 0) { // Home: Show Notification Bell
          return [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell), 
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                    }
                  ),
                  // Unread Badge
                  ValueListenableBuilder(
                    valueListenable: Hive.box<NotificationModel>('notificationsBox').listenable(),
                    builder: (_, Box<NotificationModel> box, __) {
                       final unread = box.values.where((n) => !n.isRead).length;
                       if (unread == 0) return const SizedBox.shrink();
                       return Positioned(
                         right: 8,
                         top: 8,
                         child: Container(
                           padding: const EdgeInsets.all(4),
                           decoration: const BoxDecoration(
                             color: Colors.red,
                             shape: BoxShape.circle,
                           ),
                           child: Text(
                             unread > 9 ? '9+' : unread.toString(),
                             style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                           ),
                         ),
                       );
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8),
          ];
      }
      return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getPageTitle(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: _buildActions(),
      ),
      drawer: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
            String displayName = FirebaseAuth.instance.currentUser?.displayName ?? "User";
            String email = FirebaseAuth.instance.currentUser?.email ?? "";
            String? photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
            String? photoBase64;

            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                displayName = data['name'] ?? displayName;
                // email = data['email'] ?? email;
                photoUrl = data['photoUrl'] ?? photoUrl;
                photoBase64 = data['photoBase64'];
            }

            ImageProvider? backgroundImage;
            if (photoBase64 != null) {
                try {
                    backgroundImage = MemoryImage(base64Decode(photoBase64));
                } catch (_) {}
            } else if (photoUrl != null) {
                backgroundImage = NetworkImage(photoUrl);
            }

            return Drawer(
              child: Column(
                children: [
                   UserAccountsDrawerHeader(
                     accountName: Text(displayName),
                     accountEmail: Text(email),
                     currentAccountPicture: CircleAvatar(
                       backgroundColor: Colors.white,
                       backgroundImage: backgroundImage,
                       child: backgroundImage == null ? const Icon(LucideIcons.user, size: 30) : null,
                     ),
                     decoration: BoxDecoration(
                         color: Theme.of(context).primaryColor,
                     ),
                   ),
                   ListTile(
                     leading: const Icon(LucideIcons.layoutDashboard),
                     title: const Text("Home"),
                     selected: _selectedIndex == 0,
                     onTap: () {
                       setState(() => _selectedIndex = 0);
                       Navigator.pop(context);
                     },
                   ),
                   ListTile(
                     leading: const Icon(LucideIcons.folder),
                     title: const Text("Files"),
                     selected: _selectedIndex == 1,
                     onTap: () {
                       setState(() => _selectedIndex = 1);
                       Navigator.pop(context);
                     },
                   ),
                   ListTile(
                     leading: const Icon(LucideIcons.user),
                     title: const Text("Profile"),
                     selected: _selectedIndex == 2,
                     onTap: () {
                        setState(() => _selectedIndex = 2);
                        Navigator.pop(context);
                     },
                   ),
                   const Spacer(),
                   const Divider(),
                   ListTile(
                     leading: const Icon(LucideIcons.logOut, color: Colors.red),
                     title: const Text("Logout", style: TextStyle(color: Colors.red)),
                     onTap: () async {
                         await FirebaseAuth.instance.signOut();
                     },
                   ),
                   const SizedBox(height: 16),
                ],
              ),
            );
        }
      ),
      body: _pages[_selectedIndex],
    );
  }
}
