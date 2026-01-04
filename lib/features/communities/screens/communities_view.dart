import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../dashboard/screens/home_view.dart';
import '../services/community_service.dart';
import '../models/community_model.dart';
import 'create_community_view.dart';
import 'community_detail_view.dart';

class CommunitiesView extends StatelessWidget {
  const CommunitiesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Community>>(
        stream: CommunityService().getCommunities(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final communities = snapshot.data!;
          if (communities.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(LucideIcons.users, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   const Text('No communities found', style: TextStyle(color: Colors.grey)),
                 ],
               ),
             );
          }

          return ListView.builder(
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(LucideIcons.users, color: Colors.blue),
                  ),
                  title: Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(community.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => CommunityDetailView(communityId: community.id)),
                     );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCommunityView()),
          );
        },
        label: const Text('Create'),
        icon: const Icon(LucideIcons.plus),
      ),
    );
  }
}
