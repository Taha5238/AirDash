import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_item.dart';

class FileDetailView extends StatelessWidget {
  final FileItem file;

  const FileDetailView({super.key, required this.file});

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
              tag: 'file_icon_${file.id}',
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color:
                      file.color?.withValues(alpha: 0.2) ??
                      Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getIconForType(file.type),
                  size: 80,
                  color: file.color ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            file.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${file.size} • Modified ${_formatDate(file.modified)}',
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
            children: [
              _ActionButton(
                icon: LucideIcons.download,
                label: 'Download',
                onTap: () {},
              ),
              _ActionButton(
                icon: LucideIcons.share2,
                label: 'Share',
                onTap: () {},
              ),
              _ActionButton(
                icon: LucideIcons.star,
                label: 'Add to Starred',
                onTap: () {},
              ),
              _ActionButton(
                icon: LucideIcons.trash2,
                label: 'Delete',
                color: Colors.red,
                onTap: () {},
              ),
            ],
          ),

          const Spacer(),
          if (file.isFolder) ...[
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

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalColor = color ?? theme.colorScheme.primary;

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
            Icon(icon, color: finalColor),
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
