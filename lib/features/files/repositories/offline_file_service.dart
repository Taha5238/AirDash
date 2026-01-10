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
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/file_item.dart';
import '../models/file_type.dart';
import '../../auth/services/auth_service.dart';
import '../../notifications/services/notification_service.dart';

class OfflineFileService {
  Box get _box => Hive.box('filesBox');

  // Get all files from Hive (Filtered by User/Community and Parent Folder)
  List<FileItem> getAllFiles({String? parentId, String? communityId}) {
    final currentUserUid = AuthService().currentUserUid;
    if (currentUserUid == null) return []; // No files if not logged in

    final List<FileItem> files = [];
    for (var key in _box.keys) {
      final data = _box.get(key);
      if (data != null) {
        try {
           final map = Map<String, dynamic>.from(data);
           final item = FileItem.fromMap(map);
           

           // Filter logic
           bool matchesContext = false;
           if (communityId != null) {
              // Community Mode: Show files for this community
              matchesContext = (item.communityId == communityId);
           } else {
              // Personal Mode: Show files for this user AND not in a community
              matchesContext = (item.userId == currentUserUid && item.communityId == null);
           }

           if (matchesContext) {
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
  Future<FileItem?> pickAndSaveFile({Function(String name, int size)? onFilePicked, String? parentId, String? communityId}) async {
    final currentUserUid = AuthService().currentUserUid;
    final String? userName = AuthService().currentUserName; // Get name for metadata
    if (currentUserUid == null) {
        print("Cannot save file: No user logged in");
        return null;
    }

    try {
      // if (!kIsWeb) {
      //   var status = await Permission.storage.request();
      //   if (!status.isGranted) {
      //      // Try manage external storage for Android 11+ if needed, or just warn
      //      if (await Permission.manageExternalStorage.status.isDenied) {
      //           // await Permission.manageExternalStorage.request(); // Optional: careful with store policy
      //      }
      //      if (status.isPermanentlyDenied) {
      //         openAppSettings();
      //         return null;
      //      }
      //   }
      // }

      print("DEBUG: Starting File Picker...");
        fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
          withData: kIsWeb, 
          // type: fp.FileType.any, // Removing explicit type to rely on default
        );

        print("DEBUG: File Picker Result: ${result != null}");

        if (result != null) {
           final file = result.files.single;
           print("DEBUG: File picked: ${file.name}, Path: ${file.path}");
           if (!kIsWeb && file.path == null) {
              print("DEBUG: File path is null!");
              return null; 
           }

           String fileName = file.name;
           String? newPath;
           Uint8List? content;
           int size = file.size;

         if (kIsWeb) {
           content = file.bytes;
         } else {
            try {
              final Directory appDir = await getApplicationDocumentsDirectory();
              newPath = path.join(appDir.path, fileName);
              final File originalFile = File(file.path!);
              await originalFile.copy(newPath);
              size = File(newPath).lengthSync();
            } catch (e) {
               print("Error copying file: $e");
               // Try to use original path if copy fails
               newPath = file.path; 
            }
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

         final String id = const Uuid().v4();
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
          communityId: communityId,
        );

        // 1. Save Local (Hive)
        await _box.put(id, newItem.toMap());
        
        // 2. Sync Metadata to Firestore
        final batch = FirebaseFirestore.instance.batch();
        final fileRef = FirebaseFirestore.instance.collection('files').doc(id);

        batch.set(fileRef, {
          'id': id,
          'name': fileName,
          'size': size,
          'type': newItem.type.index,
          'userId': currentUserUid,
          'userName': userName,
          'parentId': parentId,
          'communityId': communityId, // Add communityId
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Atomic Increment for User Stats (Only if personal file)
        if (communityId == null) {
          final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserUid);
          batch.update(userRef, {
            'storageUsed': FieldValue.increment(size),
            'fileCount': FieldValue.increment(1),
          });
        }

        await batch.commit();

        return newItem;
      }
      return null;
    } on PlatformException catch (e) {
      print("CRITICAL: File Picker Platform Exception: ${e.message} code: ${e.code} details: ${e.details}");
      throw Exception("System Error: ${e.message}");
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

         final String id = const Uuid().v4();
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
  Future<FileItem?> createFolder(String name, {String? parentId, String? communityId}) async {
    final currentUserUid = AuthService().currentUserUid;
    final String? userName = AuthService().currentUserName; // Get name
    if (currentUserUid == null) return null;

    final String id = const Uuid().v4();
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
      communityId: communityId,
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
        'communityId': communityId,
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

  // Rename File
  Future<void> renameFile(String id, String newName) async {
    final data = _box.get(id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      final item = FileItem.fromMap(map);
      
      if (item.userId != AuthService().currentUserUid) return;

      // 1. Rename on Disk (if exists locally)
      String? newPath = item.localPath;
      if (!kIsWeb && item.localPath != null) {
          final file = File(item.localPath!);
          if (await file.exists()) {
              final dir = path.dirname(item.localPath!);
              final ext = path.extension(item.localPath!);
              // Ensure newName has extension or keep old?
              // Usually user types ID "Funny Cat", we keep ".png".
              // Assuming newName is valid filename WITHOUT extension or WITH?
              // Let's assume user provides full name or we handle it in UI. 
              // Better: UI provides name without extension, we append extension.
              // For now, let's assume UI does the right thing.
              newPath = path.join(dir, newName);
              try {
                  await file.rename(newPath);
              } catch (e) {
                  print("Error renaming file on disk: $e");
                  // If disk rename fails, maybe don't rename metadata? 
                  // or continue? Let's continue but keep old path if fail.
                  newPath = item.localPath;
              }
          }
      }

      final updatedItem = item.copyWith(name: newName, localPath: newPath);
      await _box.put(id, updatedItem.toMap());

      // 2. Sync to Firestore (Metadata)
      try {
        await FirebaseFirestore.instance.collection('files').doc(id).update({
            'name': newName
        });
      } catch (e) {
         print("Error renaming file cloud: $e");
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
      
      // Security check: Only delete if owned by current user OR if user is community admin
      // For now, strict ownership or relying on UI to hide delete button.
      // Ideally check Community role here if communityId != null.
      // Simplified: If communityId is set, only allow if user is owner (creator) or we trust the UI check for now.
      if (item.userId != AuthService().currentUserUid && item.communityId == null) return;

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
        // Only decrement stats if it's a file AND personal
        if (!item.isFolder && item.communityId == null) {
           final userRef = FirebaseFirestore.instance.collection('users').doc(item.userId);
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
      final files = getAllFiles(); // Uses filtered list (only personal!)
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
      final Map<String, DocumentSnapshot> cloudDocs = { for (var d in query.docs) d.id : d };

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

      // 3. Sync Down: Add files present in Cloud but missing locally (Ghost Files)
      for (var doc in query.docs) {
          if (!_box.containsKey(doc.id)) {
              final data = doc.data();
              // Create Ghost Item
              // Map Firestore Type index back to Enum
              FileType type = FileType.other;
              if (data['type'] is int) {
                  type = FileType.values[data['type']];
              }

              final newItem = FileItem(
                  id: doc.id,
                  name: data['name'] ?? 'Unknown',
                  size: _formatSize(data['size'] ?? 0),
                  modified: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  type: type,
                  localPath: null, // Ghost File!
                  synced: true,
                  userId: currentUserUid,
                  parentId: data['parentId'], // Sync hierarchy!
                  // TODO: Color for folders?
              );
              await _box.put(doc.id, newItem.toMap());
          }
      }

    } catch (e) {
      print("Sync error: $e");
    }
  }

  // Sync Community Files
  Future<void> syncCommunityFiles(String communityId) async {
      try {
          final query = await FirebaseFirestore.instance
              .collection('files')
              .where('communityId', isEqualTo: communityId)
              .get();
          
          for (var doc in query.docs) {
              if (!_box.containsKey(doc.id)) {
                  final data = doc.data();
                  // Create Ghost File
                   FileType type = FileType.other;
                   if (data['type'] is int) {
                      try {
                          type = FileType.values[data['type']];
                      } catch (_) {}
                   }

                   final newItem = FileItem(
                      id: doc.id,
                      name: data['name'] ?? 'Unknown',
                      size: _formatSize(data['size'] ?? 0),
                      modified: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      type: type,
                      localPath: null, 
                      synced: true,
                      userId: data['userId'], 
                      parentId: data['parentId'], 
                      communityId: communityId,
                      // TODO: Folder color?
                   );
                   await _box.put(doc.id, newItem.toMap());
              }
              // Optional: Update existing if metadata changed?
          }
      } catch (e) {
          print("Error syncing community files: $e");
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

         final String id = const Uuid().v4();
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
