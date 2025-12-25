import 'dart:typed_data';
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
  final String? localPath;
  final bool synced;
  final bool isStarred;
  final Uint8List? content; // For Web support

  const FileItem({
    required this.id,
    required this.name,
    required this.size,
    required this.modified,
    required this.type,
    this.color,
    this.previewUrl,
    this.localPath,
    this.synced = false,
    this.isStarred = false,
    this.content,
  });

  bool get isFolder => type == FileType.folder;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'size': size,
      'modified': modified.toIso8601String(),
      'type': type.index,
      'localPath': localPath,
      'synced': synced,
      'isStarred': isStarred,
      'color': color?.value, // Store int value of color
      'content': content,
    };
  }

  factory FileItem.fromMap(Map<dynamic, dynamic> map) {
    return FileItem(
      id: map['id'],
      name: map['name'],
      size: map['size'],
      modified: DateTime.parse(map['modified']),
      type: FileType.values[map['type']],
      localPath: map['localPath'],
      synced: (map['synced'] as bool?) ?? false,
      isStarred: (map['isStarred'] as bool?) ?? false,
      color: map['color'] != null ? Color(map['color']) : null,
      content: map['content'],
    );
  }
}
