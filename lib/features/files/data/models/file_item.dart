import 'package:flutter/material.dart';

enum FileType { folder, image, video, document, audio, other }

class FileItem {
  final String id;
  final String name;
  final String size;
  final DateTime modified;
  final FileType type;
  final Color? color; // For folders
  final String? previewUrl; // For images (mock asset path)

  const FileItem({
    required this.id,
    required this.name,
    required this.size,
    required this.modified,
    required this.type,
    this.color,
    this.previewUrl,
  });

  bool get isFolder => type == FileType.folder;
}
