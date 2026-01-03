import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import '../models/file_item.dart';
import '../models/file_type.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../notifications/data/services/notification_service.dart';

class OfflineFileService {
  Box get _box => Hive.box('filesBox');

  // Get all files from Hive (Filtered by User and Parent Folder)
  List<FileItem> getAllFiles({String? parentId}) {
    final currentUserUid = AuthService().currentUserUid;
    if (currentUserUid == null) return []; // No files if not logged in

    final List<FileItem> files = [];
    for (var key in _box.keys) {
      final data = _box.get(key);
      if (data != null) {
        try {
           final map = Map<String, dynamic>.from(data);
           final item = FileItem.fromMap(map);
           

           // Filter: Only show files for this user and optionally by folder
           if (item.userId == currentUserUid) {
              if (parentId == null) {
                  // Root: items with no parentId
                  if (item.parentId == null) files.add(item);
              } else {
                  // Subfolder: items with matching parentId
                  if (item.parentId == parentId) files.add(item);
              }
           }
        } catch (e) {
          print("Error parsing file item: $e");
        }
      }
    }
    // Sort by Starred first, then newest
    files.sort((a, b) {
      if (a.isStarred && !b.isStarred) return -1;
      if (!a.isStarred && b.isStarred) return 1;
      return b.modified.compareTo(a.modified);
    });
    return files;
  }

  // Pick and save a file
  Future<FileItem?> pickAndSaveFile({Function(String name, int size)? onFilePicked, String? parentId}) async {
    final currentUserUid = AuthService().currentUserUid;
    final String? userName = AuthService().currentUserName; // Get name for metadata
    if (currentUserUid == null) {
        print("Cannot save file: No user logged in");
        return null;
    }

    try {
      print("Picking file...");
      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        withData: true, 
      );

      if (result != null) {
         final file = result.files.single;
         if (!kIsWeb && file.path == null) {
            return null; 
         }

         String fileName = file.name;
         String? newPath;
         Uint8List? content;
         int size = file.size;

         if (kIsWeb) {
           content = file.bytes;
         } else {
            final Directory appDir = await getApplicationDocumentsDirectory();
            newPath = path.join(appDir.path, fileName);
            final File originalFile = File(file.path!);
            await originalFile.copy(newPath);
            size = File(newPath).lengthSync();
         }

         // Callback for UI feedback
         if (onFilePicked != null) {
            onFilePicked(fileName, size);
         }

         // Simulate Upload Delay (1 sec per 1 MB, min 1 sec, max 10 sec)
         int delayMillis = (size / (1024 * 1024) * 1000).toInt(); 
         if (delayMillis < 1000) delayMillis = 1000;
         if (delayMillis > 10000) delayMillis = 10000;
         
         await Future.delayed(Duration(milliseconds: delayMillis));

        final String id = DateTime.now().millisecondsSinceEpoch.toString();
        final FileItem newItem = FileItem(
          id: id,
          name: fileName,
          size: _formatSize(size),
          modified: DateTime.now(),
          type: _getTypeFromName(fileName),
          localPath: newPath,
          synced: true, // Mark as synced since we send to Firestore
          content: content,
          userId: currentUserUid, 
          parentId: parentId,
        );

        // 1. Save Local (Hive)
        await _box.put(id, newItem.toMap());
        
        // 2. Sync Metadata to Firestore (For Admin Visibility) & Update User Stats
        final batch = FirebaseFirestore.instance.batch();
        final fileRef = FirebaseFirestore.instance.collection('files').doc(id);
        final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserUid);

        batch.set(fileRef, {
          'id': id,
          'name': fileName,
          'size': size,
          'type': newItem.type.index,
          'userId': currentUserUid,
          'userName': userName,
          'parentId': parentId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Atomic Increment for User Stats
        batch.update(userRef, {
          'storageUsed': FieldValue.increment(size),
          'fileCount': FieldValue.increment(1),
        });

        await batch.commit();

        return newItem;
      }
      return null;
    } catch (e) {
      print("Error picking/saving file: $e");
      rethrow;
    }
  }

  // Save Generated PDF
  Future<FileItem?> savePdfFile(Uint8List bytes, String fileName) async {
      final currentUserUid = AuthService().currentUserUid;
      final String? userName = AuthService().currentUserName;
      if (currentUserUid == null) return null;

      try {
         String? newPath;
         int size = bytes.length;

         if (!kIsWeb) {
            final Directory appDir = await getApplicationDocumentsDirectory();
            newPath = path.join(appDir.path, fileName);
            final File file = File(newPath);
            await file.writeAsBytes(bytes);
         }

         final String id = DateTime.now().millisecondsSinceEpoch.toString();
         final FileItem newItem = FileItem(
           id: id,
           name: fileName,
           size: _formatSize(size),
           modified: DateTime.now(),
           type: FileType.document, // PDF is a document
           localPath: newPath,
           synced: true,
           content: kIsWeb ? bytes : null, 
           userId: currentUserUid,
         );

         // 1. Save Local
         await _box.put(id, newItem.toMap());
         
         // 2. Sync to Firestore & Update User Stats
         final batch = FirebaseFirestore.instance.batch();
         final fileRef = FirebaseFirestore.instance.collection('files').doc(id);
         final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserUid);

         batch.set(fileRef, {
            'id': id,
            'name': fileName,
            'size': size,
            'type': newItem.type.index,
            'userId': currentUserUid,
            'userName': userName,
            'createdAt': FieldValue.serverTimestamp(),
         });

         batch.update(userRef, {
            'storageUsed': FieldValue.increment(size),
            'fileCount': FieldValue.increment(1),
         });

         await batch.commit();

         return newItem;
      } catch (e) {
          print("Error saving PDF: $e");
          return null;
      }
  }

  // Create Folder
  Future<FileItem?> createFolder(String name, {String? parentId}) async {
    final currentUserUid = AuthService().currentUserUid;
    final String? userName = AuthService().currentUserName; // Get name
    if (currentUserUid == null) return null;

    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    // Default folder color
    final Color folderColor = Colors.blue; 

    final FileItem newFolder = FileItem(
      id: id,
      name: name,
      size: '', // Folders don't have size in this simple version
      modified: DateTime.now(),
      type: FileType.folder, 
      localPath: null, // Virtual folder
      synced: true,
      userId: currentUserUid,
      parentId: parentId,
      color: folderColor,
    );

    await _box.put(id, newFolder.toMap());

    // Sync to Firestore
    try {
      await FirebaseFirestore.instance.collection('files').doc(id).set({
        'id': id,
        'name': name,
        'size': 0,
        'type': FileType.folder.index,
        'userId': currentUserUid,
        'userName': userName,
        'parentId': parentId,
        'createdAt': FieldValue.serverTimestamp(),
        'color': folderColor.value,
      });
    } catch (e) {
      print("Error syncing folder creation: $e");
    }
    
    return newFolder;
  }

  // Rename Folder
  Future<void> renameFolder(String id, String newName) async {
    final data = _box.get(id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      final item = FileItem.fromMap(map);
      
      if (item.userId != AuthService().currentUserUid) return;

      final updatedItem = item.copyWith(name: newName);
      await _box.put(id, updatedItem.toMap());

      // Sync
      try {
        await FirebaseFirestore.instance.collection('files').doc(id).update({
            'name': newName
        });
      } catch (e) {
         print("Error renaming folder cloud: $e");
      }
    }
  }

  // Move File or Folder
  Future<void> moveFile(String id, String? newParentId) async {
    final data = _box.get(id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      final item = FileItem.fromMap(map);

      if (item.userId != AuthService().currentUserUid) return;
      
      // Prevent circular move (folder into itself)
      if (item.isFolder && id == newParentId) return;

      final updatedItem = item.copyWith(parentId: newParentId);
      await _box.put(id, updatedItem.toMap());

      // Sync
      try {
         await FirebaseFirestore.instance.collection('files').doc(id).update({
             'parentId': newParentId
         });
      } catch (e) {
         print("Error moving file cloud: $e");
      }
    }
  }

  // Helper to find all descendants of a folder (for recursive delete)
  List<String> _getAllDescendantIds(String folderId) {
     final List<String> descendants = [];
     final allFiles = _box.values.map((e) => FileItem.fromMap(Map<String, dynamic>.from(e))).toList();
     
     // Find direct children
     final children = allFiles.where((f) => f.parentId == folderId).toList();
     
     for (var child in children) {
        descendants.add(child.id);
        if (child.isFolder) {
           descendants.addAll(_getAllDescendantIds(child.id));
        }
     }
     return descendants;
  }


  // Delete file
  Future<void> deleteFile(String id) async {
    final data = _box.get(id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      final item = FileItem.fromMap(map);
      
      // Security check: Only delete if owned by current user
      if (item.userId != AuthService().currentUserUid) return;

      // If folder, delete contents recursively
      if (item.isFolder) {
          final descendants = _getAllDescendantIds(item.id);
          for (var childId in descendants) {
             await deleteFile(childId);
          }
      }

      if (!kIsWeb && item.localPath != null) {
        final File file = File(item.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await _box.delete(id);
      
      // Sync Delete in Firestore
      try {
        final batch = FirebaseFirestore.instance.batch();
        final fileRef = FirebaseFirestore.instance.collection('files').doc(id);
        final userRef = FirebaseFirestore.instance.collection('users').doc(item.userId);

        batch.delete(fileRef);
        // Only decrement stats if it's a file (folders have no size/count impact in this simple model, or count as 0 size)
        if (!item.isFolder) {
           batch.update(userRef, {
              'storageUsed': FieldValue.increment(-_parseSize(item.size)),
              'fileCount': FieldValue.increment(-1),
           });
        }

        await batch.commit();
      } catch(e) {
        print("Error deleting from cloud: $e"); 
      }
    }
  }

  // Toggle Star
  Future<FileItem?> toggleStar(String id) async {
    final data = _box.get(id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      final item = FileItem.fromMap(map);
      
      if (item.userId != AuthService().currentUserUid) return null;

      final newItem = FileItem(
        id: item.id,
        name: item.name,
        size: item.size,
        modified: item.modified,
        type: item.type,
        localPath: item.localPath,
        synced: item.synced,
        isStarred: !item.isStarred,
        content: item.content,
        color: item.color,
        userId: item.userId,
      );
      await _box.put(id, newItem.toMap());
      return newItem;
    }
    return null;
  }



  // Get Total Size (Filtered)
  int getTotalSize() {
      int total = 0;
      final files = getAllFiles(); // This is already filtered by userId!
      for (var f in files) {
          total += _parseSize(f.size);
      }
      return total;
  }

  int _parseSize(String sizeStr) {
      final parts = sizeStr.split(' ');
      if (parts.length != 2) return 0;
      double val = double.tryParse(parts[0]) ?? 0;
      String unit = parts[1];
      switch (unit) {
          case 'B': return val.toInt();
          case 'KB': return (val * 1024).toInt();
          case 'MB': return (val * 1024 * 1024).toInt();
          case 'GB': return (val * 1024 * 1024 * 1024).toInt();
          default: return 0;
      }
  }

  // Delete All Files (Cleanup - Filtered)
  Future<void> deleteAllFiles() async {
      final files = getAllFiles(); // Uses filtered list
      for (var f in files) {
          await deleteFile(f.id); // deleteFile has security check too
      }
  }

  // Download File
  Future<void> downloadFile(FileItem item) async {
    if (kIsWeb) {
      if (item.content != null) {
        final blob = html.Blob([item.content!]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", item.name)
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } else {
      await shareFile(item); // Fallback to share for consistency
    }
  }

  // Share File
  Future<void> shareFile(FileItem item) async {
      try {
       final String shareText = 'Check out this file: ${item.name}';
       final String shareSubject = 'Sharing ${item.name}';

       if (kIsWeb) {
          if (item.content != null) {
             final xFile = XFile.fromData(
               item.content!,
               name: item.name,
               mimeType: _getMimeType(item.name),
             );
             await Share.shareXFiles(
               [xFile], 
               text: shareText,
               subject: shareSubject, // Mostly for email
             );
          }
       } else {
          if (item.localPath != null) {
             final file = File(item.localPath!);
             if (await file.exists()) {
               final xFile = XFile(item.localPath!);
               await Share.shareXFiles(
                 [xFile], 
                 text: shareText,
                 subject: shareSubject,
               );
             } else {
                throw Exception("File not found at ${item.localPath}");
             }
          }
       }
     } catch (e) {
       throw Exception("Could not share file: $e");
     }
  }

  String _getMimeType(String name) {
     final ext = path.extension(name).toLowerCase();
     switch (ext) {
       case '.jpg':
       case '.jpeg': return 'image/jpeg';
       case '.png': return 'image/png';
       case '.pdf': return 'application/pdf';
       case '.txt': return 'text/plain';
       default: return 'application/octet-stream';
     }
  }

  // Helper: Get File Type
  FileType _getTypeFromName(String name) {
    String ext = path.extension(name).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return FileType.image;
      case '.mp4':
      case '.mov':
      case '.avi':
        return FileType.video;
      case '.mp3':
      case '.wav':
      case '.aac':
        return FileType.audio;
      case '.pdf':
        return FileType.pdf;
      case '.doc':
      case '.docx':
      case '.txt':
        return FileType.document;
      case '.zip':
      case '.rar':
        return FileType.archive;
      default:
        return FileType.other;
    }
  }

  // Helper: Format Size
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Sync: Check for Admin Deletions
  Future<void> syncCloudDeletions() async {
    final currentUserUid = AuthService().currentUserUid;
    if (currentUserUid == null) return;

    try {
      // 1. Get all file IDs currently in Firestore for this user
      final query = await FirebaseFirestore.instance
          .collection('files')
          .where('userId', isEqualTo: currentUserUid)
          .get();
      
      final Set<String> cloudIds = query.docs.map((d) => d.id).toSet();

      // 2. Iterate local files
      final localFiles = getAllFiles(); // user filtered
      
      for (var item in localFiles) {
        if (item.synced && !cloudIds.contains(item.id)) {
             print("Sync: Deleting local file ${item.name} as it was removed from cloud.");
             await deleteFile(item.id); 
             
             // Notify User
             await NotificationService().addNotification(
               title: 'File Removed by Admin', 
               body: 'Your file "${item.name}" was removed by an administrator.'
             );
        }
      }
    } catch (e) {
      print("Sync error: $e");
    }
  }

  // Save Received File (P2P)
  Future<FileItem?> saveReceivedFile(Uint8List bytes, String fileName, dynamic sizeArg, dynamic typeArg) async {
       final currentUserUid = AuthService().currentUserUid;
       final String? userName = AuthService().currentUserName;
       if (currentUserUid == null) return null;

       try {
         String? newPath;
         int size = bytes.length; 
         
         if (!kIsWeb) {
            final Directory appDir = await getApplicationDocumentsDirectory();
            newPath = path.join(appDir.path, fileName);
            
            final File file = File(newPath);
            if (await file.exists()) {
                 final nameWithoutExt = path.basenameWithoutExtension(fileName);
                 final ext = path.extension(fileName);
                 newPath = path.join(appDir.path, "${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}$ext");
            }
            await File(newPath).writeAsBytes(bytes);
         }

         final String id = DateTime.now().millisecondsSinceEpoch.toString();
         // We should try to use the typeArg if strictly matching, but helper is safer
         final FileType type = _getTypeFromName(fileName);

         final FileItem newItem = FileItem(
           id: id,
           name: fileName,
           size: _formatSize(size),
           modified: DateTime.now(),
           type: type,
           localPath: newPath,
           synced: true,
           content: kIsWeb ? bytes : null,
           userId: currentUserUid,
         );

         await _box.put(id, newItem.toMap());

         final batch = FirebaseFirestore.instance.batch();
         final fileRef = FirebaseFirestore.instance.collection('files').doc(id);
         final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserUid);

         batch.set(fileRef, {
            'id': id,
            'name': fileName,
            'size': size,
            'type': newItem.type.index,
            'userId': currentUserUid,
            'userName': userName,
            'createdAt': FieldValue.serverTimestamp(),
         });

         batch.update(userRef, {
            'storageUsed': FieldValue.increment(size),
            'fileCount': FieldValue.increment(1),
         });

         await batch.commit();
         return newItem;
      } catch (e) {
         print("Error saving received file: $e");
         return null;
      }
  }
}
