import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;
import '../auth/google_auth_service.dart';

class GoogleDriveService {
  final GoogleAuthService _authService;
  drive.DriveApi? _driveApi;

  // Folder info
  String? _receiptsFolderId;
  static const String _receiptsFolderName = 'ReceiptRiser Images';

  GoogleDriveService({GoogleAuthService? authService})
      : _authService = authService ?? GoogleAuthService();

  // Initialize the Drive API
  Future<bool> initialize() async {
    try {
      final authClient = await _authService.getGoogleAuthClient();
      if (authClient == null) {
        return false;
      }

      _driveApi = drive.DriveApi(authClient);
      return true;
    } catch (e) {
      print('Error initializing Google Drive API: $e');
      return false;
    }
  }

  // Create a folder for receipt images
  Future<String?> createReceiptsFolder() async {
    if (_driveApi == null) {
      if (!await initialize()) {
        return null;
      }
    }

    try {
      // Check if folder already exists
      final existingFolderId = await _findReceiptsFolder();
      if (existingFolderId != null) {
        _receiptsFolderId = existingFolderId;
        return existingFolderId;
      }

      // Create a new folder
      final folder = drive.File(
        name: _receiptsFolderName,
        mimeType: 'application/vnd.google-apps.folder',
      );

      final response = await _driveApi!.files.create(folder);
      _receiptsFolderId = response.id;

      return _receiptsFolderId;
    } catch (e) {
      print('Error creating folder: $e');
      return null;
    }
  }

  // Find the receipts folder
  Future<String?> _findReceiptsFolder() async {
    if (_driveApi == null) {
      return null;
    }

    try {
      final query = "name='$_receiptsFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final response = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      final files = response.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }

      return null;
    } catch (e) {
      print('Error finding folder: $e');
      return null;
    }
  }

  // Set the receipts folder ID
  void setReceiptsFolderId(String id) {
    _receiptsFolderId = id;
  }

  // Get the receipts folder ID
  String? getReceiptsFolderId() {
    return _receiptsFolderId;
  }

  // Upload a receipt image
  Future<String?> uploadReceiptImage(File imageFile, String receiptId) async {
    if (_driveApi == null) {
      if (!await initialize()) {
        return null;
      }
    }

    if (_receiptsFolderId == null) {
      final folderId = await createReceiptsFolder();
      if (folderId == null) {
        return null;
      }
    }

    try {
      // Create file metadata
      final fileName = 'receipt_${receiptId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final file = drive.File(
        name: fileName,
        parents: [_receiptsFolderId!],
      );

      // Upload file
      final response = await _driveApi!.files.create(
        file,
        uploadMedia: drive.Media(
          imageFile.openRead(),
          await imageFile.length(),
          contentType: _getContentType(imageFile.path),
        ),
      );

      // Make the file publicly accessible
      await _driveApi!.permissions.create(
        drive.Permission(
          type: 'anyone',
          role: 'reader',
        ),
        response.id!,
      );

      // Get the web view link
      final updatedFile = await _driveApi!.files.get(
        response.id!,
        $fields: 'webViewLink',
      ) as drive.File;

      return updatedFile.webViewLink;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Delete a receipt image
  Future<bool> deleteReceiptImage(String fileUrl) async {
    if (_driveApi == null) {
      if (!await initialize()) {
        return false;
      }
    }

    try {
      // Extract file ID from URL
      final fileId = _extractFileIdFromUrl(fileUrl);
      if (fileId == null) {
        return false;
      }

      await _driveApi!.files.delete(fileId);
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  // Get content type based on file extension
  String _getContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  // Extract file ID from Google Drive URL
  String? _extractFileIdFromUrl(String url) {
    final regex = RegExp(r'/d/([^/]+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Try another format
    final idRegex = RegExp(r'id=([^&]+)');
    final idMatch = idRegex.firstMatch(url);
    if (idMatch != null && idMatch.groupCount >= 1) {
      return idMatch.group(1);
    }

    return null;
  }

  // List all receipt images
  Future<List<Map<String, String>>> listReceiptImages() async {
    if (_driveApi == null) {
      if (!await initialize()) {
        return [];
      }
    }

    if (_receiptsFolderId == null) {
      final folderId = await _findReceiptsFolder();
      if (folderId == null) {
        return [];
      }
      _receiptsFolderId = folderId;
    }

    try {
      final query = "'$_receiptsFolderId' in parents and trashed=false";
      final response = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, webViewLink)',
      );

      final files = response.files;
      if (files == null || files.isEmpty) {
        return [];
      }

      return files.map((file) {
        return {
          'id': file.id ?? '',
          'name': file.name ?? '',
          'url': file.webViewLink ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error listing images: $e');
      return [];
    }
  }
}
