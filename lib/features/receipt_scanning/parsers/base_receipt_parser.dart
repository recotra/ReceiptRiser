import 'package:intl/intl.dart';

/// Base class for receipt parsers
abstract class BaseReceiptParser {
  // Extracted receipt data
  String? merchantName;
  String? merchantAddress;
  DateTime? transactionDate;
  double? amount;
  String? currency;
  Map<String, dynamic>? additionalFields;
  double confidenceScore = 0.0;

  // Receipt type
  String get receiptType;
  
  // Parse the recognized text from the receipt
  void parseReceiptText(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // Extract basic information
    merchantName = extractMerchantName(lines);
    merchantAddress = extractMerchantAddress(lines);
    transactionDate = extractTransactionDate(lines);
    final amountData = extractAmount(lines);
    amount = amountData.$1;
    currency = amountData.$2;
    
    // Extract additional fields specific to this receipt type
    additionalFields = extractAdditionalFields(lines);
    
    // Calculate confidence score
    calculateConfidenceScore();
  }
  
  // Extract merchant name
  String? extractMerchantName(List<String> lines);
  
  // Extract merchant address
  String? extractMerchantAddress(List<String> lines);
  
  // Extract transaction date
  DateTime? extractTransactionDate(List<String> lines);
  
  // Extract amount and currency
  (double?, String?) extractAmount(List<String> lines);
  
  // Extract additional fields specific to this receipt type
  Map<String, dynamic>? extractAdditionalFields(List<String> lines) {
    return null; // Default implementation returns null
  }
  
  // Calculate confidence score based on extracted fields
  void calculateConfidenceScore() {
    int fieldsExtracted = 0;
    int totalFields = 4; // merchantName, merchantAddress, transactionDate, amount
    
    if (merchantName != null && merchantName!.isNotEmpty) fieldsExtracted++;
    if (merchantAddress != null && merchantAddress!.isNotEmpty) fieldsExtracted++;
    if (transactionDate != null) fieldsExtracted++;
    if (amount != null) fieldsExtracted++;
    
    confidenceScore = fieldsExtracted / totalFields;
  }
  
  // Helper to normalize 2-digit years to 4-digit
  int normalizeYear(int year) {
    if (year < 100) {
      // Assume 20xx for years less than 50, 19xx otherwise
      return year < 50 ? 2000 + year : 1900 + year;
    }
    return year;
  }
  
  // Helper to parse month name to number
  int parseMonth(String monthText) {
    final months = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
      'JANUARY': 1, 'FEBRUARY': 2, 'MARCH': 3, 'APRIL': 4, 'MAY': 5, 'JUNE': 6,
      'JULY': 7, 'AUGUST': 8, 'SEPTEMBER': 9, 'OCTOBER': 10, 'NOVEMBER': 11, 'DECEMBER': 12
    };
    
    final upperMonth = monthText.toUpperCase();
    for (final entry in months.entries) {
      if (upperMonth.contains(entry.key)) {
        return entry.value;
      }
    }
    return 1; // Default to January if not found
  }
  
  // Helper method to try extracting date using multiple patterns
  DateTime? tryExtractDate(String line, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        try {
          // Try to parse the date
          if (pattern.pattern.contains(r'[A-Za-z]{3,}')) {
            // Handle text month format
            if (match.groupCount >= 3) {
              int day, month, year;
              
              if (pattern.pattern.startsWith(r'(\d{1,2})')) {
                // DD Month YYYY
                day = int.parse(match.group(1)!);
                month = parseMonth(match.group(2)!);
                year = normalizeYear(int.parse(match.group(3)!));
              } else {
                // Month DD, YYYY
                month = parseMonth(match.group(1)!);
                day = int.parse(match.group(2)!);
                year = normalizeYear(int.parse(match.group(3)!));
              }
              
              return DateTime(year, month, day);
            }
          } else {
            // Handle numeric date format
            if (match.groupCount >= 3) {
              final part1 = int.parse(match.group(1)!);
              final part2 = int.parse(match.group(2)!);
              final part3 = normalizeYear(int.parse(match.group(3)!));
              
              // Determine if MM/DD/YYYY or DD/MM/YYYY
              // Assume MM/DD/YYYY for US receipts
              if (part1 <= 12) {
                return DateTime(part3, part1, part2);
              } else {
                return DateTime(part3, part2, part1);
              }
            }
          }
        } catch (e) {
          // Continue to next pattern if parsing fails
          continue;
        }
      }
    }
    return null;
  }
}
