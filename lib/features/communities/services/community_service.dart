import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/services/auth_service.dart';
import '../models/community_model.dart';
import '../models/community_message.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  // Create a new community
  Future<void> createCommunity({
    required String name,
    required String description,
    required bool isPublic,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    print("DEBUG: createCommunity called. Name: $name, User: ${user?.uid}");
    final docRef = _firestore.collection('communities').doc();
    print("DEBUG: Generated ID: ${docRef.id}");
    final community = Community(
      id: docRef.id,
      name: name,
      description: description,
      memberRoles: {user.uid: 'admin'}, // Creator is admin
      pendingMemberIds: [],
      createdAt: DateTime.now(),
      isPublic: isPublic,
      createdBy: user.uid,
    );

    print("DEBUG: Saving community to Firestore...");
    try {
       await docRef.set(community.toMap());
       print("DEBUG: Saved successfully.");
    } catch (e) {
       print("DEBUG: Firestore Set Error: $e");
       rethrow;
    }
  }

  // Get all communities (Joined + Public)
  Stream<List<Community>> getCommunities() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    
    return _firestore.collection('communities').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Community.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Join a community
  Future<void> joinCommunity(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final communityRef = _firestore.collection('communities').doc(communityId);
    final communityDoc = await communityRef.get();
    
    if (!communityDoc.exists) return;
    
    final community = Community.fromMap(communityDoc.data()!, communityDoc.id);

    if (community.isPublic) {
       // Auto-join as viewer if public
       await communityRef.update({
         'memberRoles.${user.uid}': 'viewer' 
       });
    } else {
       // Request to join
       if (!community.pendingMemberIds.contains(user.uid)) {
          await communityRef.update({
            'pendingMemberIds': FieldValue.arrayUnion([user.uid])
          });
       }
    }
  }

  // Admin: Approve Member
  Future<void> approveMember(String communityId, String userId) async {
     await _firestore.collection('communities').doc(communityId).update({
       'pendingMemberIds': FieldValue.arrayRemove([userId]),
       'memberRoles.$userId': 'viewer' // Default to viewer
     });
  }

  // Admin: Reject Member
  Future<void> rejectMember(String communityId, String userId) async {
     await _firestore.collection('communities').doc(communityId).update({
       'pendingMemberIds': FieldValue.arrayRemove([userId])
     });
  }

  // Admin: Update Role
  Future<void> updateMemberRole(String communityId, String userId, String newRole) async {
    // Validate role
    if (!['admin', 'editor', 'viewer'].contains(newRole)) return;

    await _firestore.collection('communities').doc(communityId).update({
      'memberRoles.$userId': newRole
    });
  }

  // Chat: Send Message
  Future<void> sendMessage(String communityId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final userName = _auth.currentUserName ?? "Unknown";

    final docRef = _firestore.collection('communities').doc(communityId).collection('messages').doc();
    
    final message = CommunityMessage(
      id: docRef.id,
      communityId: communityId,
      senderId: user.uid,
      senderName: userName,
      text: text,
      timestamp: DateTime.now(),
    );

    await docRef.set(message.toMap());
  }

  Future<void> deleteCommunity(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore.collection('communities').doc(communityId).delete();
  }

  // Remove Member (Kick)
  Future<void> removeMember(String communityId, String userId) async {
    await _firestore.collection('communities').doc(communityId).update({
      'memberRoles.$userId': FieldValue.delete(), 
    });
  }

  Stream<List<CommunityMessage>> getMessages(String communityId) {
    return _firestore.collection('communities')
        .doc(communityId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
           return snapshot.docs.map((doc) => CommunityMessage.fromMap(doc.data(), doc.id)).toList();
        });
  }
}
