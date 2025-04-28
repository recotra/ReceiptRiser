import 'package:intl/intl.dart';

class ReceiptParser {
  // Extracted receipt data
  String? merchantName;
  String? merchantAddress;
  DateTime? transactionDate;
  double? amount;
  String? currency;

  // Parse the recognized text from the receipt
  void parseReceiptText(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // Extract merchant name (usually at the top of the receipt)
    merchantName = _extractMerchantName(lines);
    
    // Extract merchant address
    merchantAddress = _extractMerchantAddress(lines);
    
    // Extract transaction date
    transactionDate = _extractTransactionDate(lines);
    
    // Extract amount
    final amountData = _extractAmount(lines);
    amount = amountData.item1;
    currency = amountData.item2;
  }

  // Extract merchant name (usually one of the first lines)
  String? _extractMerchantName(List<String> lines) {
    if (lines.isEmpty) return null;
    
    // Try to find a line that looks like a merchant name
    // Usually one of the first few lines and often in ALL CAPS or has specific keywords
    for (int i = 0; i < Math.min(5, lines.length); i++) {
      final line = lines[i].trim();
      
      // Skip lines that are likely not merchant names
      if (line.contains(RegExp(r'\d{2}/\d{2}/\d{2,4}'))) continue; // Skip date lines
      if (line.contains(RegExp(r'\$\d+\.\d{2}'))) continue; // Skip amount lines
      if (line.contains('RECEIPT') || line.contains('INVOICE')) continue; // Skip receipt/invoice headers
      
      // If line is all caps or starts with caps, it's likely the merchant name
      if (line == line.toUpperCase() || 
          (line.length > 3 && line[0] == line[0].toUpperCase())) {
        return line;
      }
    }
    
    // If no good candidate found, return the first non-empty line
    return lines.first;
  }

  // Extract merchant address
  String? _extractMerchantAddress(List<String> lines) {
    if (lines.length < 2) return null;
    
    // Look for address patterns (street numbers, city names, zip codes)
    final addressPattern = RegExp(r'\d+\s+[A-Za-z]+|[A-Za-z]+,\s*[A-Za-z]{2}|\d{5}(-\d{4})?');
    
    // Start from line 2 (after potential merchant name)
    for (int i = 1; i < Math.min(7, lines.length); i++) {
      final line = lines[i].trim();
      if (addressPattern.hasMatch(line)) {
        return line;
      }
    }
    
    return null;
  }

  // Extract transaction date
  DateTime? _extractTransactionDate(List<String> lines) {
    // Common date formats
    final datePatterns = [
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})'), // MM/DD/YYYY or DD/MM/YYYY
      RegExp(r'(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{2,4})'), // DD Month YYYY
      RegExp(r'([A-Za-z]{3,})\s+(\d{1,2}),?\s+(\d{2,4})'), // Month DD, YYYY
    ];
    
    // Keywords that often precede dates
    final dateKeywords = [
      'DATE', 'TRANSACTION DATE', 'PURCHASE DATE', 'SALE DATE', 
      'DATE:', 'TRANSACTION DATE:', 'PURCHASE DATE:', 'SALE DATE:'
    ];
    
    // First look for lines with date keywords
    for (final line in lines) {
      final lowerLine = line.toUpperCase();
      for (final keyword in dateKeywords) {
        if (lowerLine.contains(keyword)) {
          // Try to extract date from this line
          final date = _tryExtractDate(line, datePatterns);
          if (date != null) return date;
        }
      }
    }
    
    // If not found, scan all lines for date patterns
    for (final line in lines) {
      final date = _tryExtractDate(line, datePatterns);
      if (date != null) return date;
    }
    
    // If no date found, return current date
    return DateTime.now();
  }

  // Helper method to try extracting date using multiple patterns
  DateTime? _tryExtractDate(String line, List<RegExp> patterns) {
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
                month = _parseMonth(match.group(2)!);
                year = _normalizeYear(int.parse(match.group(3)!));
              } else {
                // Month DD, YYYY
                month = _parseMonth(match.group(1)!);
                day = int.parse(match.group(2)!);
                year = _normalizeYear(int.parse(match.group(3)!));
              }
              
              return DateTime(year, month, day);
            }
          } else {
            // Handle numeric date format
            if (match.groupCount >= 3) {
              final part1 = int.parse(match.group(1)!);
              final part2 = int.parse(match.group(2)!);
              final part3 = _normalizeYear(int.parse(match.group(3)!));
              
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

  // Helper to parse month name to number
  int _parseMonth(String monthText) {
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

  // Helper to normalize 2-digit years to 4-digit
  int _normalizeYear(int year) {
    if (year < 100) {
      // Assume 20xx for years less than 50, 19xx otherwise
      return year < 50 ? 2000 + year : 1900 + year;
    }
    return year;
  }

  // Extract amount and currency
  (double?, String?) _extractAmount(List<String> lines) {
    // Common amount patterns
    final amountPatterns = [
      RegExp(r'(?:TOTAL|AMOUNT|BALANCE|DUE|PAID)(?:[:\s]+)?\$?(\d+\.\d{2})'), // TOTAL: $XX.XX
      RegExp(r'\$\s*(\d+\.\d{2})'), // $XX.XX
      RegExp(r'(\d+\.\d{2})\s*(?:USD|EUR|GBP)'), // XX.XX USD
    ];
    
    // Keywords that often precede or include amounts
    final amountKeywords = [
      'TOTAL', 'AMOUNT', 'BALANCE DUE', 'AMOUNT PAID', 'GRAND TOTAL',
      'TOTAL:', 'AMOUNT:', 'BALANCE DUE:', 'AMOUNT PAID:', 'GRAND TOTAL:'
    ];
    
    double? highestAmount;
    String? currency = 'USD'; // Default currency
    
    // First look for lines with amount keywords
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      
      // Skip lines that are likely not totals
      if (upperLine.contains('SUBTOTAL') && !upperLine.contains('TOTAL:')) continue;
      
      for (final keyword in amountKeywords) {
        if (upperLine.contains(keyword)) {
          // Try to extract amount from this line
          final result = _tryExtractAmount(line, amountPatterns);
          if (result.item1 != null) {
            // If we find a line with a keyword, it's likely the total
            return result;
          }
        }
      }
    }
    
    // If not found with keywords, scan all lines for amount patterns
    // and take the highest amount (usually the total)
    for (final line in lines) {
      final result = _tryExtractAmount(line, amountPatterns);
      if (result.item1 != null && (highestAmount == null || result.item1! > highestAmount)) {
        highestAmount = result.item1;
        currency = result.item2;
      }
    }
    
    return (highestAmount, currency);
  }

  // Helper method to try extracting amount using multiple patterns
  (double?, String?) _tryExtractAmount(String line, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null && match.groupCount >= 1) {
        try {
          final amountStr = match.group(1)!;
          final amount = double.parse(amountStr);
          
          // Try to extract currency
          String? currency;
          if (line.contains('\$') || line.contains('USD')) {
            currency = 'USD';
          } else if (line.contains('€') || line.contains('EUR')) {
            currency = 'EUR';
          } else if (line.contains('£') || line.contains('GBP')) {
            currency = 'GBP';
          } else {
            currency = 'USD'; // Default
          }
          
          return (amount, currency);
        } catch (e) {
          // Continue to next pattern if parsing fails
          continue;
        }
      }
    }
    return (null, null);
  }
}

// Helper class for Math operations
class Math {
  static int min(int a, int b) => a < b ? a : b;
}

// Extension for Tuple
extension Tuple2<T1, T2> on (T1?, T2?) {
  T1? get item1 => $1;
  T2? get item2 => $2;
}
