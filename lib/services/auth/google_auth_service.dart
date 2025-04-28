import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

class GoogleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets',
    ],
  );

  // Current user
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isSignedIn => currentUser != null;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Get Google auth client for API access
  Future<auth.AuthClient?> getGoogleAuthClient() async {
    try {
      if (!await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signIn();
      }

      return await _googleSignIn.authenticatedClient();
    } catch (e) {
      print('Error getting Google auth client: $e');
      return null;
    }
  }

  // Get user info
  Map<String, dynamic> getUserInfo() {
    final user = currentUser;
    if (user == null) {
      return {};
    }

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
    };
  }

  // Check if user has granted required scopes
  Future<bool> hasRequiredScopes() async {
    if (!await _googleSignIn.isSignedIn()) {
      return false;
    }

    // Note: We can't directly check scopes in the current version of google_sign_in
    // So we'll just return true if the user is signed in
    return true;
  }

  // Request additional scopes if needed
  Future<bool> requestAdditionalScopes() async {
    if (!await _googleSignIn.isSignedIn()) {
      return false;
    }

    try {
      final account = await _googleSignIn.requestScopes(_googleSignIn.scopes);
      return account != null;
    } catch (e) {
      print('Error requesting additional scopes: $e');
      return false;
    }
  }
}
