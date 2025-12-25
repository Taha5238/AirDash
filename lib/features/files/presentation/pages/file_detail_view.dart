import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../data/models/file_item.dart';
import '../../data/repositories/offline_file_service.dart';

class FileDetailView extends StatefulWidget {
  final FileItem file;

  const FileDetailView({super.key, required this.file});

  @override
  State<FileDetailView> createState() => _FileDetailViewState();
}

class _FileDetailViewState extends State<FileDetailView> {
  final OfflineFileService _fileService = OfflineFileService();
  late FileItem _file;

  @override
  void initState() {
    super.initState();
    _file = widget.file;
  }

  @override
  void didUpdateWidget(FileDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.id != oldWidget.file.id || widget.file.isStarred != oldWidget.file.isStarred) {
      _file = widget.file;
    }
  }

  Future<void> _handleDownload() async {
    try {
      await _fileService.downloadFile(_file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download started')),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleShare() async {
     showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Allow full height and keyboard handling
        builder: (context) => Padding(
            // Handle keyboard overlap
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
                child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text("Share file", style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 24),
                            
                            // 1. Link Section
                            Text("File Link", style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                    children: [
                                        Expanded(
                                            child: Text(
                                                "https://airdash.app/share/${_file.id}",
                                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                overflow: TextOverflow.ellipsis,
                                            ),
                                        ),
                                        IconButton(
                                            icon: const Icon(LucideIcons.copy),
                                            tooltip: "Copy Link",
                                            onPressed: () {
                                                _fileService.copyToClipboard(_file);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Link copied to clipboard')),
                                                );
                                                Navigator.pop(context);
                                            },
                                        ),
                                    ],
                                ),
                            ),
                            
                            const SizedBox(height: 24),

                            // 2. Email Section
                            Text("Send via Email", style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 8),
                            TextField(
                                decoration: InputDecoration(
                                    hintText: "Enter email address",
                                    suffixIcon: IconButton(
                                        icon: const Icon(LucideIcons.send),
                                        onPressed: () {
                                            // We need a controller or logic to get text, but for stateless simplicity
                                            // we might need to extract this widget.
                                            // check below for widget extraction plan.
                                        },
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onSubmitted: (value) {
                                    if (value.isNotEmpty) {
                                        Navigator.pop(context);
                                        _fileService.shareViaEmail(_file, recipient: value);
                                    }
                                },
                            ),

                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),

                            // 3. Social & System
                            Text("Social Share", style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 16),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                    _SocialIconBtn(
                                        icon: LucideIcons.messageCircle, 
                                        color: Colors.green, 
                                        label: "WhatsApp",
                                        onTap: () {
                                             Navigator.pop(context);
                                             _fileService.shareToSocial(_file, 'whatsapp');
                                        }
                                    ),
                                    _SocialIconBtn(
                                        icon: LucideIcons.twitter, 
                                        color: Colors.blue, 
                                        label: "Twitter",
                                         onTap: () {
                                             Navigator.pop(context);
                                             _fileService.shareToSocial(_file, 'twitter');
                                        }
                                    ),
                                    _SocialIconBtn(
                                        icon: LucideIcons.linkedin, 
                                        color: Colors.blueAccent, 
                                        label: "LinkedIn",
                                         onTap: () {
                                             Navigator.pop(context);
                                             _fileService.shareToSocial(_file, 'linkedin');
                                        }
                                    ),
                                    _SocialIconBtn(
                                        icon: LucideIcons.share2, 
                                        color: Theme.of(context).colorScheme.primary, 
                                        label: "More",
                                         onTap: () {
                                             Navigator.pop(context);
                                             _fileService.shareLinkOrEmail(_file);
                                        }
                                    ),
                                ],
                            ),
                            const SizedBox(height: 16),
                        ],
                    ),
                ),
            ),
        ),
    );
  }

  Future<void> _handleStar() async {
    final updated = await _fileService.toggleStar(_file.id);
    if (updated != null && mounted) {
      setState(() {
        _file = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_file.isStarred ? 'Added to Starred' : 'Removed from Starred')),
        );
    }
  }

  Future<void> _handleDelete() async {
     // Show confirmation dialog logic here usually, but for speed:
     await _fileService.deleteFile(_file.id);
     if (mounted) {
       // Only pop if we are on mobile (pushed status)
       // OR check if we can pop safely without exiting the app
       if (!ResponsiveLayout.isDesktop(context)) {
          Navigator.of(context).pop(); 
       }
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted')),
        );
     }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Preview
          Center(
            child: Hero(
              tag: 'file_icon_${_file.id}',
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color:
                      _file.color?.withValues(alpha: 0.2) ??
                      Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildFilePreview(context),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            _file.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${_file.size} • Modified ${_formatDate(_file.modified)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),

          const SizedBox(height: 32),

          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _ActionButton(
                icon: LucideIcons.download,
                label: 'Download',
                onTap: _handleDownload,
              ),
              _ActionButton(
                icon: LucideIcons.share2,
                label: 'Share',
                onTap: _handleShare,
              ),
              _ActionButton(
                icon: _file.isStarred ? LucideIcons.star : LucideIcons.star,
                iconColor: _file.isStarred ? Colors.orange : null,
                label: _file.isStarred ? 'Starred' : 'Add to Starred',
                onTap: _handleStar,
              ),
              _ActionButton(
                icon: LucideIcons.trash2,
                label: 'Delete',
                color: Colors.red,
                iconColor: Colors.red,
                onTap: _handleDelete,
              ),
            ],
          ),


          const Spacer(),
          if (_file.isFolder) ...[
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Folder Properties',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Text('Contains 12 files'),
          ],
        ],
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

  Widget _buildFilePreview(BuildContext context) {
      if (_file.type == FileType.image) {
          if (_file.content != null) {
              return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                      _file.content!,
                      fit: BoxFit.cover,
                  ),
              );
          } else if (_file.localPath != null) {
              // TODO: Handle Web vs Native if localPath is used (e.g. from cache)
              // But for now, content takes precedence
          }
      }
      return Icon(
          _getIconForType(_file.type),
          size: 80,
          color: _file.color ?? Theme.of(context).colorScheme.primary,
      );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalColor = color ?? theme.colorScheme.primary;
    final finalIconColor = iconColor ?? finalColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: finalIconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: finalColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _SocialIconBtn extends StatelessWidget {
    final IconData icon;
    final Color color;
    final String label;
    final VoidCallback onTap;

    const _SocialIconBtn({required this.icon, required this.color, required this.label, required this.onTap});

    @override
    Widget build(BuildContext context) {
         return GestureDetector(
             onTap: onTap,
             child: Column(
                 children: [
                     Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                             color: color.withValues(alpha: 0.1),
                             shape: BoxShape.circle,
                         ),
                         child: Icon(icon, color: color, size: 24),
                     ),
                     const SizedBox(height: 8),
                     Text(label, style: const TextStyle(fontSize: 12)),
                 ],
             ),
         );
    }
}
