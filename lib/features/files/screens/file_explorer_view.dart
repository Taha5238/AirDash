import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart'; // Added
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/utils/responsive_layout.dart';
import 'package:airdash/features/files/models/file_item.dart';
import 'package:airdash/features/files/models/file_type.dart';
import 'package:airdash/features/files/models/file_type.dart';
import 'package:airdash/features/files/repositories/offline_file_service.dart';
import 'package:airdash/features/files/repositories/supabase_file_service.dart';
import '../widgets/folder_picker_dialog.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'file_detail_view.dart';
import 'file_search_delegate.dart';
import 'viewers/image_viewer_page.dart';
import 'viewers/pdf_viewer_page.dart';
import 'viewers/video_player_page.dart';
import 'viewers/office_viewer_page.dart';
import 'package:airdash/features/transfer/widgets/transfer_user_picker_dialog.dart';
import 'package:airdash/features/transfer/screens/transfer_progress_screen.dart';

class FileExplorerView extends StatefulWidget {
  const FileExplorerView({super.key});

  @override
  State<FileExplorerView> createState() => _FileExplorerViewState();
}

class _FileExplorerViewState extends State<FileExplorerView> {
  final OfflineFileService _fileService = OfflineFileService();
  final SupabaseFileService _supabaseService = SupabaseFileService();
  // List<FileItem> _files = []; // Handled by ValueListenableBuilder
  FileItem? _selectedFile;
  String _searchQuery = '';
  FileType? _filterType;
  
  String? _currentFolderId; // Current folder ID (null = root)


  Future<void> _pickAndSaveFile() async {
    try {
      final newItem = await _fileService.pickAndSaveFile(parentId: _currentFolderId);
      if (newItem != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved offline!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error saving file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createFolder() async {
      String? folderName;
      await showDialog(
         context: context,
         builder: (context) {
             final controller = TextEditingController();
             return AlertDialog(
                 title: const Text("New Folder"),
                 content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: "Folder Name"),
                    autofocus: true,
                    onSubmitted: (val) => Navigator.pop(context),
                 ),
                 actions: [
                     TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                     FilledButton(
                         onPressed: () {
                             folderName = controller.text.trim();
                             Navigator.pop(context);
                         }, 
                         child: const Text("Create")
                     ),
                 ],
             );
         }
      );

      if (folderName != null && folderName!.isNotEmpty) {
          try {
             await _fileService.createFolder(folderName!, parentId: _currentFolderId);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Folder created")));
          } catch(e) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      }
  }

  Future<void> _renameItem(FileItem item) async {
       String? newName;
      await showDialog(
         context: context,
         builder: (context) {
             final controller = TextEditingController(text: item.name);
             return AlertDialog(
                 title: Text("Rename ${item.isFolder ? 'Folder' : 'File'}"),
                 content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: "New Name"),
                    autofocus: true,
                    onSubmitted: (val) => Navigator.pop(context),
                 ),
                 actions: [
                     TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                     FilledButton(
                         onPressed: () {
                             newName = controller.text.trim();
                             Navigator.pop(context);
                         }, 
                         child: const Text("Rename")
                     ),
                 ],
             );
         }
      );

      if (newName != null && newName!.isNotEmpty && newName != item.name) {
          try {
            if (item.isFolder) {
                await _fileService.renameFolder(item.id, newName!);
            } else {
                await _fileService.renameFile(item.id, newName!);
                // Sync to Supabase if it's a cloud backup
                if (item.synced) {
                    await _supabaseService.renameBackup(item.id, newName!);
                }
            }
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Renamed successfully")));
          } catch (e) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rename failed: $e"))); 
          }
      }
  }

  Future<void> _moveFile(FileItem item) async {
      final String? destReturn = await showDialog<String?>(
          context: context,
          builder: (context) => FolderPickerDialog(
             currentFolderId: _currentFolderId,
             fileToMoveId: item.id,
          ),
      );
      
      if (destReturn != null) {
          final String? finalDestId = destReturn == "root" ? null : destReturn;
          if (finalDestId != item.parentId) {
             await _fileService.moveFile(item.id, finalDestId);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved.")));
          }
      }
      
  }

  Future<void> _sendToUser(FileItem item) async {
       if (item.isFolder) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot transfer folders directly yet.")));
           return;
       }

       final String? userId = await showDialog<String>(
           context: context,
           builder: (context) => const TransferUserPickerDialog(),
       );

       if (userId != null && mounted) {
           Navigator.of(context).push(
               MaterialPageRoute(
                   builder: (context) => TransferProgressScreen(file: item, receiverId: userId),
               ),
           );
       }
  }

  Future<void> _deleteFile(FileItem file) async {
    // Confirmation
    final bool confirm = await showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: Text(file.isFolder ? 'Delete Folder?' : 'Delete File?'),
        content: Text(file.isFolder 
          ? 'This will delete the folder and ALL its contents. This cannot be undone.' 
          : 'Are you sure you want to delete this file?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete")
          ),
        ],
      )
    ) ?? false;

    if (!confirm) return;

    await _fileService.deleteFile(file.id);
    
    if (_selectedFile?.id == file.id) {
        setState(() {
            _selectedFile = null;
        });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item deleted.')),
    );
  }

  Future<void> _shareFile(FileItem file) async {
    try {
      if (file.isFolder) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot share folders yet.")));
         return;
      }
      await _fileService.shareFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _backupFile(FileItem file) async {
    // Check if file is actually local
    if (file.localPath == null && file.content == null) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot backup: File is not downloaded (Ghost File).'), backgroundColor: Colors.orange),
       );
       return;
    }

    try {
      await _supabaseService.backupFile(file);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File backed up successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _restoreFile() async {
    try {
      // 1. Fetch cloud files
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
          throw Exception("User not logged in");
      }
      final cloudFiles = await _supabaseService.getCloudFiles(user.uid);
      
      if (!mounted) return;

      // 2. Show dialog to pick
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Restore from Cloud"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: cloudFiles.isEmpty 
              ? const Center(child: Text("No backups found."))
              : ListView.builder(
                  itemCount: cloudFiles.length,
                  itemBuilder: (context, index) {
                    final data = cloudFiles[index];
                    return ListTile(
                      leading: const Icon(LucideIcons.cloud),
                      title: Text(data['file_name'] ?? 'Unknown'),
                      subtitle: Text(data['file_size'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.download),
                        onPressed: () async {
                          Navigator.pop(context); // Close dialog first
                          await _executeRestore(data);
                        },
                      ),
                    );
                  },
              ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error fetching backups: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _executeRestore(Map<String, dynamic> data) async {
      try {
           final String path = data['storage_path']; // Correct key
           final String name = data['file_name'];    // Correct key
           
           final bytes = await _supabaseService.downloadFileContent(path);
           
           // Save locally
           final dir = await getApplicationDocumentsDirectory();
           final file = File('${dir.path}/$name');
           await file.writeAsBytes(bytes);
           
           // Resolve FileType from String
           FileType type = FileType.other;
           final String? typeStr = data['file_type'];
           if (typeStr != null) {
              try {
                 type = FileType.values.firstWhere((e) => e.toString().split('.').last == typeStr);
              } catch (_) {}
           }

           final user = FirebaseAuth.instance.currentUser;
           if (user == null) throw Exception("User not logged in");

           final newFile = FileItem(
               id: data['id'], 
               name: name,
               size: data['file_size'] ?? '0 B',
               modified: DateTime.now(),
               type: type,
               localPath: file.path,
               parentId: _currentFolderId,
               userId: user.uid,
           );
           
           final box = Hive.box('filesBox');
           await box.put(newFile.id, newFile.toMap());
           
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('File restored')),
           );

      } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
           );
      }
  }

  void _onSearch(String query) {
      setState(() {
          _searchQuery = query;
      });
  }

  void _onFilter(FileType? type) {
      setState(() {
          _filterType = type;
      });
  }



  void _onFileTap(FileItem file) {
    if (file.isFolder) {
        // Enter folder
        setState(() {
            _currentFolderId = file.id;
            _selectedFile = null; // Deselect when entering folder
        });
        return;
    }

    // GHOST FILE CHECK
    if (file.localPath == null && file.content == null && file.synced) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                title: const Text("File Not Available Locally"),
                content: const Text("This file exists on another device (synced metadata). To view it here, use the 'Transfer' feature from the other device."),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                ],
            )
        );
        return;
    }

    if (ResponsiveLayout.isDesktop(context)) {
      setState(() {
        _selectedFile = file;
      });
    } else {
      // Mobile Navigation logic with strict in-app viewers
      Widget? viewerPage;
      
      switch (file.type) {
          case FileType.image:
              viewerPage = ImageViewerPage(file: file);
              break;
          case FileType.document:
              if (file.name.toLowerCase().endsWith('.pdf')) {
                  viewerPage = PdfViewerPage(file: file);
              } else if (file.name.toLowerCase().endsWith('.docx') || file.name.toLowerCase().endsWith('.xlsx')) {
                  viewerPage = OfficeViewerPage(file: file); // iOS only, Android shows message
              }
              break;
          case FileType.video:
              viewerPage = VideoPlayerPage(file: file);
              break;
          default:
              break;
      }

      if (viewerPage != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => viewerPage!),
          );
      } else {
          // Fallback to Detail View if no viewer or "Other" type
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text(file.name)),
                body: FileDetailView(file: file),
              ),
            ),
          );
      }
    }
  }

  void _navigateUp() {
      if (_currentFolderId == null) return;
      final item = Hive.box('filesBox').get(_currentFolderId);
      if (item != null) {
          final map = Map<String, dynamic>.from(item);
          final folder = FileItem.fromMap(map);
          setState(() {
              _currentFolderId = folder.parentId;
          });
      } else {
          // Folder doesn't exist? Go literal root.
          setState(() {
              _currentFolderId = null;
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('filesBox').listenable(),
      builder: (context, box, _) {
        // Re-fetch files whenever box changes
        final allFiles = _fileService.getAllFiles(parentId: _currentFolderId);

        
        // Apply Filters
        final filteredFiles = allFiles.where((file) {
          final matchesSearch = file.name.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesType = _filterType == null || file.type == _filterType;
          return matchesSearch && matchesType;
        }).toList();
        if (_selectedFile != null && !allFiles.any((f) => f.id == _selectedFile!.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                   setState(() {
                     _selectedFile = null;
                   });
                }
            });
        }
        
        if (_selectedFile != null) {
           try {
             final updatedSelected = allFiles.firstWhere((f) => f.id == _selectedFile!.id);
             if (updatedSelected != _selectedFile) {
               _selectedFile = updatedSelected;
             }
           } catch (_) {}
        }

        final bool isDesktop = ResponsiveLayout.isDesktop(context);

        if (isDesktop) {
          return Row(
            children: [
              // Left Pane: List
              Expanded(
                flex: 2, 
                child: _FileListView(
                  files: filteredFiles,
                  onFileTap: _onFileTap,
                  selectedFile: _selectedFile,
                  onUpload: _pickAndSaveFile,
                  onCreateFolder: _createFolder,
                  onDelete: _deleteFile,
                  onShare: _shareFile,
                  onRename: _renameItem,
                  onMove: _moveFile,
                  onSearch: _onSearch,
                  onFilter: _onFilter,
                  currentFolderId: _currentFolderId,
                  onNavigateUp: _navigateUp,
                  onSendToUser: _sendToUser,
                  onRestore: _restoreFile,
                  onBackup: _backupFile,
                ),
              ),
              const VerticalDivider(width: 1),
              // Right Pane: Detail
              Expanded(
                flex: 3, 
                child: _selectedFile != null
                    ? FileDetailView(
                        key: ValueKey(_selectedFile!.id), 
                        file: _selectedFile!,
                      )
                    : const Center(child: Text("Select a file")),
              ),
            ],
          );
        } else {
          // Mobile View
          return _FileListView(
            files: filteredFiles,
            onFileTap: _onFileTap,
            selectedFile: null, 
            onUpload: _pickAndSaveFile,
            onCreateFolder: _createFolder,
            onDelete: _deleteFile,
            onShare: _shareFile,
            onRename: _renameItem,
            onMove: _moveFile,
            onSearch: _onSearch,
            onFilter: _onFilter,
            currentFolderId: _currentFolderId,
            onNavigateUp: _navigateUp,
            onSendToUser: _sendToUser,
            onRestore: _restoreFile,
            onBackup: _backupFile,
          );
        }
      },
    );
  }
}

class _FileListView extends StatelessWidget {
  final List<FileItem> files;
  final Function(FileItem) onFileTap;
  final FileItem? selectedFile;
  final VoidCallback onUpload;
  final VoidCallback onCreateFolder;
  final Function(FileItem) onDelete;
  final Function(FileItem) onShare;
  final Function(FileItem) onRename;
  final Function(FileItem) onMove;
  final Function(String) onSearch;
  final Function(FileType?) onFilter;
  final String? currentFolderId;
  final VoidCallback onNavigateUp;
  final Function(FileItem) onSendToUser;
  final VoidCallback onRestore;
  final Function(FileItem) onBackup;

  const _FileListView({
    required this.files,
    required this.onFileTap,
    this.selectedFile,
    required this.onUpload,
    required this.onCreateFolder,
    required this.onDelete,
    required this.onShare,
    required this.onRename,
    required this.onMove,
    required this.onSearch,
    required this.onFilter,
    this.currentFolderId,
    required this.onNavigateUp,
    required this.onSendToUser,
    required this.onRestore,
    required this.onBackup,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out folders from the list for the file count, but display them
    final fileCount = files.where((f) => !f.isFolder).length;
    final folderCount = files.where((f) => f.isFolder).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            showModalBottomSheet(
                context: context,
                backgroundColor: Theme.of(context).cardColor,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (context) => SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Text("Add New", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                ListTile(
                                    leading: const Icon(LucideIcons.uploadCloud, color: Colors.blue),
                                    title: const Text("Upload File"),
                                    onTap: () { Navigator.pop(context); onUpload(); },
                                ),
                                ListTile(
                                    leading: const Icon(LucideIcons.folderPlus, color: Colors.amber),
                                    title: const Text("Create Folder"),
                                    onTap: () { Navigator.pop(context); onCreateFolder(); },
                                ),
                                ListTile(
                                    leading: const Icon(LucideIcons.downloadCloud, color: Colors.purple),
                                    title: const Text("Restore from Cloud"),
                                    onTap: () { Navigator.pop(context); onRestore(); },
                                ),
                            ],
                        ),
                    ),
                ),
            );
        },
        label: const Text("Add New"),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Modern Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
               children: [
                 if (currentFolderId != null)
                   Padding(
                     padding: const EdgeInsets.only(right: 8),
                     child: IconButton(
                       icon: const Icon(LucideIcons.arrowLeft),
                       onPressed: onNavigateUp,
                       style: IconButton.styleFrom(
                         backgroundColor: Theme.of(context).cardColor,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                   ),
                 Expanded(
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     height: 50,
                     decoration: BoxDecoration(
                       color: Theme.of(context).cardColor,
                       borderRadius: BorderRadius.circular(25),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.05),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                     child: Row(
                       children: [
                         Icon(LucideIcons.search, color: Colors.grey[400]),
                         const SizedBox(width: 12),
                         Expanded(
                           child: TextField(
                             decoration: const InputDecoration(
                               hintText: "Search your files...",
                               border: InputBorder.none,
                               isDense: true,
                             ),
                             onChanged: onSearch,
                           ),
                         ),
                         // Filter Icon inside Search Pill
                         PopupMenuButton<FileType?>(
                           icon: Icon(LucideIcons.slidersHorizontal, color: Colors.grey[600], size: 20),
                           tooltip: "Filter",
                           onSelected: onFilter,
                           itemBuilder: (context) => [
                             const PopupMenuItem(value: null, child: Text("All Files")),
                             ...FileType.values.map(
                               (type) => PopupMenuItem(
                                 value: type,
                                 child: Text(type.toString().split('.').last.toUpperCase()),
                               ),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                 ),
               ],
            ),
          ),

          // File List
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.folderOpen, size: 60, color: Theme.of(context).primaryColor),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "No files found",
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Upload a file or create a folder to get started",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: onUpload,
                          icon: const Icon(LucideIcons.uploadCloud),
                          label: const Text("Upload First File"),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final isSelected = selectedFile?.id == file.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                          border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
                        ),
                        child: ListTile(
                          key: ValueKey(file.id),
                          selected: isSelected,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: file.isFolder ? Colors.amber.withOpacity(0.1) : Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              file.isFolder ? LucideIcons.folder : _getIconForType(file.type),
                              color: file.isFolder ? Colors.amber : Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${file.size} • ${_formatDate(file.modified)}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(LucideIcons.share2, size: 20, color: Colors.grey),
                                  tooltip: "Share",
                                  onPressed: () => onShare(file),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(LucideIcons.moreVertical, size: 20, color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    onDelete(file);
                                  } else if (value == 'rename') {
                                     onRename(file);
                                  } else if (value == 'move') {
                                      onMove(file);
                                  } else if (value == 'transfer') {
                                      onSendToUser(file);
                                  } else if (value == 'backup') {
                                      onBackup(file);
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  return {'Delete'}.map((String choice) {
                                    return PopupMenuItem<String>(
                                      value: choice.toLowerCase(),
                                      child: Text(choice),
                                    );
                                  }).toList()
                                  ..addAll([
                                      const PopupMenuItem(value: 'move', child: Text("Move to...")),
                                      const PopupMenuItem(value: 'rename', child: Text("Rename")),
                                      if (!file.isFolder) const PopupMenuItem(value: 'transfer', child: Text("Send to User (P2P)")),
                                      if (!file.isFolder) const PopupMenuItem(value: 'backup', child: Text("Backup to Cloud")),
                                  ]);
                                },
                              ),
                            ],
                          ),
                          onTap: () => onFileTap(file),
                        ),
                      );
                    },
                  ),
          ),
          
          // Folder/File Count Status
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "$folderCount folders, $fileCount files",
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForType(FileType type) {
    switch (type) {
      case FileType.image: return LucideIcons.image;
      case FileType.video: return LucideIcons.video;
      case FileType.audio: return LucideIcons.music;
      case FileType.document: return LucideIcons.fileText;
      case FileType.pdf: return LucideIcons.file;
      case FileType.archive: return LucideIcons.archive;
      case FileType.other: return LucideIcons.file;
      default: return LucideIcons.file;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
  }
}
