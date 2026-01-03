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
  final String? userId; // Owner of the file
  final String? parentId; // ID of the parent folder (null for root)

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
    this.userId,
    this.parentId,
  });

  bool get isFolder => type == FileType.folder;
  
  FileItem copyWith({
    String? id,
    String? name,
    String? size,
    DateTime? modified,
    FileType? type,
    Color? color,
    String? previewUrl,
    String? localPath,
    bool? synced,
    bool? isStarred,
    Uint8List? content,
    String? userId,
    String? parentId,
  }) {
    return FileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      type: type ?? this.type,
      color: color ?? this.color,
      previewUrl: previewUrl ?? this.previewUrl,
      localPath: localPath ?? this.localPath,
      synced: synced ?? this.synced,
      isStarred: isStarred ?? this.isStarred,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
    );
  }

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
      'color': color?.value,
      'content': content,
      'userId': userId,
      'parentId': parentId,
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
      userId: map['userId'],
      parentId: map['parentId'],
    );
  }
}
