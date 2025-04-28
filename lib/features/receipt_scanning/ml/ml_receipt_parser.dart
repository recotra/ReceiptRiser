import 'dart:async';
import '../enhanced_receipt_parser.dart';
import 'entity_extraction_service.dart';
import 'receipt_classifier_ml.dart';
import 'receipt_learning_service.dart';

/// An enhanced receipt parser that uses machine learning techniques
class MLReceiptParser {
  final EnhancedReceiptParser _baseParser;
  final EntityExtractionService _entityExtractor;
  final ReceiptLearningService _learningService;
  bool _isInitialized = false;
  
  // Extracted receipt data
  String? merchantName;
  String? merchantAddress;
  DateTime? transactionDate;
  double? amount;
  String? currency;
  Map<String, dynamic>? additionalFields;
  String receiptType = 'unknown';
  double confidenceScore = 0.0;
  
  // Suggestions based on learning
  Map<String, List<String>> suggestions = {};
  
  MLReceiptParser() 
    : _baseParser = EnhancedReceiptParser(),
      _entityExtractor = EntityExtractionService(),
      _learningService = ReceiptLearningService();
  
  /// Initialize the parser and its components
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      // Initialize entity extractor
      final entityExtractorInitialized = await _entityExtractor.initialize();
      
      _isInitialized = entityExtractorInitialized;
      return _isInitialized;
    } catch (e) {
      print('Error initializing ML receipt parser: $e');
      return false;
    }
  }
  
  /// Parse the recognized text from the receipt
  Future<void> parseReceiptText(String text) async {
    // Initialize if not already done
    if (!_isInitialized) {
      await initialize();
    }
    
    // Use the ML classifier for receipt type
    receiptType = ReceiptClassifierML.classifyReceipt(text);
    
    // Use the base parser for initial extraction
    _baseParser.parseReceiptText(text);
    
    // Extract entities using ML Kit
    final extractedEntities = await _entityExtractor.extractReceiptEntities(text);
    
    // Combine results from base parser and entity extraction
    merchantName = _baseParser.merchantName;
    merchantAddress = _baseParser.merchantAddress ?? extractedEntities['merchantAddress'];
    
    // For dates, prefer the entity extraction if available
    if (extractedEntities.containsKey('transactionDate')) {
      try {
        final dateStr = extractedEntities['transactionDate'];
        final date = DateTime.parse(dateStr);
        transactionDate = date;
      } catch (e) {
        transactionDate = _baseParser.transactionDate;
      }
    } else {
      transactionDate = _baseParser.transactionDate;
    }
    
    // For amounts, prefer the entity extraction if available
    if (extractedEntities.containsKey('amount')) {
      amount = extractedEntities['amount'];
    } else {
      amount = _baseParser.amount;
    }
    
    currency = _baseParser.currency;
    
    // Combine additional fields
    additionalFields = _baseParser.additionalFields ?? {};
    if (extractedEntities.containsKey('phoneNumber')) {
      additionalFields!['phoneNumber'] = extractedEntities['phoneNumber'];
    }
    if (extractedEntities.containsKey('email')) {
      additionalFields!['email'] = extractedEntities['email'];
    }
    
    // Calculate confidence score
    _calculateConfidenceScore();
    
    // Get suggestions from learning service
    await _getSuggestions(text);
  }
  
  /// Calculate confidence score based on extracted fields
  void _calculateConfidenceScore() {
    int fieldsExtracted = 0;
    int totalFields = 4; // merchantName, merchantAddress, transactionDate, amount
    
    if (merchantName != null && merchantName!.isNotEmpty) fieldsExtracted++;
    if (merchantAddress != null && merchantAddress!.isNotEmpty) fieldsExtracted++;
    if (transactionDate != null) fieldsExtracted++;
    if (amount != null) fieldsExtracted++;
    
    // Base confidence score
    confidenceScore = fieldsExtracted / totalFields;
    
    // Adjust based on receipt type
    if (receiptType != 'unknown') {
      confidenceScore += 0.1; // Bonus for identified receipt type
    }
    
    // Cap at 1.0
    if (confidenceScore > 1.0) {
      confidenceScore = 1.0;
    }
  }
  
  /// Get suggestions from learning service
  Future<void> _getSuggestions(String text) async {
    suggestions = {};
    
    // Get suggestions for each field
    suggestions['merchantName'] = await _learningService.getSuggestions(
      text, 'merchantName', merchantName);
      
    suggestions['merchantAddress'] = await _learningService.getSuggestions(
      text, 'merchantAddress', merchantAddress);
      
    suggestions['amount'] = await _learningService.getSuggestions(
      text, 'amount', amount);
  }
  
  /// Store a correction made by the user
  Future<void> storeCorrection(
    String originalText,
    String field,
    dynamic originalValue,
    dynamic correctedValue,
  ) async {
    await _learningService.storeCorrection(
      originalText, field, originalValue, correctedValue);
  }
  
  /// Get a map of all extracted data
  Map<String, dynamic> getAllData() {
    final data = <String, dynamic>{
      'merchantName': merchantName,
      'merchantAddress': merchantAddress,
      'transactionDate': transactionDate,
      'amount': amount,
      'currency': currency,
      'receiptType': receiptType,
      'confidenceScore': confidenceScore,
      'suggestions': suggestions,
    };
    
    // Add additional fields if available
    if (additionalFields != null) {
      data.addAll(additionalFields!);
    }
    
    return data;
  }
  
  /// Close resources when done
  void close() {
    _entityExtractor.close();
  }
}
