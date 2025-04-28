import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/sync/sync_service.dart';
import '../../services/auth/google_auth_service.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final SyncService _syncService = SyncService();
  final GoogleAuthService _authService = GoogleAuthService();
  
  bool _isLoading = true;
  bool _autoSyncEnabled = false;
  DateTime? _lastSyncTime;
  String? _spreadsheetUrl;
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _syncService.initialize();
      
      final settings = await _syncService.getSyncSettings();
      
      setState(() {
        _autoSyncEnabled = settings['autoSyncEnabled'] as bool;
        _lastSyncTime = settings['lastSyncTime'] as DateTime?;
        _spreadsheetUrl = settings['spreadsheetUrl'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }
  
  Future<void> _toggleAutoSync(bool value) async {
    setState(() {
      _autoSyncEnabled = value;
    });
    
    try {
      await _syncService.updateSyncSettings(autoSyncEnabled: value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating settings: $e')),
        );
      }
    }
  }
  
  Future<void> _syncNow() async {
    if (_isSyncing) {
      return;
    }
    
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatus = 'Starting sync...';
    });
    
    try {
      // Start sync
      final success = await _syncService.syncReceipts();
      
      // Update UI
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync completed successfully')),
          );
          
          // Reload settings to get updated last sync time
          await _loadSettings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: ${_syncService.syncStatus}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sync: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
  
  Future<void> _clearSyncData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Sync Data'),
        content: const Text(
          'Are you sure you want to clear all sync data? '
          'This will not delete your receipts, but will remove the connection '
          'to Google Sheets and Drive.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirmed != true) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _syncService.clearSyncData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync data cleared')),
        );
        
        // Reload settings
        await _loadSettings();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing sync data: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Google account info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Google Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildGoogleAccountInfo(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sync settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sync Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Auto Sync'),
                            subtitle: const Text(
                              'Automatically sync receipts when changes are made'
                            ),
                            value: _autoSyncEnabled,
                            onChanged: _toggleAutoSync,
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text('Last Sync'),
                            subtitle: Text(
                              _lastSyncTime != null
                                  ? DateFormat.yMMMd().add_jm().format(_lastSyncTime!)
                                  : 'Never',
                            ),
                          ),
                          if (_spreadsheetUrl != null) ...[
                            const Divider(),
                            ListTile(
                              title: const Text('Google Sheets'),
                              subtitle: Text(
                                _spreadsheetUrl!,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.open_in_new),
                              onTap: () {
                                // Open spreadsheet URL
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sync actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sync Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isSyncing) ...[
                            const Text('Syncing...'),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: _syncProgress),
                            const SizedBox(height: 8),
                            Text(_syncStatus),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isSyncing ? null : _syncNow,
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync Now'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isSyncing ? null : _clearSyncData,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Clear Sync Data'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildGoogleAccountInfo() {
    final userInfo = _authService.getUserInfo();
    
    if (userInfo.isEmpty) {
      return const Text('Not signed in');
    }
    
    return Row(
      children: [
        if (userInfo['photoURL'] != null)
          CircleAvatar(
            backgroundImage: NetworkImage(userInfo['photoURL']),
            radius: 20,
          )
        else
          const CircleAvatar(
            child: Icon(Icons.person),
            radius: 20,
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userInfo['displayName'] ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                userInfo['email'] ?? '',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            try {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error signing out: $e')),
                );
              }
            }
          },
          tooltip: 'Sign Out',
        ),
      ],
    );
  }
}
