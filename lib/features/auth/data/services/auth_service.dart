import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get Current User
  User? get currentUser => _auth.currentUser;

  String? get currentUserEmail => _auth.currentUser?.email;
  
  String get currentUserName => _auth.currentUser?.displayName ?? 'User';
  
  String? get currentUserUid => _auth.currentUser?.uid;

  // Sign Up with Email & Password
  Future<void> signUp(String name, String email, String password, String phoneNumber) async {
    try {
      // 1. Create Auth User
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // 2. Update Display Name
      if (cred.user != null) {
        await cred.user!.updateDisplayName(name);
        await cred.user!.reload(); 
        
        // 2b. Send Verification Email
        if (!cred.user!.emailVerified) {
           await cred.user!.sendEmailVerification();
        }

        // 3. Create User Document in Firestore
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'name': name,
          'email': email,
          'phoneNumber': phoneNumber,
          'role': 'user', // Default role
          'accountStatus': 'active', // Default status
          'plan': 'free', // New: Plan field
          'storageLimit': 5368709120, // New: 5GB in bytes
          'storageUsed': 0, // Initialize storage used
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      print("Sign Up Error: ${e.message}");
      rethrow;
    } catch (e) {
      print("General Sign Up Error: $e");
      rethrow;
    }
  }

  // Sign In
  Future<void> signIn(String email, String password) async {
    try {
      // 1. Authenticate with Firebase Auth
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // 2. Check Firestore for Role and Status
      if (cred.user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(cred.user!.uid).get();
        
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          
          if (data['accountStatus'] == 'blocked') {
            await signOut(); // Prevent access
            throw FirebaseAuthException(code: 'user-blocked', message: 'Your account has been blocked.');
          }
        } else {
           // Self-healing: Create missing user document if it doesn't exist
           // This handles legacy users or cases where signup failed halfway
           await _firestore.collection('users').doc(cred.user!.uid).set({
              'uid': cred.user!.uid,
              'name': cred.user!.displayName ?? 'User',
              'email': email,
              'role': 'user', 
              'accountStatus': 'active',
              'createdAt': FieldValue.serverTimestamp(),
           });
        }
      }
    } on FirebaseAuthException catch (e) {
      print("Sign In Error: ${e.message}");
      if (e.code == 'user-blocked') rethrow; 
      rethrow;
    } catch (e) {
      print("General Sign In Error: $e");
      throw Exception('Login Failed: $e');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Get User Role
  Future<String?> getUserRole() async {
    if (currentUser == null) return null;
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['role'] as String?;
      }
    } catch (e) {
      print("Error fetching role: $e");
    }
    return null;
  }
  // Update Profile Picture
  Future<void> updateProfilePicture(File imageFile) async {
    try {
      if (currentUser == null) return;
      
      final String uid = currentUser!.uid;
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');
          
      // Upload
      await storageRef.putFile(imageFile);
      
      // Get URL
      final String downloadUrl = await storageRef.getDownloadURL();
      
      // Update Auth Profile
      await currentUser!.updatePhotoURL(downloadUrl);
      
      // Update Firestore Profile (Redundancy)
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': downloadUrl,
      });
      
    } catch (e) {
      print("Error uploading profile picture: $e");
      rethrow;
    }
  }

  // Sync Verification Status to Firestore
  Future<void> syncVerificationStatus() async {
    if (currentUser == null) return;
    try {
      if (currentUser!.emailVerified) {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'isVerified': true,
        });
      }
    } catch (e) {
      print("Error syncing verification status: $e");
      // Don't rethrow, strictly optional sync
    }
  }

  // Update Phone Number

  // Update Phone Number
  Future<void> updatePhoneNumber(String newNumber) async {
    if (currentUser == null) return;
    try {
       await _firestore.collection('users').doc(currentUser!.uid).update({
         'phoneNumber': newNumber,
       });
    } catch (e) {
      print("Error updating phone number: $e");
      rethrow;
    }
  }

  // Get User Stream (for real-time profile updates)
  Stream<DocumentSnapshot> getUserStream() {
    if (currentUser == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUser!.uid).snapshots();
  }
}
