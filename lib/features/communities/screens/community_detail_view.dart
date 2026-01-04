import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/community_model.dart';
import '../models/community_message.dart';
import '../services/community_service.dart';
import '../../files/repositories/offline_file_service.dart';
import '../../files/repositories/offline_file_service.dart';
// Note: We might need to duplicate/refactor FileList if FileListTile depends heavily on specific context

class CommunityDetailView extends StatefulWidget {
  final String communityId;
  const CommunityDetailView({super.key, required this.communityId});

  @override
  State<CommunityDetailView> createState() => _CommunityDetailViewState();
}

class _CommunityDetailViewState extends State<CommunityDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommunityService _communityService = CommunityService();
  final OfflineFileService _fileService = OfflineFileService();
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Auto-join if not member logic might be needed elsewhere, but assuming we entered from list where we handle access.
    // Actually, assume we are at least viewing it. 
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        // Handle deleted community
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Community not found")));

        final community = Community.fromMap(snapshot.data!.data() as Map<String, dynamic>, widget.communityId);
        final currentUser = _auth.currentUserUid;
        final isMember = community.isMember(currentUser!);
        final isAdmin = community.isAdmin(currentUser);
        final canEdit = isAdmin || community.isEditor(currentUser);

        final isPending = community.pendingMemberIds.contains(currentUser);

        // Access Control
        if (!community.isPublic && !isMember && !isAdmin) {
             return Scaffold(
                appBar: AppBar(title: Text(community.name)),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.lock, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text("This is a Private Community", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text("You need to be a member to see content."),
                      const SizedBox(height: 24),
                      if (isPending)
                        const Chip(label: Text("Request Sent"), avatar: Icon(Icons.hourglass_empty))
                      else
                        FilledButton(
                          onPressed: () => _communityService.joinCommunity(widget.communityId),
                          child: const Text("Request to Join"),
                        ),
                    ],
                  ),
                ),
             );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(community.name),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                const Tab(text: 'Files'),
                const Tab(text: 'Chat'),
                const Tab(text: 'Members'),
                if (isAdmin) const Tab(text: 'Requests'),
              ],
            ),
            actions: [
                if (!isMember && !isPending) 
                   TextButton(
                     onPressed: () => _communityService.joinCommunity(widget.communityId),
                     child: const Text('Join', style: TextStyle(color: Colors.white)),
                   )
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 1. Files Tab
              _buildFilesTab(community, canEdit),

              // 2. Chat Tab
              _buildChatTab(community, isMember),

              // 3. Members Tab
              _buildMembersTab(community, isAdmin),

              // 4. Requests Tab (Admin Only)
              if (isAdmin) _buildRequestsTab(community) else const Center(child: Text("Admin only")),
            ],
          ),
        );
      },
    );
  }

  // --- Files Tab ---
  Widget _buildFilesTab(Community community, bool canEdit) {
    return Column(
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                 try {
                   await _fileService.pickAndSaveFile(
                     communityId: community.id,
                     onFilePicked: (name, size) {
                        if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploading $name...')));
                        }
                     },
                   );
                 } catch (e) {
                   print("Upload Error: $e");
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                 }
              },
              icon: const Icon(LucideIcons.upload),
              label: const Text('Upload File'),
            ),
          ),
        Expanded(
          // We need a way to refresh this list or use a stream. 
          // OfflineFileService is Hive-based (local). We need to sync down community files first?
          // For now, let's assume syncCloud logic handles it or we trigger a sync.
          // In a real app we'd have a Stream from Hive or Firestore. 
          // Let's rely on FutureBuilder for Hive for now, assuming Sync happens in background or we trigger it.
          // TODO: Trigger Sync logic for this community
          child: ValueListenableBuilder(
            valueListenable: Hive.box('filesBox').listenable(),
            builder: (context, box, _) {
                 final files = _fileService.getAllFiles(communityId: community.id);
                 if (files.isEmpty) return const Center(child: Text('No files shared yet'));
                 
                 return ListView.builder(
                   itemCount: files.length,
                   itemBuilder: (context, index) {
                      final file = files[index];
                      return ListTile(
                        leading: const Icon(LucideIcons.file),
                        title: Text(file.name),
                        subtitle: Text(file.size),
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.download),
                          onPressed: () => _fileService.downloadFile(file),
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

  // --- Chat Tab ---
  Widget _buildChatTab(Community community, bool isMember) {
    if (!isMember) return const Center(child: Text("Join to chat"));
    final _msgController = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<CommunityMessage>>(
            stream: _communityService.getMessages(community.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snapshot.data!;
              return ListView.builder(
                reverse: true, // Show newest at bottom (ListView reverse means index 0 is bottom)
                itemCount: messages.length,
                itemBuilder: (context, index) {
                   final msg = messages[index];
                   final isMe = msg.senderId == _auth.currentUserUid;
                   return Align(
                     alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                     child: Container(
                       margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: isMe ? Colors.blue[100] : Colors.grey[200],
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           if (!isMe) Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                           Text(msg.text),
                           Text(DateFormat('h:mm a').format(msg.timestamp), style: const TextStyle(fontSize: 8, color: Colors.grey)),
                         ],
                       ),
                     ),
                   );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: 'Message...'))),
              IconButton(
                icon: const Icon(LucideIcons.send),
                onPressed: () {
                   if (_msgController.text.isNotEmpty) {
                      _communityService.sendMessage(community.id, _msgController.text);
                      _msgController.clear();
                   }
                },
              )
            ],
          ),
        )
      ],
    );
  }

  // --- Members Tab ---
  Widget _buildMembersTab(Community community, bool isAdmin) {
      final members = community.memberRoles.entries.toList();
      return ListView.builder(
        itemCount: members.length,
        itemBuilder: (context, index) {
           final entry = members[index];
           final uid = entry.key;
           final role = entry.value;
           
           return ListTile(
             title: Text(uid == _auth.currentUserUid ? 'You' : 'User ($uid)'), // In real app fetch name
             subtitle: Text(role.toUpperCase()),
             trailing: isAdmin && uid != _auth.currentUserUid ? PopupMenuButton<String>(
               onSelected: (value) {
                  if (value == 'kick') { // Not implemented yet
                  } else {
                     _communityService.updateMemberRole(community.id, uid, value);
                  }
               },
               itemBuilder: (context) => [
                 const PopupMenuItem(value: 'viewer', child: Text('Make Viewer')),
                 const PopupMenuItem(value: 'editor', child: Text('Make Editor')),
                 const PopupMenuItem(value: 'admin', child: Text('Make Admin')),
               ],
             ) : null,
           );
        },
      );
  }

  // --- Requests Tab ---
  Widget _buildRequestsTab(Community community) {
      if (community.pendingMemberIds.isEmpty) return const Center(child: Text("No pending requests"));
      return ListView.builder(
        itemCount: community.pendingMemberIds.length,
        itemBuilder: (context, index) {
           final uid = community.pendingMemberIds[index];
           return ListTile(
             title: Text('User $uid'),
             trailing: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _communityService.approveMember(community.id, uid)),
                 IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _communityService.rejectMember(community.id, uid)),
               ],
             ),
           );
        },
      );
  }
}
