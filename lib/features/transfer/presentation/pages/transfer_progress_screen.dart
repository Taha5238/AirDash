import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:airdash/core/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:airdash/features/files/data/models/file_item.dart';
import 'package:airdash/features/auth/data/services/auth_service.dart';
import 'package:airdash/features/transfer/data/services/webrtc_service.dart';

class TransferProgressScreen extends StatefulWidget {
  final FileItem file;
  final String receiverId;

  const TransferProgressScreen({super.key, required this.file, required this.receiverId});

  @override
  State<TransferProgressScreen> createState() => _TransferProgressScreenState();
}

class _TransferProgressScreenState extends State<TransferProgressScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  String _status = "Initializing...";
  double _progress = 0.0;
  bool _isComplete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTransfer();
  }

  Future<void> _startTransfer() async {
     try {
         setState(() => _status = "Waiting for connection...");
         
         final senderId = AuthService().currentUserUid;
         if (senderId == null) throw Exception("Not logged in");

         _webRTCService.onTxProgress = (progress) {
             if (mounted) {
                 setState(() {
                     _progress = progress;
                     _status = "Sending: ${(progress * 100).toStringAsFixed(0)}%";
                 });
             }
         };
         
         _webRTCService.onDataChannelState = (state) {
            print("Data Channel State: $state");
            if (state == RTCDataChannelState.RTCDataChannelOpen) {
                 _sendData();
            }
         };

         await _webRTCService.startConnection(senderId, widget.receiverId, widget.file);

     } catch (e) {
         setState(() {
             _error = e.toString();
             _status = "Failed";
         });
     }
  }

  Future<void> _sendData() async {
      if (widget.file.content == null && widget.file.localPath == null) {
          setState(() {
               _error = "File content unavailable";
               _status = "Failed";
          });
          return;
      }

      setState(() => _status = "Sending data...");
      try {
          // Load data
          Uint8List bytes;
          if (widget.file.content != null) {
              bytes = widget.file.content!;
          } else {
              // Read from file
              if (kIsWeb) {
                  throw Exception("Web file reading not fully implemented yet. Ensure content is passed.");
              } else {
                  if (widget.file.localPath != null) {
                       bytes = await FileUtils.readBytes(widget.file.localPath!);
                   } else {
                       throw Exception("No content or path available to send.");
                   }
              }
          }
          
          await _webRTCService.sendFile(bytes, widget.file.toMap());
          
          setState(() {
              _status = "Sent Successfully!";
              _progress = 1.0;
              _isComplete = true;
          });
          
      } catch (e) {
          setState(() {
             _error = e.toString();
             _status = "Failed to send";
          });
      }
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sending File")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                 if (_error != null)
                    Icon(Icons.error, size: 60, color: Colors.red)
                 else if (_isComplete)
                    Icon(Icons.check_circle, size: 60, color: Colors.green)
                 else 
                    const CircularProgressIndicator(),
                 
                 const SizedBox(height: 20),
                 
                 Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 
                 const SizedBox(height: 10),
                 if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                 
                 if (!_isComplete && _error == null) ...[
                     const SizedBox(height: 20),
                     LinearProgressIndicator(value: _progress),
                 ],
                 
                 const SizedBox(height: 40),
                 if (_isComplete || _error != null)
                    FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
                 else
                    OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
             ],
          ),
        ),
      ),
    );
  }
}
