import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class UploadBottomSheet extends StatelessWidget {
  const UploadBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Uploading 3 items',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildUploadItem(context, 'Presentation.pptx', 0.65),
          const SizedBox(height: 16),
          _buildUploadItem(context, 'Vacation_Photos.zip', 0.30),
          const SizedBox(height: 16),
          _buildUploadItem(context, 'Project_Brief.pdf', 1.0, isComplete: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUploadItem(
    BuildContext context,
    String name,
    double progress, {
    bool isComplete = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.file, size: 20),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (isComplete)
                    const Icon(
                      LucideIcons.checkCircle,
                      size: 16,
                      color: Colors.green,
                    )
                  else
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!isComplete)
                LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Theme.of(context).dividerColor,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
