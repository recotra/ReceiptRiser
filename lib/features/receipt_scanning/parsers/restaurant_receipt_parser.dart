import 'base_receipt_parser.dart';

class RestaurantReceiptParser extends BaseReceiptParser {
  @override
  String get receiptType => 'restaurant';

  @override
  String? extractMerchantName(List<String> lines) {
    if (lines.isEmpty) return null;
    
    // Restaurant names are typically at the top of the receipt
    // and often in ALL CAPS or larger font
    for (int i = 0; i < Math.min(4, lines.length); i++) {
      final line = lines[i].trim();
      
      // Skip lines that are likely not restaurant names
      if (line.contains(RegExp(r'\d{2}/\d{2}/\d{2,4}'))) continue; // Skip date lines
      if (line.contains(RegExp(r'\$\d+\.\d{2}'))) continue; // Skip amount lines
      if (line.contains('RECEIPT') || line.contains('INVOICE')) continue; // Skip receipt/invoice headers
      if (line.contains('TABLE') || line.contains('SERVER')) continue; // Skip table/server info
      
      // If line is all caps or starts with caps, it's likely the restaurant name
      if (line == line.toUpperCase() || 
          (line.length > 3 && line[0] == line[0].toUpperCase())) {
        return line;
      }
    }
    
    // If no good candidate found, return the first non-empty line
    return lines.first;
  }

  @override
  String? extractMerchantAddress(List<String> lines) {
    if (lines.length < 2) return null;
    
    // Look for address patterns (street numbers, city names, zip codes)
    final addressPattern = RegExp(r'\d+\s+[A-Za-z]+|[A-Za-z]+,\s*[A-Za-z]{2}|\d{5}(-\d{4})?');
    
    // Start from line 2 (after potential restaurant name)
    for (int i = 1; i < Math.min(7, lines.length); i++) {
      final line = lines[i].trim();
      if (addressPattern.hasMatch(line)) {
        return line;
      }
    }
    
    return null;
  }

  @override
  DateTime? extractTransactionDate(List<String> lines) {
    // Common date formats
    final datePatterns = [
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})'), // MM/DD/YYYY or DD/MM/YYYY
      RegExp(r'(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{2,4})'), // DD Month YYYY
      RegExp(r'([A-Za-z]{3,})\s+(\d{1,2}),?\s+(\d{2,4})'), // Month DD, YYYY
    ];
    
    // Keywords that often precede dates in restaurant receipts
    final dateKeywords = [
      'DATE', 'CHECK DATE', 'VISIT DATE', 'ORDER DATE',
      'DATE:', 'CHECK DATE:', 'VISIT DATE:', 'ORDER DATE:'
    ];
    
    // First look for lines with date keywords
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      for (final keyword in dateKeywords) {
        if (upperLine.contains(keyword)) {
          // Try to extract date from this line
          final date = tryExtractDate(line, datePatterns);
          if (date != null) return date;
        }
      }
    }
    
    // Look for lines with time (often includes date in restaurant receipts)
    for (final line in lines) {
      if (line.contains(RegExp(r'\d{1,2}:\d{2}'))) { // Time pattern
        final date = tryExtractDate(line, datePatterns);
        if (date != null) return date;
      }
    }
    
    // If not found, scan all lines for date patterns
    for (final line in lines) {
      final date = tryExtractDate(line, datePatterns);
      if (date != null) return date;
    }
    
    // If no date found, return current date
    return DateTime.now();
  }

  @override
  (double?, String?) extractAmount(List<String> lines) {
    // Common amount patterns for restaurant receipts
    final amountPatterns = [
      RegExp(r'(?:TOTAL|AMOUNT|BALANCE|DUE|PAID)(?:[:\s]+)?\$?(\d+\.\d{2})'), // TOTAL: $XX.XX
      RegExp(r'\$\s*(\d+\.\d{2})'), // $XX.XX
      RegExp(r'(\d+\.\d{2})\s*(?:USD|EUR|GBP)'), // XX.XX USD
    ];
    
    // Keywords that often precede or include amounts in restaurant receipts
    final amountKeywords = [
      'TOTAL', 'AMOUNT DUE', 'BALANCE DUE', 'AMOUNT PAID', 'GRAND TOTAL',
      'TOTAL:', 'AMOUNT DUE:', 'BALANCE DUE:', 'AMOUNT PAID:', 'GRAND TOTAL:',
      'CHECK TOTAL', 'CHECK TOTAL:'
    ];
    
    double? highestAmount;
    String? currency = 'USD'; // Default currency
    
    // First look for lines with amount keywords
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      
      // Skip lines that are likely not totals
      if (upperLine.contains('SUBTOTAL') && !upperLine.contains('TOTAL:')) continue;
      if (upperLine.contains('TIP') || upperLine.contains('GRATUITY')) continue;
      
      for (final keyword in amountKeywords) {
        if (upperLine.contains(keyword)) {
          // Try to extract amount from this line
          final result = _tryExtractAmount(line, amountPatterns);
          if (result.$1 != null) {
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
      if (result.$1 != null && (highestAmount == null || result.$1! > highestAmount)) {
        highestAmount = result.$1;
        currency = result.$2;
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
  
  @override
  Map<String, dynamic>? extractAdditionalFields(List<String> lines) {
    final additionalFields = <String, dynamic>{};
    
    // Extract tip information
    additionalFields['tip'] = _extractTip(lines);
    
    // Extract tax information
    additionalFields['tax'] = _extractTax(lines);
    
    // Extract server name
    additionalFields['server'] = _extractServer(lines);
    
    // Extract table number
    additionalFields['table'] = _extractTable(lines);
    
    // Extract number of guests
    additionalFields['guests'] = _extractGuests(lines);
    
    return additionalFields;
  }
  
  // Extract tip information
  double? _extractTip(List<String> lines) {
    final tipPatterns = [
      RegExp(r'(?:TIP|GRATUITY)(?:[:\s]+)?\$?(\d+\.\d{2})'), // TIP: $XX.XX
      RegExp(r'(?:TIP|GRATUITY)[:\s]+(\d+\.\d{2})'), // TIP: XX.XX
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('TIP') || upperLine.contains('GRATUITY')) {
        for (final pattern in tipPatterns) {
          final match = pattern.firstMatch(line);
          if (match != null && match.groupCount >= 1) {
            try {
              return double.parse(match.group(1)!);
            } catch (e) {
              continue;
            }
          }
        }
      }
    }
    
    return null;
  }
  
  // Extract tax information
  double? _extractTax(List<String> lines) {
    final taxPatterns = [
      RegExp(r'(?:TAX|SALES\s+TAX|VAT)(?:[:\s]+)?\$?(\d+\.\d{2})'), // TAX: $XX.XX
      RegExp(r'(?:TAX|SALES\s+TAX|VAT)[:\s]+(\d+\.\d{2})'), // TAX: XX.XX
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('TAX') || upperLine.contains('VAT')) {
        for (final pattern in taxPatterns) {
          final match = pattern.firstMatch(line);
          if (match != null && match.groupCount >= 1) {
            try {
              return double.parse(match.group(1)!);
            } catch (e) {
              continue;
            }
          }
        }
      }
    }
    
    return null;
  }
  
  // Extract server name
  String? _extractServer(List<String> lines) {
    final serverPatterns = [
      RegExp(r'(?:SERVER|WAITER|WAITRESS)[:\s]+([A-Za-z]+)'), // SERVER: Name
      RegExp(r'(?:SERVER|WAITER|WAITRESS)[:\s]+([A-Za-z]+\s+[A-Za-z]+)'), // SERVER: First Last
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('SERVER') || upperLine.contains('WAITER') || upperLine.contains('WAITRESS')) {
        for (final pattern in serverPatterns) {
          final match = pattern.firstMatch(line);
          if (match != null && match.groupCount >= 1) {
            return match.group(1);
          }
        }
        
        // If pattern doesn't match but line contains server info,
        // try to extract the name from the end of the line
        final parts = line.split(':');
        if (parts.length > 1) {
          return parts[1].trim();
        }
      }
    }
    
    return null;
  }
  
  // Extract table number
  String? _extractTable(List<String> lines) {
    final tablePatterns = [
      RegExp(r'(?:TABLE|TABLE\s+NO|TABLE\s+NUMBER)[:\s]+(\d+)'), // TABLE: XX
      RegExp(r'(?:TABLE|TABLE\s+NO|TABLE\s+NUMBER)[:\s]+([A-Za-z\d]+)'), // TABLE: A1
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('TABLE')) {
        for (final pattern in tablePatterns) {
          final match = pattern.firstMatch(line);
          if (match != null && match.groupCount >= 1) {
            return match.group(1);
          }
        }
        
        // If pattern doesn't match but line contains table info,
        // try to extract the number from the end of the line
        final parts = line.split(':');
        if (parts.length > 1) {
          return parts[1].trim();
        }
      }
    }
    
    return null;
  }
  
  // Extract number of guests
  int? _extractGuests(List<String> lines) {
    final guestPatterns = [
      RegExp(r'(?:GUESTS|PEOPLE|PERSONS|PARTY\s+SIZE)[:\s]+(\d+)'), // GUESTS: X
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('GUEST') || upperLine.contains('PEOPLE') || 
          upperLine.contains('PERSONS') || upperLine.contains('PARTY SIZE')) {
        for (final pattern in guestPatterns) {
          final match = pattern.firstMatch(line);
          if (match != null && match.groupCount >= 1) {
            try {
              return int.parse(match.group(1)!);
            } catch (e) {
              continue;
            }
          }
        }
      }
    }
    
    return null;
  }
}

// Helper class for Math operations
class Math {
  static int min(int a, int b) => a < b ? a : b;
}
