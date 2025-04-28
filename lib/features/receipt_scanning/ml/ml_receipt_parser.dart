import 'dart:async';
import '../enhanced_receipt_parser.dart';
import 'entity_extraction_service.dart';
import 'receipt_classifier_ml.dart';
import 'receipt_learning_service.dart';
import 'model_training_service.dart';
import 'training_data_storage.dart';
import 'training_scheduler.dart';

/// An enhanced receipt parser that uses machine learning techniques
class MLReceiptParser {
  final EnhancedReceiptParser _baseParser;
  final EntityExtractionService _entityExtractor;
  final ReceiptLearningService _learningService;
  final TrainingDataStorage _trainingDataStorage;
  final ModelTrainingService _modelTrainingService;
  final TrainingScheduler _trainingScheduler;
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

  // Training status
  bool get isTraining => _trainingScheduler.trainingService.isTraining;
  double get trainingProgress => _trainingScheduler.trainingService.trainingProgress;
  String get trainingStatus => _trainingScheduler.trainingService.trainingStatus;

  MLReceiptParser()
    : _baseParser = EnhancedReceiptParser(),
      _entityExtractor = EntityExtractionService(),
      _learningService = ReceiptLearningService(),
      _trainingDataStorage = TrainingDataStorage(),
      _modelTrainingService = ModelTrainingService(),
      _trainingScheduler = TrainingScheduler();

  /// Initialize the parser and its components
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Initialize entity extractor
      final entityExtractorInitialized = await _entityExtractor.initialize();

      // Start the training scheduler
      _trainingScheduler.start();

      _isInitialized = entityExtractorInitialized;
      return _isInitialized;
    } catch (e) {
      print('Error initializing ML receipt parser: $e');
      return false;
    }
  }

  /// Force training of models
  Future<bool> forceTraining() async {
    return await _trainingScheduler.forceTrainNow();
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

    // Try to use trained models for extraction
    final modelPredictions = _getPredictionsFromTrainedModels(text);

    // Combine results from all sources, prioritizing trained models
    merchantName = modelPredictions['merchantName'] ??
                   _baseParser.merchantName;

    merchantAddress = modelPredictions['merchantAddress'] ??
                      _baseParser.merchantAddress ??
                      extractedEntities['merchantAddress'];

    // For dates, try trained model first, then entity extraction, then base parser
    if (modelPredictions.containsKey('transactionDate')) {
      try {
        final dateStr = modelPredictions['transactionDate'];
        final date = DateTime.parse(dateStr);
        transactionDate = date;
      } catch (e) {
        // Fall back to entity extraction or base parser
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
      }
    } else if (extractedEntities.containsKey('transactionDate')) {
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

    // For amounts, try trained model first, then entity extraction, then base parser
    if (modelPredictions.containsKey('amount')) {
      try {
        final amountStr = modelPredictions['amount'];
        amount = double.parse(amountStr);
      } catch (e) {
        // Fall back to entity extraction or base parser
        amount = extractedEntities.containsKey('amount') ?
                extractedEntities['amount'] :
                _baseParser.amount;
      }
    } else {
      amount = extractedEntities.containsKey('amount') ?
              extractedEntities['amount'] :
              _baseParser.amount;
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

    // Add model confidence scores to additional fields
    if (modelPredictions.containsKey('confidenceScores')) {
      additionalFields!['modelConfidenceScores'] = modelPredictions['confidenceScores'];
    }

    // Calculate confidence score
    _calculateConfidenceScore();

    // Get suggestions from learning service
    await _getSuggestions(text);

    // Store this example for future training
    await _storeTrainingExample(text);
  }

  /// Get predictions from trained models
  Map<String, dynamic> _getPredictionsFromTrainedModels(String text) {
    final predictions = <String, dynamic>{};
    final confidenceScores = <String, double>{};

    // Check if we have trained models
    final modelTrainingService = _trainingScheduler.trainingService;

    // Try to predict each field
    for (final field in ['merchantName', 'merchantAddress', 'transactionDate', 'amount']) {
      if (modelTrainingService.hasModelForField(field)) {
        final prediction = modelTrainingService.predictField(field, text);
        final confidence = modelTrainingService.getPredictionConfidence(field, text);

        if (prediction != null && confidence > 0.5) { // Only use predictions with decent confidence
          predictions[field] = prediction;
          confidenceScores[field] = confidence;
        }
      }
    }

    // Add confidence scores
    if (confidenceScores.isNotEmpty) {
      predictions['confidenceScores'] = confidenceScores;
    }

    return predictions;
  }

  /// Store this example for future training
  Future<void> _storeTrainingExample(String text) async {
    // Only store examples with good data
    if (merchantName != null && amount != null) {
      final labels = <String, dynamic>{
        'merchantName': merchantName,
        'merchantAddress': merchantAddress,
        'transactionDate': transactionDate?.toIso8601String(),
        'amount': amount?.toString(),
        'currency': currency,
        'receiptType': receiptType,
      };

      await _trainingDataStorage.addTrainingExample(text, labels);
    }
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
    // Store in learning service for suggestions
    await _learningService.storeCorrection(
      originalText, field, originalValue, correctedValue);

    // Also store as a training example
    if (correctedValue != null) {
      final labels = <String, dynamic>{
        field: correctedValue.toString(),
      };

      await _trainingDataStorage.addTrainingExample(originalText, labels);

      // Consider triggering training if we have enough corrections
      if (_shouldTriggerTraining()) {
        // Train in the background
        forceTraining();
      }
    }
  }

  /// Determine if we should trigger training
  bool _shouldTriggerTraining() {
    // In a real implementation, you would check:
    // - Number of new examples since last training
    // - Time since last training
    // - Device state (battery, charging, etc.)

    // For now, return false to avoid training too frequently during testing
    return false;
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
    _trainingScheduler.stop();
  }

  /// Get training statistics
  Map<String, dynamic> getTrainingStats() {
    final modelTrainingService = _trainingScheduler.trainingService;
    final stats = <String, dynamic>{
      'isTraining': modelTrainingService.isTraining,
      'trainingProgress': modelTrainingService.trainingProgress,
      'trainingStatus': modelTrainingService.trainingStatus,
      'fieldModels': <String, dynamic>{},
    };

    // Add stats for each field model
    for (final field in ['merchantName', 'merchantAddress', 'transactionDate', 'amount']) {
      if (modelTrainingService.hasModelForField(field)) {
        stats['fieldModels'][field] = {
          'exampleCount': modelTrainingService.getTrainingExampleCount(field),
          'available': true,
        };
      } else {
        stats['fieldModels'][field] = {
          'exampleCount': 0,
          'available': false,
        };
      }
    }

    return stats;
  }
}
