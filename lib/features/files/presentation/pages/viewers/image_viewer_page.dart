import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../../data/models/file_item.dart';
import '../file_detail_view.dart';

class ImageViewerPage extends StatelessWidget {
  final FileItem file;

  const ImageViewerPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;

    if (file.content != null) {
      imageProvider = MemoryImage(file.content!);
    } else if (!kIsWeb && file.localPath != null) {
      imageProvider = FileImage(File(file.localPath!));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(file.name),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        actions: [
            IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: "File Details",
                onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Scaffold(
                            appBar: AppBar(title: Text(file.name)),
                            body: FileDetailView(file: file),
                        )),
                    );
                },
            ),
        ],
      ),
      body: imageProvider != null
          ? PhotoView(
              imageProvider: imageProvider,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            )
          : const Center(
              child: Text("Image not available", style: TextStyle(color: Colors.white)),
            ),
    );
  }
}
