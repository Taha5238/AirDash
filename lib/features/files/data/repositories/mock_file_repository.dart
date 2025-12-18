import 'package:flutter/material.dart';
import '../models/file_item.dart';

class MockFileRepository {
  static List<FileItem> getRecentFiles() {
    return [
      FileItem(
        id: '1',
        name: 'Project Proposal.pdf',
        size: '2.4 MB',
        modified: DateTime.now().subtract(const Duration(hours: 2)),
        type: FileType.document,
      ),
      FileItem(
        id: '2',
        name: 'Design Assets',
        size: '156 MB',
        modified: DateTime.now().subtract(const Duration(days: 1)),
        type: FileType.folder,
        color: Colors.blueAccent,
      ),
      FileItem(
        id: '3',
        name: 'Vacation.mp4',
        size: '450 MB',
        modified: DateTime.now().subtract(const Duration(days: 3)),
        type: FileType.video,
      ),
      FileItem(
        id: '4',
        name: 'logo_v2.png',
        size: '1.2 MB',
        modified: DateTime.now().subtract(const Duration(hours: 5)),
        type: FileType.image,
      ),
    ];
  }

  static List<FileItem> getFolders() {
    return [
      FileItem(
        id: 'f1',
        name: 'Documents',
        size: '1.2 GB',
        modified: DateTime.now(), // Placeholder
        type: FileType.folder,
        color: const Color(0xFF3B82F6), // Blue
      ),
      FileItem(
        id: 'f2',
        name: 'Images',
        size: '3.4 GB',
        modified: DateTime.now(),
        type: FileType.folder,
        color: const Color(0xFFF59E0B), // Amber
      ),
      FileItem(
        id: 'f3',
        name: 'Work',
        size: '800 MB',
        modified: DateTime.now(),
        type: FileType.folder,
        color: const Color(0xFF10B981), // Green
      ),
      FileItem(
        id: 'f4',
        name: 'Personal',
        size: '200 MB',
        modified: DateTime.now(),
        type: FileType.folder,
        color: const Color(0xFF8B5CF6), // Purple
      ),
    ];
  }

  static List<FileItem> getAllFiles() {
    return [
      ...getFolders(),
      ...getRecentFiles(),
      FileItem(
        id: '5',
        name: 'Budget 2024.xlsx',
        size: '45 KB',
        modified: DateTime.now().subtract(const Duration(days: 5)),
        type: FileType.document,
      ),
      FileItem(
        id: '6',
        name: 'Audio_Recording.wav',
        size: '12 MB',
        modified: DateTime.now().subtract(const Duration(hours: 1)),
        type: FileType.audio,
      ),
    ];
  }
}
