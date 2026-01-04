import 'dart:io';
import 'dart:convert';
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
      // 0. Check if Registration is Enabled
      final configDoc = await _firestore.collection('config').doc('app_settings').get();
      if (configDoc.exists) {
        final bool isEnabled = configDoc.data()?['registrationEnabled'] ?? true; // Default true
        if (!isEnabled) {
           throw FirebaseAuthException(
             code: 'registration-disabled', 
             message: 'New user registrations are currently disabled by the administrator.'
           );
        }
      }
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
        // Force refresh of Access Token and User Metadata (like emailVerified)
        await cred.user!.reload();
        // Sync Verification Status
        if (cred.user!.emailVerified) {
           await _firestore.collection('users').doc(cred.user!.uid).update({'isVerified': true});
        }
        
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
              'isVerified': cred.user!.emailVerified,
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
  // Update Profile Picture (Base64 Strategy)
  Future<void> updateProfilePicture(File imageFile) async {
    try {
      if (currentUser == null) return;
      
      final String uid = currentUser!.uid;
      
      // 1. Read Bytes
      final bytes = await imageFile.readAsBytes();
      
      // 2. Simple validation (Avoid huge files)
      if (bytes.length > 5 * 1024 * 1024) {
         throw Exception("Image too large (Max 5MB). Please choose a smaller one.");
      }
      
      // 3. Convert to Base64
      // NOTE: In a production app, we should resize/compress this image client-side 
      // to avoid bloating Firestore. For now, we assume reasonable input or add simple check.
      String base64Image = base64Encode(bytes);
      
      // 4. Update Firestore
      await _firestore.collection('users').doc(uid).update({
        'photoBase64': base64Image,
        'photoUrl': null, // Clear old URL so UI prefers Base64
      });
      
      // 5. Update Auth (Cannot set Base64 as photoURL usually, so we leave it or set a placeholder)
      // await currentUser!.updatePhotoURL(null); 
      
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
