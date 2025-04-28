import 'package:googleapis/sheets/v4.dart' as sheets;
import '../auth/google_auth_service.dart';
import '../../domain/entities/receipt.dart';

class GoogleSheetsService {
  final GoogleAuthService _authService;
  sheets.SheetsApi? _sheetsApi;

  // Spreadsheet info
  String? _spreadsheetId;
  static const String _receiptsSheetName = 'Receipts';

  GoogleSheetsService({GoogleAuthService? authService})
      : _authService = authService ?? GoogleAuthService();

  // Initialize the Sheets API
  Future<bool> initialize() async {
    try {
      final authClient = await _authService.getGoogleAuthClient();
      if (authClient == null) {
        return false;
      }

      _sheetsApi = sheets.SheetsApi(authClient);
      return true;
    } catch (e) {
      print('Error initializing Google Sheets API: $e');
      return false;
    }
  }

  // Create a new spreadsheet for receipts
  Future<String?> createReceiptsSpreadsheet() async {
    if (_sheetsApi == null) {
      if (!await initialize()) {
        return null;
      }
    }

    try {
      // Create a new spreadsheet
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: 'ReceiptRiser Data',
          locale: 'en_US',
        ),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(
              title: _receiptsSheetName,
              gridProperties: sheets.GridProperties(
                frozenRowCount: 1, // Freeze header row
              ),
            ),
          ),
        ],
      );

      final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
      _spreadsheetId = response.spreadsheetId;

      // Add headers to the receipts sheet
      await _addReceiptHeaders();

      return _spreadsheetId;
    } catch (e) {
      print('Error creating spreadsheet: $e');
      return null;
    }
  }

  // Add headers to the receipts sheet
  Future<bool> _addReceiptHeaders() async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      return false;
    }

    try {
      final values = [
        [
          'ID',
          'Merchant Name',
          'Merchant Address',
          'Transaction Date',
          'Amount',
          'Currency',
          'Category',
          'Receipt Type',
          'Notes',
          'Image URL',
          'Created At',
          'Updated At',
        ]
      ];

      final valueRange = sheets.ValueRange(
        range: '$_receiptsSheetName!A1:L1',
        values: values,
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        '$_receiptsSheetName!A1:L1',
        valueInputOption: 'RAW',
      );

      // Format header row
      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: 0,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: 12,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(
                  red: 0.2,
                  green: 0.4,
                  blue: 0.8,
                ),
                textFormat: sheets.TextFormat(
                  bold: true,
                  foregroundColor: sheets.Color(
                    red: 1.0,
                    green: 1.0,
                    blue: 1.0,
                  ),
                ),
                horizontalAlignment: 'CENTER',
              ),
            ),
            fields: 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)',
          ),
        ),
        sheets.Request(
          autoResizeDimensions: sheets.AutoResizeDimensionsRequest(
            dimensions: sheets.DimensionRange(
              sheetId: 0,
              dimension: 'COLUMNS',
              startIndex: 0,
              endIndex: 12,
            ),
          ),
        ),
      ];

      await _sheetsApi!.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        _spreadsheetId!,
      );

      return true;
    } catch (e) {
      print('Error adding headers: $e');
      return false;
    }
  }

  // Set the spreadsheet ID
  void setSpreadsheetId(String id) {
    _spreadsheetId = id;
  }

  // Get the spreadsheet ID
  String? getSpreadsheetId() {
    return _spreadsheetId;
  }

  // Check if a spreadsheet exists
  Future<bool> checkSpreadsheetExists(String spreadsheetId) async {
    if (_sheetsApi == null) {
      if (!await initialize()) {
        return false;
      }
    }

    try {
      await _sheetsApi!.spreadsheets.get(spreadsheetId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Add a receipt to the spreadsheet
  Future<bool> addReceipt(Receipt receipt) async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      return false;
    }

    try {
      // Get the next available row
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$_receiptsSheetName!A:A',
      );

      final values = response.values ?? [];
      final nextRow = values.length + 1;

      // Format the receipt data
      final receiptData = [
        [
          receipt.id,
          receipt.merchantName,
          receipt.merchantAddress ?? '',
          receipt.transactionDate.toIso8601String(),
          receipt.amount.toString(),
          receipt.currency,
          receipt.category,
          receipt.receiptType ?? 'Unknown',
          receipt.notes ?? '',
          receipt.imageUrl ?? '',
          receipt.createdAt.toIso8601String(),
          receipt.updatedAt?.toIso8601String() ?? '',
        ]
      ];

      final valueRange = sheets.ValueRange(
        range: '$_receiptsSheetName!A$nextRow:L$nextRow',
        values: receiptData,
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        '$_receiptsSheetName!A$nextRow:L$nextRow',
        valueInputOption: 'RAW',
      );

      return true;
    } catch (e) {
      print('Error adding receipt: $e');
      return false;
    }
  }

  // Update a receipt in the spreadsheet
  Future<bool> updateReceipt(Receipt receipt) async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      return false;
    }

    try {
      // Find the row with the receipt ID
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$_receiptsSheetName!A:A',
      );

      final values = response.values ?? [];
      int? rowIndex;

      for (int i = 1; i < values.length; i++) {
        if (values[i].isNotEmpty && values[i][0] == receipt.id) {
          rowIndex = i + 1; // +1 because sheets are 1-indexed
          break;
        }
      }

      if (rowIndex == null) {
        // Receipt not found, add it instead
        return await addReceipt(receipt);
      }

      // Update the receipt data
      final receiptData = [
        [
          receipt.id,
          receipt.merchantName,
          receipt.merchantAddress ?? '',
          receipt.transactionDate.toIso8601String(),
          receipt.amount.toString(),
          receipt.currency,
          receipt.category,
          receipt.receiptType ?? 'Unknown',
          receipt.notes ?? '',
          receipt.imageUrl ?? '',
          receipt.createdAt.toIso8601String(),
          receipt.updatedAt?.toIso8601String() ?? '',
        ]
      ];

      final valueRange = sheets.ValueRange(
        range: '$_receiptsSheetName!A$rowIndex:L$rowIndex',
        values: receiptData,
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        '$_receiptsSheetName!A$rowIndex:L$rowIndex',
        valueInputOption: 'RAW',
      );

      return true;
    } catch (e) {
      print('Error updating receipt: $e');
      return false;
    }
  }

  // Delete a receipt from the spreadsheet
  Future<bool> deleteReceipt(String receiptId) async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      return false;
    }

    try {
      // Find the row with the receipt ID
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$_receiptsSheetName!A:A',
      );

      final values = response.values ?? [];
      int? rowIndex;
      int? sheetId;

      for (int i = 1; i < values.length; i++) {
        if (values[i].isNotEmpty && values[i][0] == receiptId) {
          rowIndex = i; // 0-indexed for the API
          break;
        }
      }

      if (rowIndex == null) {
        // Receipt not found
        return false;
      }

      // Get the sheet ID
      final spreadsheet = await _sheetsApi!.spreadsheets.get(_spreadsheetId!);
      for (final sheet in spreadsheet.sheets!) {
        if (sheet.properties!.title == _receiptsSheetName) {
          sheetId = sheet.properties!.sheetId;
          break;
        }
      }

      if (sheetId == null) {
        return false;
      }

      // Delete the row
      final requests = [
        sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: rowIndex,
              endIndex: rowIndex + 1,
            ),
          ),
        ),
      ];

      await _sheetsApi!.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        _spreadsheetId!,
      );

      return true;
    } catch (e) {
      print('Error deleting receipt: $e');
      return false;
    }
  }

  // Get all receipts from the spreadsheet
  Future<List<Receipt>> getAllReceipts() async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      return [];
    }

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$_receiptsSheetName!A2:L',
      );

      final values = response.values ?? [];
      final receipts = <Receipt>[];

      for (final row in values) {
        if (row.length < 12) continue;

        try {
          final receipt = Receipt(
            id: row[0].toString(),
            userId: _authService.currentUser?.uid ?? '',
            merchantName: row[1].toString(),
            merchantAddress: row[2].toString().isEmpty ? null : row[2].toString(),
            transactionDate: DateTime.parse(row[3].toString()),
            amount: double.parse(row[4].toString()),
            currency: row[5].toString(),
            category: row[6].toString(),
            receiptType: row[7].toString(),
            notes: row[8].toString().isEmpty ? null : row[8].toString(),
            imageUrl: row[9].toString().isEmpty ? null : row[9].toString(),
            createdAt: DateTime.parse(row[10].toString()),
            updatedAt: row[11] != null ? DateTime.parse(row[11].toString()) : null,
          );

          receipts.add(receipt);
        } catch (e) {
          print('Error parsing receipt: $e');
        }
      }

      return receipts;
    } catch (e) {
      print('Error getting receipts: $e');
      return [];
    }
  }

  // Backup all receipts to the spreadsheet
  Future<bool> backupReceipts(List<Receipt> receipts) async {
    if (_sheetsApi == null) {
      if (!await initialize()) {
        return false;
      }
    }

    if (_spreadsheetId == null) {
      final spreadsheetId = await createReceiptsSpreadsheet();
      if (spreadsheetId == null) {
        return false;
      }
    }

    try {
      // Clear existing data (except headers)
      await _sheetsApi!.spreadsheets.values.clear(
        sheets.ClearValuesRequest(),
        _spreadsheetId!,
        '$_receiptsSheetName!A2:L',
      );

      // Prepare batch data
      final List<List<dynamic>> batchData = [];

      for (final receipt in receipts) {
        batchData.add([
          receipt.id,
          receipt.merchantName,
          receipt.merchantAddress ?? '',
          receipt.transactionDate.toIso8601String(),
          receipt.amount.toString(),
          receipt.currency,
          receipt.category,
          receipt.receiptType ?? 'Unknown',
          receipt.notes ?? '',
          receipt.imageUrl ?? '',
          receipt.createdAt.toIso8601String(),
          receipt.updatedAt?.toIso8601String() ?? '',
        ]);
      }

      if (batchData.isEmpty) {
        return true; // Nothing to backup
      }

      // Add all receipts in one batch
      final valueRange = sheets.ValueRange(
        range: '$_receiptsSheetName!A2:L${batchData.length + 1}',
        values: batchData,
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        '$_receiptsSheetName!A2:L${batchData.length + 1}',
        valueInputOption: 'RAW',
      );

      return true;
    } catch (e) {
      print('Error backing up receipts: $e');
      return false;
    }
  }

  // Get the spreadsheet URL
  String? getSpreadsheetUrl() {
    if (_spreadsheetId == null) {
      return null;
    }

    return 'https://docs.google.com/spreadsheets/d/$_spreadsheetId/edit';
  }
}
