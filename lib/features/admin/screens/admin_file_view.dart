import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../files/models/file_type.dart';

class AdminFileView extends StatefulWidget {
  final String? userId;
  final String? userName;

  const AdminFileView({super.key, this.userId, this.userName});

  @override
  State<AdminFileView> createState() => _AdminFileViewState();
}

class _AdminFileViewState extends State<AdminFileView> {
  String? _currentParentId; // null = root

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _navigateUp() {
      // Simple implementation: Go strictly to root? 
      // Or finding parent? Since we don't have the parent object easily without lookups,
      // and this is a simple admin view, let's just go to root or implement a stack if needed.
      // But wait, if we are deep, we need a stack.
      // For now, let's just set to null (Root) if we go back, or maybe build a breadcrumb?
      // Let's use a simple list stack for history if we want full nav.
      // Actually, standard file explorer behavior: Back goes to parent.
      // Querying the folder's parent might be complex with StreamBuilder.
      // Let's try to query the folder doc from the full list if possible?
      // No, let's just use a List<String> navigationStack.
      if (_folderStack.isNotEmpty) {
          setState(() {
              _folderStack.removeLast();
              _currentParentId = _folderStack.isNotEmpty ? _folderStack.last : null;
          });
      } else {
         _currentParentId = null; 
      }
  }
  
  final List<String> _folderStack = [];

  void _enterFolder(String folderId) {
      setState(() {
          _folderStack.add(folderId);
          _currentParentId = folderId;
      });
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('files');
    if (widget.userId != null) {
      query = query.where('userId', isEqualTo: widget.userId);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName != null ? '${widget.userName}\'s Files' : 'User Files'),
        leading: _currentParentId != null 
           ? IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: _navigateUp)
           : const BackButton(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error loading files'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final allFiles = snapshot.data?.docs ?? [];
        
        if (allFiles.isEmpty) {
          return const Center(child: Text('No files found on server.'));
        }

        // Filter by current folder
        // Note: Firestore stores parentId as null for root.
        final visibleFiles = allFiles.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final pId = data['parentId'];
            return pId == _currentParentId;
        }).toList();

        // Sort: Folders first
        visibleFiles.sort((a, b) {
           final aData = a.data() as Map<String, dynamic>;
           final bData = b.data() as Map<String, dynamic>;
           final aType = aData['type'] ?? FileType.other.index;
           final bType = bData['type'] ?? FileType.other.index;
           
           final aIsFolder = aType == FileType.folder.index;
           final bIsFolder = bType == FileType.folder.index;

           if (aIsFolder && !bIsFolder) return -1;
           if (!aIsFolder && bIsFolder) return 1;
           return 0;
        });

        if (visibleFiles.isEmpty) {
             return Center(
                 child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                         const Text("Empty Folder"),
                         if (_currentParentId != null)
                             TextButton(onPressed: _navigateUp, child: const Text("Go Back"))
                     ],
                 )
             );
        }

        return ListView.builder(
          itemCount: visibleFiles.length,
          itemBuilder: (context, index) {
            final fileDoc = visibleFiles[index];
            final data = fileDoc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown File';
            final size = data['size'] ?? 0;
            final uploadedBy = data['userName'] ?? 'Unknown User'; 
            final typeIndex = data['type'] ?? FileType.other.index;
            final isFolder = typeIndex == FileType.folder.index;
            final isApk = name.toLowerCase().endsWith('.apk');
            
            return ListTile(
              leading: Icon(
                isFolder ? LucideIcons.folder 
                : (isApk ? LucideIcons.cloud : LucideIcons.file), 
                color: isFolder ? Colors.amber : (isApk ? Colors.blue : null)
              ),
              title: Text(name),
              subtitle: Text(isFolder ? 'Folder • By: $uploadedBy' : 'Size: ${_formatSize(size)} • By: $uploadedBy'),
              trailing: IconButton(
                icon: const Icon(LucideIcons.trash2, color: Colors.red),
                onPressed: () async {
                   bool? confirm = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(isFolder ? 'Delete Folder?' : 'Delete File?'),
                      content: Text(isFolder 
                          ? 'This will remove the folder but NOT its contents recursively in this Admin view (manual clean up required).' 
                          : 'This will delete the file metadata from the database and sync to the user.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true), 
                            child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                     try {
                       // 1. Get stats for decrement
                       if (!isFolder) {
                           final size = data['size'] ?? 0;
                           final userId = data['userId'];

                           // 2. Batch Delete
                           final batch = FirebaseFirestore.instance.batch();
                           batch.delete(fileDoc.reference);
                           if (userId != null) {
                               final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
                               batch.update(userRef, {
                                   'storageUsed': FieldValue.increment(-(size is int ? size : 0)),
                                   'fileCount': FieldValue.increment(-1),
                               });
                           }
                           await batch.commit();
                       } else {
                           // Folder delete: Just delete the doc. 
                           // Ideally implementation recursive delete, but for quick fix just delete doc.
                           await fileDoc.reference.delete();
                       }

                     } catch(e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
                     }
                  }
                },
              ),
              onTap: isFolder ? () => _enterFolder(fileDoc.id) : null,
            );
          },
        );
      },
    ),
    );
  }
}
