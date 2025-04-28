import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../google/google_sheets_service.dart';
import '../google/google_drive_service.dart';
import '../auth/google_auth_service.dart';
import '../../data/repositories/receipt_repository_impl.dart';
import '../../domain/entities/receipt.dart';

class SyncService {
  final GoogleAuthService _authService;
  final GoogleSheetsService _sheetsService;
  final GoogleDriveService _driveService;
  final ReceiptRepositoryImpl _receiptRepository;
  
  // Sync status
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  DateTime? _lastSyncTime;
  
  // Sync preferences keys
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _spreadsheetIdKey = 'spreadsheet_id';
  static const String _folderIdKey = 'folder_id';
  static const String _autoSyncEnabledKey = 'auto_sync_enabled';
  
  SyncService({
    GoogleAuthService? authService,
    GoogleSheetsService? sheetsService,
    GoogleDriveService? driveService,
    ReceiptRepositoryImpl? receiptRepository,
  }) : 
    _authService = authService ?? GoogleAuthService(),
    _sheetsService = sheetsService ?? GoogleSheetsService(),
    _driveService = driveService ?? GoogleDriveService(),
    _receiptRepository = receiptRepository ?? ReceiptRepositoryImpl();
  
  // Getters for sync status
  bool get isSyncing => _isSyncing;
  double get syncProgress => _syncProgress;
  String get syncStatus => _syncStatus;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Initialize the sync service
  Future<bool> initialize() async {
    try {
      // Initialize Google services
      final sheetsInitialized = await _sheetsService.initialize();
      final driveInitialized = await _driveService.initialize();
      
      if (!sheetsInitialized || !driveInitialized) {
        return false;
      }
      
      // Load saved IDs
      await _loadSavedIds();
      
      // Load last sync time
      await _loadLastSyncTime();
      
      return true;
    } catch (e) {
      print('Error initializing sync service: $e');
      return false;
    }
  }
  
  // Load saved spreadsheet and folder IDs
  Future<void> _loadSavedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final spreadsheetId = prefs.getString(_spreadsheetIdKey);
      if (spreadsheetId != null) {
        _sheetsService.setSpreadsheetId(spreadsheetId);
      }
      
      final folderId = prefs.getString(_folderIdKey);
      if (folderId != null) {
        _driveService.setReceiptsFolderId(folderId);
      }
    } catch (e) {
      print('Error loading saved IDs: $e');
    }
  }
  
  // Save spreadsheet and folder IDs
  Future<void> _saveIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final spreadsheetId = _sheetsService.getSpreadsheetId();
      if (spreadsheetId != null) {
        await prefs.setString(_spreadsheetIdKey, spreadsheetId);
      }
      
      final folderId = _driveService.getReceiptsFolderId();
      if (folderId != null) {
        await prefs.setString(_folderIdKey, folderId);
      }
    } catch (e) {
      print('Error saving IDs: $e');
    }
  }
  
  // Load last sync time
  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final lastSyncTimeMs = prefs.getInt(_lastSyncTimeKey);
      if (lastSyncTimeMs != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimeMs);
      }
    } catch (e) {
      print('Error loading last sync time: $e');
    }
  }
  
  // Save last sync time
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _lastSyncTime = DateTime.now();
      await prefs.setInt(_lastSyncTimeKey, _lastSyncTime!.millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving last sync time: $e');
    }
  }
  
  // Sync all receipts to Google services
  Future<bool> syncReceipts() async {
    if (_isSyncing) {
      return false; // Already syncing
    }
    
    if (!_authService.isSignedIn) {
      _syncStatus = 'Not signed in';
      return false;
    }
    
    _isSyncing = true;
    _syncProgress = 0.0;
    _syncStatus = 'Starting sync...';
    
    try {
      // Initialize services if needed
      if (!await initialize()) {
        _syncStatus = 'Failed to initialize services';
        _isSyncing = false;
        return false;
      }
      
      // Get all receipts from local database
      _syncStatus = 'Loading receipts from database...';
      _syncProgress = 0.1;
      final receipts = await _receiptRepository.getAllReceipts();
      
      if (receipts.isEmpty) {
        _syncStatus = 'No receipts to sync';
        _isSyncing = false;
        return true;
      }
      
      // Create spreadsheet if needed
      _syncStatus = 'Preparing Google Sheets...';
      _syncProgress = 0.2;
      final spreadsheetId = _sheetsService.getSpreadsheetId();
      if (spreadsheetId == null) {
        final newSpreadsheetId = await _sheetsService.createReceiptsSpreadsheet();
        if (newSpreadsheetId == null) {
          _syncStatus = 'Failed to create spreadsheet';
          _isSyncing = false;
          return false;
        }
      }
      
      // Create folder if needed
      _syncStatus = 'Preparing Google Drive...';
      _syncProgress = 0.3;
      final folderId = _driveService.getReceiptsFolderId();
      if (folderId == null) {
        final newFolderId = await _driveService.createReceiptsFolder();
        if (newFolderId == null) {
          _syncStatus = 'Failed to create folder';
          _isSyncing = false;
          return false;
        }
      }
      
      // Save IDs
      await _saveIds();
      
      // Upload images that don't have a URL
      _syncStatus = 'Uploading receipt images...';
      _syncProgress = 0.4;
      
      final receiptsToUpdate = <Receipt>[];
      int imageCount = 0;
      
      for (final receipt in receipts) {
        if (receipt.imageUrl == null && receipt.imagePath != null) {
          final imageFile = File(receipt.imagePath!);
          if (await imageFile.exists()) {
            _syncStatus = 'Uploading image ${imageCount + 1} of ${receipts.length}...';
            
            final imageUrl = await _driveService.uploadReceiptImage(imageFile, receipt.id);
            if (imageUrl != null) {
              // Update receipt with image URL
              final updatedReceipt = receipt.copyWith(imageUrl: imageUrl);
              receiptsToUpdate.add(updatedReceipt);
              
              // Update in local database
              await _receiptRepository.updateReceipt(updatedReceipt);
            }
          }
          
          imageCount++;
          _syncProgress = 0.4 + (0.3 * (imageCount / receipts.length));
        }
      }
      
      // Get updated receipts list
      final updatedReceipts = await _receiptRepository.getAllReceipts();
      
      // Backup all receipts to Google Sheets
      _syncStatus = 'Backing up receipts to Google Sheets...';
      _syncProgress = 0.8;
      
      final backupSuccess = await _sheetsService.backupReceipts(updatedReceipts);
      if (!backupSuccess) {
        _syncStatus = 'Failed to backup receipts';
        _isSyncing = false;
        return false;
      }
      
      // Update last sync time
      _syncStatus = 'Finalizing sync...';
      _syncProgress = 0.9;
      await _saveLastSyncTime();
      
      _syncStatus = 'Sync completed successfully';
      _syncProgress = 1.0;
      _isSyncing = false;
      return true;
    } catch (e) {
      _syncStatus = 'Sync failed: $e';
      _isSyncing = false;
      return false;
    }
  }
  
  // Get sync settings
  Future<Map<String, dynamic>> getSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'autoSyncEnabled': prefs.getBool(_autoSyncEnabledKey) ?? false,
      'lastSyncTime': _lastSyncTime,
      'spreadsheetUrl': _sheetsService.getSpreadsheetUrl(),
    };
  }
  
  // Update sync settings
  Future<void> updateSyncSettings({bool? autoSyncEnabled}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (autoSyncEnabled != null) {
      await prefs.setBool(_autoSyncEnabledKey, autoSyncEnabled);
    }
  }
  
  // Check if auto sync is enabled
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncEnabledKey) ?? false;
  }
  
  // Clear sync data
  Future<void> clearSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_spreadsheetIdKey);
    await prefs.remove(_folderIdKey);
    await prefs.remove(_lastSyncTimeKey);
    
    _lastSyncTime = null;
  }
}
