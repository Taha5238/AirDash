import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get Current User
  User? get currentUser => _auth.currentUser;

  String? get currentUserEmail => _auth.currentUser?.email;
  
  String get currentUserName => _auth.currentUser?.displayName ?? 'User';
  
  String? get currentUserUid => _auth.currentUser?.uid;

  // Sign In
  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      print("Sign In Error: ${e.message}");
      return false;
    } catch (e) {
      print("General Sign In Error: $e");
      return false;
    }
  }

  // Sign Up
  Future<bool> signUp(String name, String email, String password) async {
    try {
      // Create User
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Update Name
      if (cred.user != null) {
        await cred.user!.updateDisplayName(name);
        await cred.user!.reload(); // Refresh to get updated name
      }
      
      return true;
    } on FirebaseAuthException catch (e) {
      print("Sign Up Error: ${e.message}");
      return false;
    } catch (e) {
      print("General Sign Up Error: $e");
      return false;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset Password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print("Reset Password Error: $e");
      return false;
    }
  }
}
