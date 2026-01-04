import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityMessage {
  final String id;
  final String communityId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  const CommunityMessage({
    required this.id,
    required this.communityId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory CommunityMessage.fromMap(Map<String, dynamic> map, String id) {
    return CommunityMessage(
      id: id,
      communityId: map['communityId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
