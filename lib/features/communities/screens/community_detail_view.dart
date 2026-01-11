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
import '../../files/repositories/supabase_file_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../files/models/file_type.dart';
import '../../files/models/file_item.dart';
import '../../files/screens/viewers/image_viewer_page.dart';
import '../../files/screens/viewers/pdf_viewer_page.dart';
import '../../files/screens/viewers/video_player_page.dart';
import '../../files/screens/viewers/office_viewer_page.dart';
import '../../files/screens/file_detail_view.dart';
import 'package:path/path.dart' as path;
// Note: We might need to duplicate/refactor FileList if FileListTile depends heavily on specific context

class CommunityDetailView extends StatefulWidget {
  final String communityId;
  const CommunityDetailView({super.key, required this.communityId});

  @override
  State<CommunityDetailView> createState() => _CommunityDetailViewState();
}

class _CommunityDetailViewState extends State<CommunityDetailView> {
  final CommunityService _communityService = CommunityService();
  final OfflineFileService _fileService = OfflineFileService();
  final SupabaseFileService _supabaseService = SupabaseFileService();
  final AuthService _auth = AuthService();

  bool _isGlobalAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkGlobalAdmin();
    // Sync Files
    _fileService.syncCommunityFiles(widget.communityId).then((_) {
        if (mounted) setState(() {});
    });
  }

  Future<void> _checkGlobalAdmin() async {
      final role = await _auth.getUserRole();
      if (mounted) {
          setState(() {
              _isGlobalAdmin = role == 'admin';
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        // Handle deleted community
        if (!snapshot.data!.exists) {
            return Scaffold(
                appBar: AppBar(title: const Text("Community")),
                body: const Center(child: Text("Community not found (Deleted)")),
            );
        }

        final community = Community.fromMap(snapshot.data!.data() as Map<String, dynamic>, widget.communityId);
        final currentUser = _auth.currentUserUid;
        final isMember = community.isMember(currentUser!);
        final isCommunityAdmin = community.isAdmin(currentUser);
        final canEdit = isCommunityAdmin || community.isEditor(currentUser) || _isGlobalAdmin;
        
        // Super Admin Access
        final hasAccess = isMember || isCommunityAdmin || _isGlobalAdmin;

        // Chat Access: STRICTLY for members only. System Admins cannot spy on chat unless they join.
        final showChat = isMember; 

        // Admin Controls (Requests, Delete, Kick)
        final showAdminControls = isCommunityAdmin || _isGlobalAdmin;

        final isPending = community.pendingMemberIds.contains(currentUser);

        // Access Control: Block ALL content if not a member AND not global admin
        if (!hasAccess) {
             return Scaffold(
                appBar: AppBar(title: Text(community.name)),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          community.isPublic ? LucideIcons.users : LucideIcons.lock, 
                          size: 80, 
                          color: Colors.blue.withOpacity(0.5)
                        ),
                        const SizedBox(height: 24),
                        Text(
                          community.name, 
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          community.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(community.isPublic ? LucideIcons.globe : LucideIcons.shield, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(community.isPublic ? "Public Community" : "Private Community"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (isPending)
                          const Chip(
                            label: Text("Request Sent"), 
                            avatar: Icon(Icons.watch_later_outlined, size: 16),
                            backgroundColor: Colors.amberAccent,
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => _communityService.joinCommunity(widget.communityId),
                            icon: Icon(community.isPublic ? LucideIcons.logIn : LucideIcons.send),
                            label: Text(community.isPublic ? "Join Community" : "Request to Join"),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
             );
        }

        // Calculate tab count dynamically
        // Files (Always) + Chat (If Member) + Members (Always) + Requests (If Admin)
        final List<Widget> tabs = [
           const Tab(text: 'Files'),
           if (showChat) const Tab(text: 'Chat'),
           const Tab(text: 'Members'),
           if (isCommunityAdmin) const Tab(text: 'Requests'),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(community.name),
              bottom: TabBar(
                isScrollable: true,
                tabs: tabs,
              ),
              actions: [
                if (showAdminControls)
                   PopupMenuButton<String>(
                     onSelected: (value) {
                       if (value == 'delete') {
                          _showDeleteConfirmation(context, community.id);
                       }
                     },
                     itemBuilder: (context) => [
                       const PopupMenuItem(
                         value: 'delete', 
                         child: Row(
                           children: [
                             Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                             SizedBox(width: 8),
                             Text('Delete Community', style: TextStyle(color: Colors.red)),
                           ],
                         ),
                       ),
                     ],
                   ),
              ],
            ),
            body: TabBarView(
              children: [
                // 1. Files Tab
                _buildFilesTab(community, canEdit),

                // 2. Chat Tab
                if (showChat) _buildChatTab(community, isMember),

                // 3. Members Tab
                _buildMembersTab(community, showAdminControls, isCommunityAdmin),

                // 4. Requests Tab (Admin Only)
                if (isCommunityAdmin) _buildRequestsTab(community),
              ],
            ),
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
                   ).then((newItem) async {
                      if (newItem != null) {
                          // AUTO BACKUP TO SUPABASE FOR COMMUNITY SHARING
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing to Cloud...")));
                          try {
                              final String storedPath = await _supabaseService.backupFile(newItem);
                              
                              // UPDATE FIRESTORE WITH STORAGE PATH
                              await FirebaseFirestore.instance.collection('files').doc(newItem.id).update({
                                  'storagePath': storedPath,
                              });
                              
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cloud Sync Complete!")));
                          } catch (e) {
                              print("Community Auto-Backup failed: $e");
                              // Not critical for local save, but means others can't see it (ghost)
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cloud Sync Failed: $e")));
                          }
                      }
                   });
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
                        trailing: PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical),
                  onSelected: (value) {
                    if (value == 'view') {
                      _openFile(file);
                    } else if (value == 'save') {
                      _saveToDownloads(file);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(LucideIcons.eye),
                        title: Text('View'),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'save',
                      child: ListTile(
                        leading: Icon(LucideIcons.download),
                        title: Text('Save to Device'),
                      ),
                    ),
                  ],
                ),
                onTap: () => _openFile(file), // Default to open on tap
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
  Widget _buildMembersTab(Community community, bool showMenu, bool canChangeRoles) {
      final members = community.memberRoles.entries.toList();
      return ListView.builder(
        itemCount: members.length,
        itemBuilder: (context, index) {
           final entry = members[index];
           final uid = entry.key;
           final role = entry.value;
           
           return FutureBuilder<DocumentSnapshot>(
             future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
             builder: (context, snapshot) {
                 String name = 'User ($uid)';
                 if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                     final data = snapshot.data!.data() as Map<String, dynamic>;
                     name = data['name'] ?? data['email'] ?? name;
                 }
                 
                 return ListTile(
                   title: Text(uid == _auth.currentUserUid ? '$name (You)' : name),
                   subtitle: Text(role.toUpperCase()),
                   trailing: showMenu && uid != _auth.currentUserUid ? PopupMenuButton<String>(
                     onSelected: (value) {
                        if (value == 'kick') {
                           _communityService.removeMember(community.id, uid);
                        } else {
                           _communityService.updateMemberRole(community.id, uid, value);
                        }
                     },
                     itemBuilder: (context) => [
                       if (canChangeRoles) ...[
                         const PopupMenuItem(value: 'viewer', child: Text('Make Viewer')),
                         const PopupMenuItem(value: 'editor', child: Text('Make Editor')),
                         const PopupMenuItem(value: 'admin', child: Text('Make Admin')),
                         const PopupMenuDivider(),
                       ],
                       const PopupMenuItem(value: 'kick', child: Row(
                         children: [
                           Icon(LucideIcons.userX, color: Colors.red, size: 18),
                           SizedBox(width: 8),
                           Text('Remove Member', style: TextStyle(color: Colors.red)),
                         ],
                       )),
                     ],
                   ) : null,
                 );
             },
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
           return FutureBuilder<DocumentSnapshot>(
             future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
             builder: (context, snapshot) {
                 String name = 'User $uid';
                 if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                     final data = snapshot.data!.data() as Map<String, dynamic>;
                     name = data['name'] ?? data['email'] ?? name;
                 }

                 return ListTile(
                   title: Text(name),
                   trailing: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _communityService.approveMember(community.id, uid)),
                       IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _communityService.rejectMember(community.id, uid)),
                     ],
                   ),
                 );
             }
           );
        },
      );
  }

  void _showDeleteConfirmation(BuildContext context, String communityId) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Delete Community?'),
        content: const Text('This action cannot be undone. All messages and roles will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
               Navigator.pop(context); // Close dialog
               Navigator.pop(context); // Close screen
               await _communityService.deleteCommunity(communityId);
               // Optimistically close or show success? 
               // Since we popped, we are back at list.
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  Future<FileItem> _ensureLocallyAvailable(FileItem file) async {
      // 1. If Local AND Exists, return as is
      if (file.localPath != null) {
         final f = File(file.localPath!);
         if (await f.exists()) return file;
      }
      if (file.content != null) return file;

      // 2. Refresh from local DB in case it was downloaded recently
      final existing = _fileService.getAllFiles(communityId: widget.communityId)
          .firstWhere((f) => f.id == file.id, orElse: () => file);
      
      if (existing.localPath != null) {
          final f = File(existing.localPath!);
          if (await f.exists()) return existing;
      }

      // 3. Download from Cloud
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching from Cloud...")));
      
      String? path;
      String? name = file.name;

      if (file.storagePath != null) {
          path = file.storagePath;
      } else {
          // Fallback: Legacy lookup
          final meta = await _supabaseService.getFileMetadata(file.id);
          if (meta != null) {
              path = meta['storage_path'];
              name = meta['file_name'];
          }
      }
      
      if (path == null) throw Exception("No storage path found");
      
      final bytes = await _supabaseService.downloadFileContent(path);
      
      // Save locally to App Cache
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/$name');
      await localFile.writeAsBytes(bytes);

      // Update Hive
      // We need to 'fake' a save or update the item properties manually
      // Since OfflineFileService manages Hive, let's update it there.
      // But we don't have a direct 'updateLocalPath' method exposed easily except duplicate logic.
      // Let's create a new item and put it.
      
      final updatedItem = file.copyWith(
          localPath: localFile.path,
          synced: true
      );
      
      // We need to persist this update so next time it is local
      // Using a bit of a hack: re-save to box. 
      // Ideally OfflineFileService should have 'markAsDownloaded(id, path)'
      // For now we assume this ephemeral DetailView can handle it or we ignore persistence 
      // (but persistence is better).
      // Let's try to update if we can access the box, but `_fileService` hides it.
      // We'll rely on the caller to use the returned item.
      await Hive.box('filesBox').put(updatedItem.id, updatedItem.toMap());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloaded!")));
      return updatedItem;
  }

  Future<void> _openFile(FileItem file) async {
      try {
          final localItem = await _ensureLocallyAvailable(file);
          
          if (!mounted) return;
          
          // Open File Viewer
          Widget? viewerPage;
          switch (localItem.type) {
              case FileType.image:
                  viewerPage = ImageViewerPage(file: localItem);
                  break;
              case FileType.document:
                  if (localItem.name.toLowerCase().endsWith('.pdf')) {
                      viewerPage = PdfViewerPage(file: localItem);
                  } else if (localItem.name.toLowerCase().endsWith('.docx') || localItem.name.toLowerCase().endsWith('.xlsx')) {
                      viewerPage = OfficeViewerPage(file: localItem); 
                  }
                  break;
              case FileType.video:
                  viewerPage = VideoPlayerPage(file: localItem);
                  break;
              default:
                  break;
          }

          if (viewerPage != null) {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => viewerPage!));
          } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: Text(localItem.name)),
                    body: FileDetailView(file: localItem),
                  ),
                ),
              );
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening file: $e")));
      }
  }

  Future<void> _saveToDownloads(FileItem file) async {
       try {
          final localItem = await _ensureLocallyAvailable(file);
          if (localItem.localPath == null) throw Exception("Could not download file.");

          await _fileService.downloadFile(localItem);
          
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File saved/shared successfully!")));

       } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e")));
       }
  }
}
