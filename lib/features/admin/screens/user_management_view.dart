import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_file_view.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search users by name or email...',
              prefixIcon: const Icon(LucideIcons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // User List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Error loading users'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
              final allUsers = snapshot.data!.docs;
              
              // Client-side filtering (efficient for this scale)
              final users = allUsers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || email.contains(_searchQuery);
              }).toList();
        
              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.userX, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
        
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userDoc = users[index];
                  final data = userDoc.data() as Map<String, dynamic>;
                  final isBlocked = data['accountStatus'] == 'blocked';
                  final isAdmin = data['role'] == 'admin';
                  final storageUsed = data['storageUsed'] ?? 0;
                  final fileCount = data['fileCount'] ?? 0;
                  final isVerified = data['isVerified'] == true;
        
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminFileView(
                            userId: data['uid'],
                            userName: data['name'],
                          )
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: isAdmin ? Colors.purple.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                      child: Icon(
                        isAdmin ? LucideIcons.shield : LucideIcons.user, 
                        color: isAdmin ? Colors.purple : Colors.blue,
                      ),
                    ),
                    title: Text(
                      data['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['email'] ?? ''),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(LucideIcons.hardDrive, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatSize(storageUsed)}  •  $fileCount Files',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         if (isVerified) 
                           const Padding(
                             padding: EdgeInsets.only(right: 8.0),
                             child: Icon(LucideIcons.badgeCheck, size: 20, color: Colors.blue),
                           ),
                         PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'toggle_block') {
                          await userDoc.reference.update({
                            'accountStatus': isBlocked ? 'active' : 'blocked'
                          });
                        } else if (value == 'delete') {
                           // Handle delete
                           bool? confirm = await showDialog(
                             context: context, 
                             builder: (_) => AlertDialog(
                               title: const Text('Delete User?'),
                               content: const Text('This will delete the user record but Auth account deletion requires cloud functions.'),
                               actions: [
                                 TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Cancel')),
                                 TextButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Delete')),
                               ],
                             )
                           );
                           if (confirm == true) {
                             await userDoc.reference.delete();
                           }

                        } else if (value == 'toggle_verify') {
                           await userDoc.reference.update({
                               'isVerified': !isVerified
                           });
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle_block',
                          child: Row(
                            children: [
                              Icon(isBlocked ? LucideIcons.checkCircle : LucideIcons.ban, size: 18, color: isBlocked ? Colors.green : Colors.red),
                              const SizedBox(width: 8),
                              Text(isBlocked ? 'Unblock User' : 'Block User'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_verify',
                          child: Row(
                            children: [
                              Icon(isVerified ? LucideIcons.badgeX : LucideIcons.badgeCheck, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(isVerified ? 'Remove Verify' : 'Verify User'),
                            ],
                          ),
                        ),
                        if (!isAdmin)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                                const SizedBox(width: 8),
                                Text('Delete User', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
