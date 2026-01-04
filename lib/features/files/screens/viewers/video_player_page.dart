import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/file_item.dart';
import '../file_detail_view.dart';

class VideoPlayerPage extends StatefulWidget {
  final FileItem file;

  const VideoPlayerPage({super.key, required this.file});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (kIsWeb) {
          // Implementing web blob/url video logic is complex for this scope if using raw bytes.
          // Fallback if content is raw bytes and not URL.
          // Assuming local path for native or bytes for web. Not fully supported here for byte-only yet.
          setState(() { _error = true; });
          return;
      }
      
      if (widget.file.localPath == null) {
         setState(() { _error = true; });
         return;
      }

      _videoPlayerController = VideoPlayerController.file(File(widget.file.localPath!));
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
       print("Video Init Error: $e");
       setState(() { _error = true; });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.file.name),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        actions: [
            IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: "File Details",
                onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Scaffold(
                            appBar: AppBar(title: Text(widget.file.name)),
                            body: FileDetailView(file: widget.file),
                        )),
                    );
                },
            ),
        ],
      ),
      body: Center(
        child: _error 
         ? const Text("Could not load video.", style: TextStyle(color: Colors.white))
         : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
