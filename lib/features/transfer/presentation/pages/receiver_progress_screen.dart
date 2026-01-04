import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:airdash/features/files/data/models/file_item.dart';
import 'package:airdash/features/files/data/repositories/offline_file_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:airdash/features/transfer/data/services/webrtc_service.dart';

class ReceiverProgressScreen extends StatefulWidget {
  final String transferId;
  final Map<String, dynamic> offer;
  final Map<String, dynamic> fileMetadata;
  final String senderName;

  const ReceiverProgressScreen({
    super.key, 
    required this.transferId, 
    required this.offer, 
    required this.fileMetadata,
    required this.senderName,
  });

  @override
  State<ReceiverProgressScreen> createState() => _ReceiverProgressScreenState();
}

class _ReceiverProgressScreenState extends State<ReceiverProgressScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final OfflineFileService _fileService = OfflineFileService();
  
  String _status = "Connecting...";
  double _progress = 0.0;
  bool _isComplete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startReception();
  }

  Future<void> _startReception() async {
      try {
           _webRTCService.onTxProgress = (progress) {
               if (mounted) {
                   setState(() {
                       _progress = progress;
                       _status = "Receiving: ${(progress * 100).toStringAsFixed(0)}%";
                   });
               }
           };

           _webRTCService.onConnectionState = (state) {
               if (mounted) {
                   setState(() {
                        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
                             _status = "Connected (P2P). Waiting for data...";
                        } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
                             _status = "Disconnected";
                        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
                             _status = "Connection Failed";
                             _error = "P2P Connection Failed";
                        } else if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
                             _status = "Checking connection...";
                        }
                   });
               }
           };

           _webRTCService.onFileReceived = (Uint8List fileData, Map<String, dynamic> metadata) async {
               if (mounted) {
                   setState(() => _status = "Saving file...");
               }
               
               try {
                   // Save to disk
                   await _fileService.saveReceivedFile(
                       fileData, 
                       widget.fileMetadata['name'] ?? 'received_file', 
                       widget.fileMetadata['size'] ?? '0 B',
                       widget.fileMetadata['type'] ?? 'other'
                   );

                   if (mounted) {
                       setState(() {
                           _status = "Received & Saved!";
                           _progress = 1.0;
                           _isComplete = true;
                       });
                   }
               } catch (e) {
                   if (mounted) setState(() => _error = "Error saving: $e");
               }
           };

           await _webRTCService.acceptConnection(widget.transferId, widget.offer);
           
           await _webRTCService.acceptConnection(widget.transferId, widget.offer);
           
           if (mounted) setState(() => _status = "Initializing connection...");

      } catch (e) {
          if (mounted) {
              setState(() {
                  _error = e.toString();
                  _status = "Connection Failed";
              });
          }
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
      appBar: AppBar(title: const Text("Receiving File")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                 Text("From: ${widget.senderName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 10),
                 Text("File: ${widget.fileMetadata['name']}"),
                 const SizedBox(height: 30),
                 
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
