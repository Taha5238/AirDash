import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../data/models/file_item.dart';
import '../../data/repositories/offline_file_service.dart';

import 'file_detail_view.dart';
import 'file_search_delegate.dart';

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


  Future<void> _pickAndSaveFile() async {
    try {
      final newItem = await _fileService.pickAndSaveFile();
      if (newItem != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved offline!')),
        );
        // _loadFiles(); // Handled by listener
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error saving file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    await _fileService.deleteFile(file.id);
    
    if (_selectedFile?.id == file.id) {
        setState(() {
            _selectedFile = null;
        });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File deleted.')),
    );

  }

  Future<void> _shareFile(FileItem file) async {
    try {
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
    if (ResponsiveLayout.isDesktop(context)) {
      setState(() {
        _selectedFile = file;
      });
    } else {
      // Mobile Navigation
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('filesBox').listenable(),
      builder: (context, box, _) {
        // Re-fetch files whenever box changes
        final allFiles = _fileService.getAllFiles();
        
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
                  onDelete: _deleteFile,
                  onShare: _shareFile,
                  onSearch: _onSearch,
                  onFilter: _onFilter,
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
            onDelete: _deleteFile,
            onShare: _shareFile,
            onSearch: _onSearch,
            onFilter: _onFilter,
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
  final Function(FileItem) onDelete;
  final Function(FileItem) onShare;
  final Function(String) onSearch;
  final Function(FileType?) onFilter;

  const _FileListView({
    required this.files,
    required this.onFileTap,
    this.selectedFile,
    required this.onUpload,
    required this.onDelete,
    required this.onShare,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Files'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search), 
             onPressed: () {
                // Determine search state? For now, we'll just allow typing if we had a field.
                // Or implementing a simple search bar in the AppBar
                showSearch(context: context, delegate: FileSearchDelegate(files, onSearch));
             }
          ),

          PopupMenuButton<FileType>(
            icon: const Icon(LucideIcons.filter),
            onSelected: onFilter,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All')),
              ...FileType.values.map(
                (type) => PopupMenuItem(
                  value: type, 
                  child: Text(type.toString().split('.').last.toUpperCase())
                )
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onUpload,
        icon: const Icon(LucideIcons.uploadCloud),
        label: const Text('Upload'),
      ),
      body: files.isEmpty 
          ? const Center(child: Text("No files yet. Upload one!"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          final isSelected = selectedFile?.id == file.id;

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 50)),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Card(
              elevation: isSelected ? 2 : 0,
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : null,
              child: ListTile(
                leading: Hero(
                  tag: 'file_icon_${file.id}',
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          file.color?.withValues(alpha: 0.2) ??
                          Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForType(file.type),
                      color:
                          file.color ?? Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                title: Text(
                  file.name,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.size),
                    Text(
                      file.synced ? "Synced" : "Local only",
                      style: TextStyle(
                        fontSize: 10,
                        color: file.synced ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
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
                      icon: const Icon(LucideIcons.moreVertical, size: 20), // explicit icon for alignment
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete(file);
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return {'Delete'}.map((String choice) {
                          return PopupMenuItem<String>(
                            value: choice.toLowerCase(),
                            child: Text(choice),
                          );
                        }).toList();
                      },
                    ),
                  ],
                ),
                onTap: () => onFileTap(file),
                selected: isSelected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForType(FileType type) {
    switch (type) {
      case FileType.folder:
        return LucideIcons.folder;
      case FileType.image:
        return LucideIcons.image;
      case FileType.video:
        return LucideIcons.video;
      case FileType.document:
        return LucideIcons.fileText;
      case FileType.audio:
        return LucideIcons.music;
      default:
        return LucideIcons.file;
    }
  }
}
