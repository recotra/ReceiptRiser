import 'receipt_classifier.dart';
import 'parsers/base_receipt_parser.dart';
import 'parsers/retail_receipt_parser.dart';
import 'parsers/restaurant_receipt_parser.dart';
import 'parsers/gas_receipt_parser.dart';

/// Enhanced receipt parser that uses a classifier to determine the best parser to use
class EnhancedReceiptParser {
  // Extracted receipt data
  String? merchantName;
  String? merchantAddress;
  DateTime? transactionDate;
  double? amount;
  String? currency;
  Map<String, dynamic>? additionalFields;
  String receiptType = 'unknown';
  double confidenceScore = 0.0;
  
  // Parse the recognized text from the receipt
  void parseReceiptText(String text) {
    // Classify the receipt
    receiptType = ReceiptClassifier.classifyReceipt(text);
    
    // Create the appropriate parser based on the receipt type
    final parser = _createParser(receiptType);
    
    // Parse the receipt
    parser.parseReceiptText(text);
    
    // Extract the parsed data
    merchantName = parser.merchantName;
    merchantAddress = parser.merchantAddress;
    transactionDate = parser.transactionDate;
    amount = parser.amount;
    currency = parser.currency;
    additionalFields = parser.additionalFields;
    confidenceScore = parser.confidenceScore;
  }
  
  // Create a parser based on the receipt type
  BaseReceiptParser _createParser(String type) {
    switch (type) {
      case ReceiptClassifier.restaurant:
        return RestaurantReceiptParser();
      case ReceiptClassifier.gas:
        return GasReceiptParser();
      case ReceiptClassifier.retail:
      default:
        return RetailReceiptParser();
    }
  }
  
  // Get a map of all extracted data
  Map<String, dynamic> getAllData() {
    final data = <String, dynamic>{
      'merchantName': merchantName,
      'merchantAddress': merchantAddress,
      'transactionDate': transactionDate,
      'amount': amount,
      'currency': currency,
      'receiptType': receiptType,
      'confidenceScore': confidenceScore,
    };
    
    // Add additional fields if available
    if (additionalFields != null) {
      data.addAll(additionalFields!);
    }
    
    return data;
  }
}
