
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/file_item.dart';
import '../models/file_type.dart';

class SupabaseFileService {
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  /// Helper to convert any ID (like legacy timestamps) to a valid UUID.
  /// Uses UUID v5 (Namespace) to ensure the same timestamp ID always maps to the same UUID.
  String _toUUID(String id) {
    try {
      // Return as-is if already a valid UUID
      if (Uuid.isValidUUID(fromString: id)) {
        return id;
      }
    } catch (_) {}

    // Generate a deterministic UUID v5 based on the ID string
    // Using a random namespace seed for this app context if needed, 
    // or just the URL namespace for simplicity.
    return _uuid.v5(Uuid.NAMESPACE_URL, id); 
  }

  /// Uploads a file to Supabase Storage and saves metadata to Firestore/Supabase DB.
  /// Note: The original requirement mentioned Supabase, but the app uses Firestore for metadata in other places.
  /// I will use Supabase for both Storage and DB for this specific "Backup" feature as requested implicitly by the Supabase context.
  Future<String> backupFile(FileItem file) async {
    // 1. Check if we have the file data
    File? localFile;
    if (file.localPath != null) {
        localFile = File(file.localPath!);
        if (!await localFile.exists()) {
             throw Exception("File not found at path: ${file.localPath}");
        }
    } else if (file.content == null) {
        // Ghost file or invalid state
        throw Exception("File content not available locally (Ghost File).");
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User must be logged in to backup files");
    }
    
    // 2. Upload to Supabase Storage
    final String path = '${user.uid}/${file.name}'; 
    
    try {
      if (localFile != null) {
          await _client.storage.from('user_backups').upload(
            path,
            localFile,
            fileOptions: const FileOptions(upsert: true),
          );
      } else if (file.content != null) {
          await _client.storage.from('user_backups').uploadBinary(
            path,
            file.content!,
            fileOptions: const FileOptions(upsert: true),
          );
      }
    } catch (e) {
      // If bucket doesn't exist or permission denied
      print("Storage Upload Error: $e");
      rethrow;
    }

    // 2. Insert/Update Metadata in 'file_backups' table in Supabase
    // Note: The Admin view was using Firestore. If we want to use Supabase entirely for this feature:
    await _client.from('file_backups').upsert({
      'id': _toUUID(file.id), // CRITICAL: Ensure ID is valid UUID
      'uid': user.uid, 
      'file_name': file.name,
      'file_size': file.size.toString(), 
      'file_type': file.type.toString().split('.').last,
      'storage_path': path, 
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return path;
  }


  /// Lists files backed up in Supabase
  Future<List<Map<String, dynamic>>> getCloudFiles(String uid) async {
    final response = await _client
        .from('file_backups')
        .select()
        .eq('uid', uid); // Filter by Firebase UID
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get metadata for a single file by ID (useful for community ghost files)
  Future<Map<String, dynamic>?> getFileMetadata(String id) async {
    final response = await _client
        .from('file_backups')
        .select()
        .eq('id', _toUUID(id))
        .maybeSingle();
    return response;
  }

  /// Downloads a file from Supabase and returns the bytes
  Future<List<int>> downloadFileContent(String path) async {
    final Uint8List bytes = await _client.storage.from('user_backups').download(path);
    return bytes.toList();
  }

  // --- Admin Methods ---

  /// Admin: Fetch ALL backups from all users
  Future<List<Map<String, dynamic>>> getAllBackups() async {
    final response = await _client
        .from('file_backups')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Admin: Delete a backup from DB and Storage and Notify User
  Future<void> deleteBackup(String id, String storagePath, String uid) async {
      // 1. Delete from Storage
      try {
        await _client.storage.from('user_backups').remove([storagePath]);
      } catch (e) {
        print("Admin: Error deleting cloud file: $e");
      }

      // 2. Delete from Metadata Table
      await _client.from('file_backups').delete().eq('id', _toUUID(id));

      // 3. Notify User (Remote Notification)
      try {
        // We write to a 'notifications' subcollection for the user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
              'title': 'Backup Deleted by Admin',
              'body': 'Your file was removed by an administrator for policy violation.',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
      } catch (e) {
        print("Admin: Error sending notification: $e");
      }
  }

  /// Rename Metadata to sync with Database updates
  Future<void> renameBackup(String id, String newName) async {
     try {
       await _client.from('file_backups').update({
         'file_name': newName
       }).eq('id', _toUUID(id));
     } catch (e) {
       print("Supabase Rename Error: $e");
       // Not critical if cloud rename fails, but good to log
     }
  }
}
