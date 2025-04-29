import 'package:flutter/material.dart';
import '../../services/auth/google_auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleAuthService _authService = GoogleAuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('LoginScreen: initState called');
    _checkIfAlreadyLoggedIn();
  }

  Future<void> _checkIfAlreadyLoggedIn() async {
    print('LoginScreen: Checking if already logged in');
    final isSignedIn = _authService.isSignedIn;
    print('LoginScreen: isSignedIn = $isSignedIn');

    if (isSignedIn) {
      print('LoginScreen: User is already signed in, navigating to home');
      _navigateToHome();
    } else {
      print('LoginScreen: User is not signed in');
    }
  }

  Future<void> _signInWithGoogle() async {
    print('LoginScreen: Starting Google sign-in');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('LoginScreen: Calling signInWithGoogle()');
      final userCredential = await _authService.signInWithGoogle();
      print('LoginScreen: Sign-in result: ${userCredential != null ? 'success' : 'cancelled'}');

      if (userCredential != null && mounted) {
        print('LoginScreen: Sign-in successful, navigating to home');
        _navigateToHome();
      } else if (mounted) {
        print('LoginScreen: Sign-in cancelled by user');
        setState(() {
          _errorMessage = 'Sign in cancelled';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('LoginScreen: Error during sign-in: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error signing in: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      size: 80,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App name
                  const Text(
                    'ReceiptRiser',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // App tagline
                  const Text(
                    'Scan, Organize, and Analyze Your Receipts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 64),

                  // Sign in button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                          height: 24,
                          width: 24,
                        ),
                        const SizedBox(width: 12),
                        _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(),
                              )
                            : const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Privacy policy
                  TextButton(
                    onPressed: () {
                      // Navigate to privacy policy
                    },
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
