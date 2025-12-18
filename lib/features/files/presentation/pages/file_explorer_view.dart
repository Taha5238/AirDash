import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../data/models/file_item.dart';
import '../../data/repositories/mock_file_repository.dart';
import '../widgets/upload_bottom_sheet.dart';
import '../widgets/transfer_modal.dart';
import 'file_detail_view.dart';

class FileExplorerView extends StatefulWidget {
  const FileExplorerView({super.key});

  @override
  State<FileExplorerView> createState() => _FileExplorerViewState();
}

class _FileExplorerViewState extends State<FileExplorerView> {
  final List<FileItem> _files = MockFileRepository.getAllFiles();
  FileItem? _selectedFile;

  @override
  void initState() {
    super.initState();
    if (_files.isNotEmpty) {
      _selectedFile = _files.first;
    }
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
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      return Row(
        children: [
          // Left Pane: List
          Expanded(
            flex: 2, // 40% width
            child: _FileListView(
              files: _files,
              onFileTap: _onFileTap,
              selectedFile: _selectedFile,
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Pane: Detail
          Expanded(
            flex: 3, // 60% width
            child: _selectedFile != null
                ? FileDetailView(
                    key: ValueKey(_selectedFile!.id), // Animate switch
                    file: _selectedFile!,
                  )
                : const Center(child: Text("Select a file")),
          ),
        ],
      );
    } else {
      // Mobile View
      return _FileListView(
        files: _files,
        onFileTap: _onFileTap,
        selectedFile: null, // No highlighting on mobile list
      );
    }
  }
}

class _FileListView extends StatelessWidget {
  final List<FileItem> files;
  final Function(FileItem) onFileTap;
  final FileItem? selectedFile;

  const _FileListView({
    required this.files,
    required this.onFileTap,
    this.selectedFile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Files'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.search), onPressed: () {}),
          IconButton(
            icon: const Icon(LucideIcons.send),
            tooltip: 'Transfer',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: const TransferModal(),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(LucideIcons.filter), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => const UploadBottomSheet(),
          );
        },
        icon: const Icon(LucideIcons.uploadCloud),
        label: const Text('Upload'),
      ),
      body: ListView.builder(
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
                subtitle: Text(file.size),
                trailing: const Icon(LucideIcons.moreVertical, size: 20),
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
