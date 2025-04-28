import 'package:flutter/material.dart';
import '../../features/receipt_scanning/ml/ml_receipt_parser.dart';
import '../../services/auth/google_auth_service.dart';
import 'model_training_screen.dart';
import 'sync_settings_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final MLReceiptParser _mlParser = MLReceiptParser();
  final GoogleAuthService _authService = GoogleAuthService();
  bool _isDarkMode = false;
  bool _isNotificationsEnabled = true;
  String _currency = 'USD';

  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CNY'];

  @override
  void initState() {
    super.initState();
    _initializeParser();
    _checkAuthStatus();
  }

  Future<void> _initializeParser() async {
    await _mlParser.initialize();
  }

  Future<void> _checkAuthStatus() async {
    if (!_authService.isSignedIn) {
      // Redirect to login screen if not signed in
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _mlParser.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance section
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
            },
          ),
          const Divider(),

          // Notifications section
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive app notifications'),
            value: _isNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _isNotificationsEnabled = value;
              });
            },
          ),
          const Divider(),

          // Currency section
          _buildSectionHeader('Currency'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(
                labelText: 'Default Currency',
                border: OutlineInputBorder(),
              ),
              items: _currencies.map((String currency) {
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _currency = newValue;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Sync section
          _buildSectionHeader('Sync'),
          ListTile(
            title: const Text('Google Sync'),
            subtitle: const Text('Sync receipts with Google Sheets and Drive'),
            leading: const Icon(Icons.sync),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SyncSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // Advanced section
          _buildSectionHeader('Advanced'),
          ListTile(
            title: const Text('Model Training'),
            subtitle: const Text('Manage and train receipt parsing models'),
            leading: const Icon(Icons.model_training),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ModelTrainingScreen(
                    mlParser: _mlParser,
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Clear App Data'),
            subtitle: const Text('Delete all app data and reset settings'),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () {
              _showClearDataDialog();
            },
          ),
          const Divider(),

          // About section
          _buildSectionHeader('About'),
          ListTile(
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
            leading: const Icon(Icons.info_outline),
          ),
          ListTile(
            title: const Text('Terms of Service'),
            leading: const Icon(Icons.description),
            onTap: () {
              // Navigate to terms of service
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            onTap: () {
              // Navigate to privacy policy
            },
          ),
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error signing out: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear App Data'),
        content: const Text(
          'Are you sure you want to clear all app data? '
          'This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Clear app data
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App data cleared')),
              );
            },
            child: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
