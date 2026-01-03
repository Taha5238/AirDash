import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_item.dart';
import '../../data/repositories/offline_file_service.dart';

class FolderPickerDialog extends StatefulWidget {
  final String? currentFolderId; // To avoid moving into itself or children (advanced)
  final String? fileToMoveId; // To prevent moving folder into itself

  const FolderPickerDialog({super.key, this.currentFolderId, this.fileToMoveId});

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  final OfflineFileService _fileService = OfflineFileService();
  String? _selectedFolderId; // null = Root
  
  // For navigation within the picker
  String? _navigationParentId; 
  List<FileItem> _currentLevelFolders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() {
      // Get all items at current navigation level
      final allFiles = _fileService.getAllFiles(parentId: _navigationParentId);
      setState(() {
          _currentLevelFolders = allFiles.where((f) => f.isFolder).toList();
          // Filter out the file itself if it's a folder we are moving
          if (widget.fileToMoveId != null) {
              _currentLevelFolders.removeWhere((f) => f.id == widget.fileToMoveId);
          }
      });
  }

  void _enterFolder(String folderId) {
      setState(() {
          _navigationParentId = folderId;
      });
      _loadFolders();
  }

  void _goUp() async {
      if (_navigationParentId == null) return;
      
      // Find parent's parent
      // This is inefficient but functional for now: get ALL files to find current parent
      final allFiles = _fileService.getAllFiles(); // unfiltered
      try {
          final currentParent = allFiles.firstWhere((f) => f.id == _navigationParentId);
          setState(() {
              _navigationParentId = currentParent.parentId;
          });
      } catch (e) {
          // If parent not found (root?), go to root
          setState(() {
              _navigationParentId = null;
          });
      }
      _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move to...'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
             if (_navigationParentId != null)
                ListTile(
                   leading: const Icon(LucideIcons.arrowUp),
                   title: const Text(".. (Go Up)"),
                   onTap: _goUp,
                ),
             ListTile(
               leading: const Icon(LucideIcons.home),
               title: const Text("Root Folder"),
               selected: _selectedFolderId == null && _navigationParentId == null, // Can select root only if at root? or allow selecting "Root" explicitly?
               // Let's allow selecting "Current Level" as destination
               onTap: () {
                   setState(() {
                      _selectedFolderId = null; 
                   });
               },
               trailing: _selectedFolderId == null ? const Icon(LucideIcons.check, color: Colors.green) : null,
             ),
             const Divider(),
             Expanded(
               child: ListView.builder(
                 itemCount: _currentLevelFolders.length,
                 itemBuilder: (context, index) {
                   final folder = _currentLevelFolders[index];
                   final isSelected = _selectedFolderId == folder.id;
                   
                   return ListTile(
                     leading: Icon(LucideIcons.folder, color: folder.color ?? Colors.blue),
                     title: Text(folder.name),
                     trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            if (isSelected) const Icon(LucideIcons.check, color: Colors.green),
                            IconButton(
                                icon: const Icon(LucideIcons.chevronRight),
                                onPressed: () => _enterFolder(folder.id),
                            )
                        ],
                     ),
                     onTap: () {
                        setState(() {
                           _selectedFolderId = folder.id;
                        });
                     },
                   );
                 },
               ),
             ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
             Navigator.pop(context, _selectedFolderId ?? "root");
          },
          child: const Text('Move Here'),
        ),
      ],
    );
  }
}
