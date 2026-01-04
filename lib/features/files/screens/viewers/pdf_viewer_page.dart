import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../models/file_item.dart';
import '../file_detail_view.dart';

class PdfViewerPage extends StatefulWidget {
  final FileItem file;

  const PdfViewerPage({super.key, required this.file});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
     if (kIsWeb || widget.file.localPath == null) {
         return Scaffold(
             appBar: AppBar(title: Text(widget.file.name)),
             body: const Center(child: Text("PDF viewing only supported on mobile/desktop with local file path.")),
         );
     }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
            if (pages != null)
                Center(child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text("${currentPage! + 1} / $pages"),
                )),
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
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.file.localPath,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: false,
            onRender: (_pages) {
              setState(() {
                pages = _pages;
                isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                errorMessage = error.toString();
              });
              print(error.toString());
            },
            onPageError: (page, error) {
              setState(() {
                errorMessage = '$page: ${error.toString()}';
              });
              print('$page: ${error.toString()}');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // _controller.complete(pdfViewController);
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                currentPage = page;
              });
            },
          ),
          errorMessage.isEmpty
              ? !isReady
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Container()
              : Center(
                  child: Text(errorMessage),
                )
        ],
      ),
    );
  }
}
