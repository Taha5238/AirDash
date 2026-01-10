import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:airdash/features/files/models/file_item.dart';
import 'signaling_service.dart';

typedef OnDataChannelState = void Function(RTCDataChannelState state);
typedef OnFileReceived = void Function(Uint8List fileData, Map<String, dynamic> metadata);
typedef OnProgress = void Function(double progress);
typedef OnConnectionState = void Function(RTCIceConnectionState state);

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final SignalingService _signaling = SignalingService();
  
  OnDataChannelState? onDataChannelState;
  OnFileReceived? onFileReceived;
  OnProgress? onTxProgress;
  OnConnectionState? onConnectionState;
  
  // Buffers for receiving
  List<int> _incomingBuffer = [];
  int _receivedBytes = 0;
  int _expectedSize = 0;
  Map<String, dynamic>? _incomingFileMetadata;

  final Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  // --- SENDER: Start Connection ---
  Future<String> startConnection(String senderId, String receiverId, FileItem file) async {
    print("WebRTC: Starting Connection (Sender)...");
    _peerConnection = await createPeerConnection(_config);
    print("WebRTC: PeerConnection Created");
    
    // Create Data Channel
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..id = 1
      ..ordered = true // Reliable delivery
      ..maxRetransmits = -1; // Unlimited
      
    print("WebRTC: Creating Data Channel 'fileTransfer'...");
    _dataChannel = await _peerConnection!.createDataChannel("fileTransfer", dataChannelDict);
    _setupDataChannel(_dataChannel!);

    _peerConnection!.onIceConnectionState = (state) {
        print("WebRTC: ICE State Change: $state");
        if (onConnectionState != null) onConnectionState!(state);
    };

    // Create Offer
    print("WebRTC: Creating Offer...");
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Send to Firestore
    print("WebRTC: Sending Offer to Firestore...");
    final transferId = await _signaling.createOffer(
        senderId, 
        receiverId, 
        offer.toMap(), 
        file.toMap(), // Send metadata for preview
    );
    print("WebRTC: Offer Sent. Transfer ID: $transferId");

    // Listen for ICE Candidates
    _peerConnection!.onIceCandidate = (candidate) {
        print("WebRTC: Generated Local Candidate: ${candidate.candidate}");
        _signaling.addCandidate(transferId, candidate.toMap(), 'sender');
    };
    
    // Listen for Answer
    print("WebRTC: Listening for Answer...");
    _signaling.getTransferStream(transferId).listen((snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data() as Map<String, dynamic>;
        
        if (data['status'] == 'accepted' && data['answer'] != null && _peerConnection!.signalingState != RTCSignalingState.RTCSignalingStateStable) {
            print("WebRTC: Received Answer! Setting Remote Description...");
            final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
            await _peerConnection!.setRemoteDescription(answer);
        }
    });
     
    // Listen for REMOTE candidates
    _signaling.getCandidatesStream(transferId).listen((snapshot) {
        for (var change in snapshot.docChanges) {
             if (change.type == DocumentChangeType.added) {
                 final data = change.doc.data() as Map<String, dynamic>;
                 if (data['type'] == 'receiver') {
                      print("WebRTC: Added Remote Candidate (from Receiver): ${data['candidate']['candidate']}");
                      final candidate = RTCIceCandidate(
                          data['candidate']['candidate'], 
                          data['candidate']['sdpMid'], 
                          data['candidate']['sdpMLineIndex']
                      );
                      _peerConnection!.addCandidate(candidate);
                 }
             }
        }
    });

    return transferId;
  }

  // --- RECEIVER: Accept Connection ---
  Future<void> acceptConnection(String transferId, Map<String, dynamic> offerMap) async {
      print("WebRTC: Accepting connection for $transferId");
      _peerConnection = await createPeerConnection(_config);
      print("WebRTC: PeerConnection created");
      
      _peerConnection!.onDataChannel = (channel) {
          print("WebRTC: DataChannel received: ${channel.label}");
          _dataChannel = channel;
          _setupDataChannel(channel);
      };

      _peerConnection!.onIceConnectionState = (state) {
          print("WebRTC: ICE State Change: $state");
          if (onConnectionState != null) onConnectionState!(state);
      };

      _peerConnection!.onIceCandidate = (candidate) {
           print("WebRTC: Generated Local Candidate: ${candidate.candidate}");
           _signaling.addCandidate(transferId, candidate.toMap(), 'receiver');
      };

      // Set Remote Description (Offer)
      print("WebRTC: Setting Remote Description...");
      final offer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);
      await _peerConnection!.setRemoteDescription(offer);
      
      // Create Answer
      print("WebRTC: Creating Answer...");
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      // Send Answer
      print("WebRTC: Sending Answer...");
      await _signaling.createAnswer(transferId, answer.toMap());
      
      // Listen for REMOTE candidates (from sender)
       _signaling.getCandidatesStream(transferId).listen((snapshot) {
        for (var change in snapshot.docChanges) {
             if (change.type == DocumentChangeType.added) {
                 final data = change.doc.data() as Map<String, dynamic>;
                 if (data['type'] == 'sender') {
                      print("WebRTC: Added Remote Candidate: ${data['candidate']['candidate']}");
                      final candidate = RTCIceCandidate(
                          data['candidate']['candidate'], 
                          data['candidate']['sdpMid'], 
                          data['candidate']['sdpMLineIndex']
                      );
                      _peerConnection!.addCandidate(candidate);
                 }
             }
        }
    });
  }

  void _setupDataChannel(RTCDataChannel channel) {
      channel.onDataChannelState = (state) {
          if (onDataChannelState != null) onDataChannelState!(state);
      };
      
      channel.onMessage = (RTCDataChannelMessage message) {
          if (message.isBinary) {
               _handleIncomingChunk(message.binary);
          } else {
               // Handle text messages (e.g., metadata specifically sent over channel if needed)
               if (message.text.startsWith("METADATA:")) {
                   final jsonStr = message.text.substring(9);
                   _incomingFileMetadata = json.decode(jsonStr);
                    if (_incomingFileMetadata != null) {
                        if (_incomingFileMetadata!.containsKey('sizeBytes')) {
                             _expectedSize = _incomingFileMetadata!['sizeBytes'];
                        } else {
                             // Fallback (Risk of error)
                             _expectedSize = int.parse(_incomingFileMetadata!['size'].replaceAll(RegExp(r'[^0-9]'), '')); 
                        }
                        
                        _receivedBytes = 0;
                        _incomingBuffer = [];
                    }
               }
          }
      };
  }

  void _handleIncomingChunk(Uint8List chunk) {
      _incomingBuffer.addAll(chunk);
      _receivedBytes += chunk.length;
      
      if (_expectedSize > 0 && onTxProgress != null) {
           onTxProgress!(_receivedBytes / _expectedSize);
      }
      
      // We need a reliable end-of-file signal. WebRTC doesn't guarantee stream end.
      // Sender should send a text message "EOF" or we check byte count.
      if (_receivedBytes >= _expectedSize && _expectedSize > 0) {
           _finalizeReception();
      }
  }

  void _finalizeReception() {
       if (_incomingFileMetadata != null && onFileReceived != null) {
           onFileReceived!(Uint8List.fromList(_incomingBuffer), _incomingFileMetadata!);
       }
  }

  // --- Send File ---
  Future<void> sendFile(Uint8List fileData, Map<String, dynamic> metadata) async {
       if (_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
           throw Exception("Connection not open");
       }
       
       // 1. Send Metadata Header
       // Add exact byte size to metadata for receiver
       metadata['sizeBytes'] = fileData.length;
       final metaMsg = "METADATA:${json.encode(metadata)}";
       await _dataChannel!.send(RTCDataChannelMessage(metaMsg));
       
       // 2. Chunk and Send
       const int chunkSize = 16 * 1024; // 16KB safe chunk
       int offset = 0;
       
       while (offset < fileData.length) {
            int end = offset + chunkSize;
            if (end > fileData.length) end = fileData.length;
            
            final chunk = fileData.sublist(offset, end);
            await _dataChannel!.send(RTCDataChannelMessage.fromBinary(chunk));
            
            offset = end;
            
            if (onTxProgress != null) {
                 onTxProgress!(offset / fileData.length);
            }
            
            // Small throttle to prevent buffer overflow? 
            await Future.delayed(const Duration(milliseconds: 1)); 
       }
  }
  
  void dispose() {
      _dataChannel?.close();
      _peerConnection?.close();
  }
}
