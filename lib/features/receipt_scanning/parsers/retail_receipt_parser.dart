import 'base_receipt_parser.dart';

class RetailReceiptParser extends BaseReceiptParser {
  @override
  String get receiptType => 'retail';

  @override
  String? extractMerchantName(List<String> lines) {
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

  @override
  String? extractMerchantAddress(List<String> lines) {
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

  @override
  DateTime? extractTransactionDate(List<String> lines) {
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
      final upperLine = line.toUpperCase();
      for (final keyword in dateKeywords) {
        if (upperLine.contains(keyword)) {
          // Try to extract date from this line
          final date = tryExtractDate(line, datePatterns);
          if (date != null) return date;
        }
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
    
    // Extract tax information
    additionalFields['tax'] = _extractTax(lines);
    
    // Extract payment method
    additionalFields['paymentMethod'] = _extractPaymentMethod(lines);
    
    return additionalFields;
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
  
  // Extract payment method
  String? _extractPaymentMethod(List<String> lines) {
    final paymentMethods = [
      'CASH', 'CREDIT', 'DEBIT', 'VISA', 'MASTERCARD', 'AMEX', 
      'AMERICAN EXPRESS', 'DISCOVER', 'CHECK', 'GIFT CARD', 'APPLE PAY', 'GOOGLE PAY'
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      for (final method in paymentMethods) {
        if (upperLine.contains(method)) {
          return method;
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
