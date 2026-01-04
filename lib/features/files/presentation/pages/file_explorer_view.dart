import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/responsive_layout.dart';
import 'package:airdash/features/files/data/models/file_item.dart';
import 'package:airdash/features/files/data/models/file_type.dart';
import 'package:airdash/features/files/data/repositories/offline_file_service.dart';
import '../widgets/folder_picker_dialog.dart';

import 'file_detail_view.dart';
import 'file_search_delegate.dart';
import 'viewers/image_viewer_page.dart';
import 'viewers/pdf_viewer_page.dart';
import 'viewers/video_player_page.dart';
import 'viewers/office_viewer_page.dart';
import 'package:airdash/features/transfer/presentation/widgets/transfer_user_picker_dialog.dart';
import 'package:airdash/features/transfer/presentation/pages/transfer_progress_screen.dart';

class FileExplorerView extends StatefulWidget {
  const FileExplorerView({super.key});

  @override
  State<FileExplorerView> createState() => _FileExplorerViewState();
}

class _FileExplorerViewState extends State<FileExplorerView> {
  final OfflineFileService _fileService = OfflineFileService();
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

  Future<void> _renameFolder(FileItem folder) async {
       String? newName;
      await showDialog(
         context: context,
         builder: (context) {
             final controller = TextEditingController(text: folder.name);
             return AlertDialog(
                 title: const Text("Rename Folder"),
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

      if (newName != null && newName!.isNotEmpty && newName != folder.name) {
          await _fileService.renameFolder(folder.id, newName!);
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
                  onRename: _renameFolder,
                  onMove: _moveFile,
                  onSearch: _onSearch,
                  onFilter: _onFilter,
                  currentFolderId: _currentFolderId,
                  onNavigateUp: _navigateUp,
                  onSendToUser: _sendToUser,
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
            onRename: _renameFolder,
            onMove: _moveFile,
            onSearch: _onSearch,
            onFilter: _onFilter,
            currentFolderId: _currentFolderId,
            onNavigateUp: _navigateUp,
            onSendToUser: _sendToUser,
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
                                  if (file.isFolder) const PopupMenuItem(value: 'rename', child: Text("Rename")),
                                  if (!file.isFolder) const PopupMenuItem(value: 'transfer', child: Text("Send to User (P2P)")),
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
