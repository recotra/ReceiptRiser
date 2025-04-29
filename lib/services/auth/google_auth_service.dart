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
      print('GoogleAuthService: Starting Google sign-in flow');

      // Trigger the authentication flow
      print('GoogleAuthService: Calling _googleSignIn.signIn()');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      print('GoogleAuthService: _googleSignIn.signIn() returned: ${googleUser != null ? 'account' : 'null'}');

      if (googleUser == null) {
        // User canceled the sign-in flow
        print('GoogleAuthService: User cancelled sign-in');
        return null;
      }

      // Obtain the auth details from the request
      print('GoogleAuthService: Getting authentication details');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('GoogleAuthService: Got authentication details');

      // Create a new credential
      print('GoogleAuthService: Creating Firebase credential');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      print('GoogleAuthService: Signing in to Firebase');
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      print('GoogleAuthService: Firebase sign-in successful');

      return userCredential;
    } catch (e) {
      print('GoogleAuthService: Error signing in with Google: $e');
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
