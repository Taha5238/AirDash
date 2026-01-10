import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
      
      // We need to find the parent of the current folder to know where to go back to.
      // Or we can just go to root if we don't track stack? 
      // Better to query the current folder's item to find its parentId.
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

        // If selected file was deleted (not in allFiles), clear selection
        if (_selectedFile != null && !allFiles.any((f) => f.id == _selectedFile!.id)) {
            // Schedule the state update for next frame to avoid build collision
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                   setState(() {
                     _selectedFile = null;
                   });
                }
            });
        }
        
        // Also update selected file reference if it changed (e.g. starred status)
        if (_selectedFile != null) {
           try {
             final updatedSelected = allFiles.firstWhere((f) => f.id == _selectedFile!.id);
             if (updatedSelected != _selectedFile) {
               // We don't need setState here usually if we just pass updatedSelected down, 
               // but _selectedFile is state.
               // Let's just use updatedSelected in the UI.
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

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              if (currentFolderId != null)
                IconButton(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: onNavigateUp,
                  tooltip: "Back",
                ),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search files...",
                    prefixIcon: Icon(LucideIcons.search, size: 20),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: 8),
               // Filter Dropdown
              PopupMenuButton<FileType?>(
                icon: const Icon(LucideIcons.filter, size: 20),
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.folderPlus, size: 20),
                tooltip: "New Folder",
                onPressed: onCreateFolder,
              ),
              IconButton(
                 icon: const Icon(LucideIcons.uploadCloud, size: 20),
                 tooltip: "Upload",
                 onPressed: onUpload,
              ),
              IconButton(
                 icon: const Icon(LucideIcons.download, size: 20),
                 tooltip: "Restore from Cloud",
                 onPressed: onRestore,
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
                      Icon(LucideIcons.folderOpen, size: 48, color: Theme.of(context).disabledColor),
                      const SizedBox(height: 16),
                      Text("No files found", style: TextStyle(color: Theme.of(context).disabledColor)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final isSelected = selectedFile?.id == file.id;

                    return ListTile(
                      key: ValueKey(file.id),
                      selected: isSelected,
                      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      leading: Icon(
                        file.isFolder ? LucideIcons.folder : _getIconForType(file.type),
                        color: file.isFolder ? Colors.amber : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: isSelected ? const TextStyle(fontWeight: FontWeight.bold) : null,
                      ),
                      subtitle: Text(
                        "${file.size} • ${_formatDate(file.modified)}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(LucideIcons.share2, size: 20),
                              tooltip: "Share",
                              onPressed: () => onShare(file),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(LucideIcons.moreVertical, size: 20),
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
                    );
                  },
                ),
        ),
        
        // Footer Status
        Container(
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Text(
                 "$folderCount folders, $fileCount files",
                 style: Theme.of(context).textTheme.bodySmall,
               ),
            ],
          ),
        ),
      ],
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
