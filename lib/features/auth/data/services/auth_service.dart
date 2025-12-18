import 'dart:async';

class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Mock database of users
  final Map<String, Map<String, String>> _users = {
    'demo@airdash.com': {'password': 'password123', 'name': 'Demo User'},
  };

  String? _currentUserEmail;

  String? get currentUserEmail => _currentUserEmail;

  String get currentUserName {
    if (_currentUserEmail == null || !_users.containsKey(_currentUserEmail))
      return 'Guest';
    return _users[_currentUserEmail]!['name'] ?? 'User';
  }

  // Simulate network delay
  Future<void> _simulateDelay() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  // Sign In
  Future<bool> signIn(String email, String password) async {
    await _simulateDelay();
    if (_users.containsKey(email) && _users[email]!['password'] == password) {
      _currentUserEmail = email;
      return true;
    }
    return false;
  }

  // Sign Up
  Future<bool> signUp(String name, String email, String password) async {
    await _simulateDelay();
    if (_users.containsKey(email)) {
      return false; // User already exists
    }
    _users[email] = {'password': password, 'name': name};
    return true;
  }

  // Sign Out
  Future<void> signOut() async {
    await _simulateDelay();
    _currentUserEmail = null;
  }

  // Reset Password (Mock)
  Future<bool> resetPassword(String email) async {
    await _simulateDelay();
    // In a real app, this would check if email exists and send a link
    // For mock, we'll just return true if the email format is valid
    return email.contains('@');
  }
}
