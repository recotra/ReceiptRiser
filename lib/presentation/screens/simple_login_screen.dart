import 'package:flutter/material.dart';
import '../../services/auth/mock_auth_service.dart';
import 'home_screen.dart';

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key});

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final MockAuthService _mockAuthService = MockAuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String _status = 'Ready to sign in';

  @override
  void initState() {
    super.initState();
    print('SimpleLoginScreen: initState called');
  }

  // Google sign-in removed to simplify the app

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _signInWithMock() async {
    print('SimpleLoginScreen: Starting mock sign-in');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _status = 'Signing in with mock account...';
    });

    try {
      print('SimpleLoginScreen: Calling mock signIn()');
      final userInfo = await _mockAuthService.signIn();
      print('SimpleLoginScreen: Mock sign-in successful');

      setState(() {
        _status = 'Mock sign-in successful! Navigating...';
      });

      print('SimpleLoginScreen: Navigating to home');
      _navigateToHome();
    } catch (e) {
      print('SimpleLoginScreen: Error during mock sign-in: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error signing in: $e';
          _isLoading = false;
          _status = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Status: $_status',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),

              // Google sign-in button removed

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithMock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Sign in with Mock Account'),
                ),
              ),

              const SizedBox(height: 16),

              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
