import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../data/models/file_item.dart';
import '../file_detail_view.dart';

class OfficeViewerPage extends StatefulWidget {
  final FileItem file;

  const OfficeViewerPage({super.key, required this.file});

  @override
  State<OfficeViewerPage> createState() => _OfficeViewerPageState();
}

class _OfficeViewerPageState extends State<OfficeViewerPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    if (kIsWeb || widget.file.localPath == null) {
        setState(() {
             _errorMessage = "Cannot view this file type offline in this environment.";
             _isLoading = false;
        });
        return;
    }

    final String path = widget.file.localPath!;
    final String url = Uri.file(path).toString();

    // Android WebView does NOT support file:// for office docs natively rendering them.
    // iOS WebView DOES render Office docs natively.
    if (Platform.isAndroid) {
        setState(() {
             _errorMessage = "Android does not support native in-app viewing of Office documents without external apps. Please convert to PDF.";
             _isLoading = false;
        });
        return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
             if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
             if (mounted) setState(() => _errorMessage = "Error loading file: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
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
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                       const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                       const SizedBox(height: 16),
                       Text(
                         _errorMessage!,
                         textAlign: TextAlign.center,
                         style: const TextStyle(fontSize: 16),
                       ),
                   ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
