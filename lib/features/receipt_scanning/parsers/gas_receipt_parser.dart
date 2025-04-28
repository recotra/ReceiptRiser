import 'base_receipt_parser.dart';

class GasReceiptParser extends BaseReceiptParser {
  @override
  String get receiptType => 'gas';

  @override
  String? extractMerchantName(List<String> lines) {
    if (lines.isEmpty) return null;
    
    // Gas station names are typically at the top of the receipt
    // Common gas station names to look for
    final gasStationNames = [
      'SHELL', 'EXXON', 'MOBIL', 'BP', 'CHEVRON', 'TEXACO', 'CITGO', 
      'MARATHON', 'SUNOCO', 'VALERO', 'PHILLIPS', 'CONOCO', '76', 'GULF'
    ];
    
    // First check for known gas station names
    for (int i = 0; i < Math.min(5, lines.length); i++) {
      final line = lines[i].trim().toUpperCase();
      
      for (final station in gasStationNames) {
        if (line.contains(station)) {
          return line;
        }
      }
    }
    
    // If no known gas station found, use general approach
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
    
    // Keywords that often precede dates in gas receipts
    final dateKeywords = [
      'DATE', 'TRANSACTION DATE', 'PURCHASE DATE', 
      'DATE:', 'TRANSACTION DATE:', 'PURCHASE DATE:'
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
    
    // Look for lines with time (often includes date in gas receipts)
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
    // Common amount patterns for gas receipts
    final amountPatterns = [
      RegExp(r'(?:TOTAL|AMOUNT|SALE|FUEL\s+TOTAL)(?:[:\s]+)?\$?(\d+\.\d{2})'), // TOTAL: $XX.XX
      RegExp(r'\$\s*(\d+\.\d{2})'), // $XX.XX
      RegExp(r'(\d+\.\d{2})\s*(?:USD|EUR|GBP)'), // XX.XX USD
    ];
    
    // Keywords that often precede or include amounts in gas receipts
    final amountKeywords = [
      'TOTAL', 'AMOUNT', 'SALE', 'FUEL TOTAL', 'FUEL AMOUNT',
      'TOTAL:', 'AMOUNT:', 'SALE:', 'FUEL TOTAL:', 'FUEL AMOUNT:'
    ];
    
    double? highestAmount;
    String? currency = 'USD'; // Default currency
    
    // First look for lines with amount keywords
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      
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
    
    // Extract gallons
    additionalFields['gallons'] = _extractGallons(lines);
    
    // Extract price per gallon
    additionalFields['pricePerGallon'] = _extractPricePerGallon(lines);
    
    // Extract fuel type
    additionalFields['fuelType'] = _extractFuelType(lines);
    
    // Extract payment method
    additionalFields['paymentMethod'] = _extractPaymentMethod(lines);
    
    // Extract pump number
    additionalFields['pumpNumber'] = _extractPumpNumber(lines);
    
    return additionalFields;
  }
  
  // Extract gallons
  double? _extractGallons(List<String> lines) {
    final gallonPatterns = [
      RegExp(r'(?:GALLONS|GAL)(?:[:\s]+)?(\d+\.\d{1,3})'), // GALLONS: XX.XXX
      RegExp(r'(\d+\.\d{1,3})\s*(?:GALLONS|GAL)'), // XX.XXX GALLONS
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('GALLON') || upperLine.contains('GAL')) {
        for (final pattern in gallonPatterns) {
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
  
  // Extract price per gallon
  double? _extractPricePerGallon(List<String> lines) {
    final pricePatterns = [
      RegExp(r'(?:PRICE|PRICE/GAL|PER\s+GALLON)(?:[:\s]+)?\$?(\d+\.\d{1,3})'), // PRICE: $X.XXX
      RegExp(r'\$\s*(\d+\.\d{1,3})\s*(?:\/\s*GAL|PER\s+GAL)'), // $X.XXX/GAL
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('PRICE') || upperLine.contains('PER GAL') || upperLine.contains('/GAL')) {
        for (final pattern in pricePatterns) {
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
  
  // Extract fuel type
  String? _extractFuelType(List<String> lines) {
    final fuelTypes = [
      'REGULAR', 'UNLEADED', 'PREMIUM', 'SUPER', 'DIESEL', 'E85', 'MIDGRADE',
      'REGULAR UNLEADED', 'PREMIUM UNLEADED', 'SUPER UNLEADED'
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      for (final type in fuelTypes) {
        if (upperLine.contains(type)) {
          return type;
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
  
  // Extract pump number
  int? _extractPumpNumber(List<String> lines) {
    final pumpPatterns = [
      RegExp(r'(?:PUMP|PUMP\s+NO|PUMP\s+NUMBER)[:\s]+(\d+)'), // PUMP: X
    ];
    
    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.contains('PUMP')) {
        for (final pattern in pumpPatterns) {
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
