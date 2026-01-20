import 'package:cloud_firestore/cloud_firestore.dart';

class SignalingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create an Offer (Sender)
  Future<String> createOffer(String senderId, String receiverId, Map<String, dynamic> offerInit, Map<String, dynamic> fileMetadata) async {
    final docRef = _db.collection('transfer_signals').doc();
    
    await docRef.set({
      'type': 'offer',
      'senderId': senderId,
      'receiverId': receiverId,
      'offer': offerInit,
      'fileMetadata': fileMetadata,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending', 
    });

    return docRef.id;
  }

  // Create an Answer (Receiver)
  Future<void> createAnswer(String transferId, Map<String, dynamic> answerInit) async {
    await _db.collection('transfer_signals').doc(transferId).update({
      'type': 'answer', 
      'answer': answerInit,
      'status': 'accepted',
    });
  }

  // Add ICE Candidate
  Future<void> addCandidate(String transferId, Map<String, dynamic> candidate, String type) async {
    
    await _db.collection('transfer_signals').doc(transferId).collection('candidates').add({
       'candidate': candidate,
       'type': type,
       'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Listen for signals meant for a user
  Stream<QuerySnapshot> getIncomingSignals(String userId) {
      return _db.collection('transfer_signals')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending') 
          .snapshots();
  }

  // Listen to a specific transfer document (for Sender to wait for Answer)
  Stream<DocumentSnapshot> getTransferStream(String transferId) {
      return _db.collection('transfer_signals').doc(transferId).snapshots();
  }

  // Listen to candidates
  Stream<QuerySnapshot> getCandidatesStream(String transferId) {
      return _db.collection('transfer_signals').doc(transferId).collection('candidates').snapshots();
  }
  
  // Cleanup
  Future<void> deleteTransfer(String transferId) async {
      await _db.collection('transfer_signals').doc(transferId).delete();
  }
}
