import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../communities/models/community_model.dart';
import '../../communities/screens/community_detail_view.dart';
import '../../communities/services/community_service.dart';

class AdminCommunityView extends StatefulWidget {
  const AdminCommunityView({super.key});

  @override
  State<AdminCommunityView> createState() => _AdminCommunityViewState();
}

class _AdminCommunityViewState extends State<AdminCommunityView> {
  final CommunityService _communityService = CommunityService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Community Management',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage all public and private communities',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('communities').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.users, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No communities found',
                          style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final community = Community.fromMap(data, docs[index].id);
                    final memberCount = community.memberRoles.length;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: community.isPublic ? Colors.blue.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            community.isPublic ? LucideIcons.globe : LucideIcons.lock,
                            color: community.isPublic ? Colors.blue : Colors.amber,
                          ),
                        ),
                        title: Text(
                          community.name,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              community.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(LucideIcons.users, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '$memberCount Members', 
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12)
                                ),
                                const SizedBox(width: 12),
                                Icon(LucideIcons.calendar, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  "ID: ${community.id.substring(0, 4)}...",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12)
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                           Navigator.of(context).push(
                             MaterialPageRoute(
                               builder: (context) => CommunityDetailView(communityId: community.id),
                             ),
                           );
                        },
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.red),
                          onPressed: () => _confirmDelete(context, community),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Community community) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community?'),
        content: Text('Are you sure you want to delete "${community.name}"? This action cannot be undone and will remove all associated data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _communityService.deleteCommunity(community.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Community deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
