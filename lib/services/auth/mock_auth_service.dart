import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class MockAuthService {
  bool _isSignedIn = false;
  final _mockUser = {
    'uid': 'mock-user-123',
    'email': 'user@example.com',
    'displayName': 'Mock User',
    'photoURL': null,
  };
  
  // Current user
  bool get isSignedIn => _isSignedIn;
  
  // Sign in
  Future<Map<String, dynamic>> signIn() async {
    print('MockAuthService: Starting mock sign-in');
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    _isSignedIn = true;
    print('MockAuthService: Mock sign-in successful');
    
    return _mockUser;
  }
  
  // Sign out
  Future<void> signOut() async {
    print('MockAuthService: Starting mock sign-out');
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    _isSignedIn = false;
    print('MockAuthService: Mock sign-out successful');
  }
  
  // Get user info
  Map<String, dynamic> getUserInfo() {
    if (!_isSignedIn) {
      return {};
    }
    
    return _mockUser;
  }
}
