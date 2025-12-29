import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class AdminFileView extends StatelessWidget {
  final String? userId;
  final String? userName;

  const AdminFileView({super.key, this.userId, this.userName});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    // Note: This requires a Firestore 'files' collection or similar to be synced.
    // If the app only uses Hive for local storage, the Admin Panel cannot see files unless they are synced.
    // Assuming requirement implies metadata is in Firestore or should be.
    // Since the prompt says "View all uploaded files", we assume there is a 'files' collection from previous tasks.
    // If not, we will rely on what exists or returning a placeholder if this is local-only.
    // Considering the user prompt mentioned "Use Cloud Firestore to store user data...", and "Admin can View all uploaded files",
    // it implies files are online. If the app was migrated to Hive only (offline), this is contradictory.
    // However, I will implement a Firestore listener for a 'files' collection.
    
    Query query = FirebaseFirestore.instance.collection('files');
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    // Note: complex sorting with filtering might require index. Fallback to client sort if needed or just remove orderBy for specific user.
    // For simplicity, we remove orderBy when filtering to avoid index errors, or ensure index exists.
    // Let's rely on client side filtering/sorting if list is small, or simple query.
    // Actually, simple query first.
    
    return Scaffold(
      appBar: userId != null ? AppBar(
        title: Text(userName != null ? '$userName\'s Files' : 'User Files'),
        leading: const BackButton(),
      ) : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error loading files'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final files = snapshot.data?.docs ?? [];
        
        if (files.isEmpty) {
          return const Center(child: Text('No files found on server.'));
        }

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final fileDoc = files[index];
            final data = fileDoc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown File';
            final size = data['size'] ?? 0;
            final uploadedBy = data['userName'] ?? 'Unknown User'; // Assuming we store this
            
            return ListTile(
              leading: const Icon(LucideIcons.file),
              title: Text(name),
              subtitle: Text('Size: ${_formatSize(size)} • By: $uploadedBy'),
              trailing: IconButton(
                icon: const Icon(LucideIcons.trash2, color: Colors.red),
                onPressed: () async {
                   bool? confirm = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete File?'),
                      content: const Text('This will delete the file metadata from the database and sync to the user.'),
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

                     } catch(e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
                     }
                  }
                },
              ),
            );
          },
        );
      },
    ),
    );
  }
}
