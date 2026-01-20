import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
          'role': 'user', 
          'accountStatus': 'active', 
          'plan': 'free', 
          'storageLimit': 5368709120, 
          'storageUsed': 0,
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
    
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
    
      if (cred.user != null) {

        await cred.user!.reload();
        
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


  // Sign In with Google
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return; // User canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore
        final DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Create new user document
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? 'Google User',
            'email': user.email ?? '',
            'phoneNumber': user.phoneNumber ?? '',
            'role': 'user',
            'accountStatus': 'active',
            'isVerified': true, 
            'photoUrl': user.photoURL,
            'plan': 'free',
            'storageLimit': 5368709120, // 5GB
            'storageUsed': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
             // Check blocked status
             final data = userDoc.data() as Map<String, dynamic>;
             if (data['accountStatus'] == 'blocked') {
                await signOut();
                throw FirebaseAuthException(code: 'user-blocked', message: 'Your account has been blocked.');
             }
        }
      }
    } on FirebaseAuthException catch (e) {
      print("Google Sign In Error: ${e.message}");
      if (e.code == 'user-blocked') rethrow;
      throw Exception(e.message);
    } catch (e) {
      print("General Google Sign In Error: $e");
      throw Exception('Google Login Failed: $e');
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
      
      if (bytes.length > 5 * 1024 * 1024) {
         throw Exception("Image too large (Max 5MB). Please choose a smaller one.");
      }
      String base64Image = base64Encode(bytes);
      
      await _firestore.collection('users').doc(uid).update({
        'photoBase64': base64Image,
        'photoUrl': null,
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

  Stream<DocumentSnapshot> getUserStream() {
    if (currentUser == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUser!.uid).snapshots();
  }
}
