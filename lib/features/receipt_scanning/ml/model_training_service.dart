import 'dart:math';
import 'training_data_storage.dart';

/// A service for training machine learning models on-device
class ModelTrainingService {
  final TrainingDataStorage _trainingDataStorage;
  
  // Trained models for different fields
  final Map<String, FieldModel> _fieldModels = {};
  
  // Training status
  bool _isTraining = false;
  double _trainingProgress = 0.0;
  String _trainingStatus = '';
  
  ModelTrainingService({TrainingDataStorage? trainingDataStorage})
      : _trainingDataStorage = trainingDataStorage ?? TrainingDataStorage();
  
  /// Get the training status
  bool get isTraining => _isTraining;
  double get trainingProgress => _trainingProgress;
  String get trainingStatus => _trainingStatus;
  
  /// Train models for all fields
  Future<bool> trainModels() async {
    if (_isTraining) {
      return false; // Already training
    }
    
    _isTraining = true;
    _trainingProgress = 0.0;
    _trainingStatus = 'Loading training data...';
    
    try {
      // Get all training examples
      final trainingExamples = await _trainingDataStorage.getTrainingExamples();
      
      if (trainingExamples.isEmpty) {
        _trainingStatus = 'No training data available';
        _isTraining = false;
        return false;
      }
      
      // Identify all fields in the training data
      final fields = <String>{};
      for (final example in trainingExamples) {
        final labels = example['labels'] as Map<String, dynamic>;
        fields.addAll(labels.keys);
      }
      
      // Train a model for each field
      int fieldIndex = 0;
      for (final field in fields) {
        _trainingStatus = 'Training model for $field...';
        _trainingProgress = fieldIndex / fields.length;
        
        // Get training examples for this field
        final fieldExamples = await _trainingDataStorage.getTrainingExamplesForField(field);
        
        if (fieldExamples.isNotEmpty) {
          // Train the model
          final model = await _trainFieldModel(field, fieldExamples);
          _fieldModels[field] = model;
        }
        
        fieldIndex++;
      }
      
      _trainingStatus = 'Training complete';
      _trainingProgress = 1.0;
      _isTraining = false;
      return true;
    } catch (e) {
      _trainingStatus = 'Error during training: $e';
      _isTraining = false;
      return false;
    }
  }
  
  /// Train a model for a specific field
  Future<FieldModel> _trainFieldModel(String field, List<Map<String, dynamic>> examples) async {
    // Create a new model
    final model = FieldModel(field);
    
    // Extract features and labels
    for (final example in examples) {
      final text = example['text'] as String;
      final labels = example['labels'] as Map<String, dynamic>;
      
      if (labels.containsKey(field) && labels[field] != null) {
        final label = labels[field].toString();
        
        // Extract features from the text
        final features = _extractFeatures(text, field);
        
        // Add to the model
        model.addExample(features, label);
      }
    }
    
    // Train the model
    model.train();
    
    return model;
  }
  
  /// Extract features from text for a specific field
  Map<String, double> _extractFeatures(String text, String field) {
    final features = <String, double>{};
    
    // Normalize text
    final normalizedText = text.toLowerCase();
    
    // Different feature extraction strategies based on field type
    switch (field) {
      case 'merchantName':
        _extractMerchantNameFeatures(normalizedText, features);
        break;
      case 'amount':
        _extractAmountFeatures(normalizedText, features);
        break;
      case 'transactionDate':
        _extractDateFeatures(normalizedText, features);
        break;
      case 'merchantAddress':
        _extractAddressFeatures(normalizedText, features);
        break;
      default:
        _extractGenericFeatures(normalizedText, features);
    }
    
    return features;
  }
  
  /// Extract features for merchant name
  void _extractMerchantNameFeatures(String text, Map<String, double> features) {
    // Extract n-grams from the first few lines
    final lines = text.split('\n');
    final topLines = lines.take(min(5, lines.length)).join(' ');
    
    // Add word n-grams
    _addNGrams(topLines, features, prefix: 'top_');
    
    // Check for common merchant name indicators
    if (text.contains('store') || text.contains('shop')) {
      features['is_store'] = 1.0;
    }
    if (text.contains('restaurant') || text.contains('cafe')) {
      features['is_restaurant'] = 1.0;
    }
    if (text.contains('gas') || text.contains('fuel')) {
      features['is_gas'] = 1.0;
    }
  }
  
  /// Extract features for amount
  void _extractAmountFeatures(String text, Map<String, double> features) {
    // Look for lines with currency symbols or amount keywords
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      
      if (line.contains(r'$') || 
          line.contains('total') || 
          line.contains('amount') || 
          line.contains('due') ||
          line.contains('pay')) {
        features['has_amount_line_$i'] = 1.0;
        
        // Add n-grams from this line
        _addNGrams(line, features, prefix: 'amount_line_');
      }
      
      // Check for number patterns
      if (RegExp(r'\d+\.\d{2}').hasMatch(line)) {
        features['has_decimal_number_$i'] = 1.0;
      }
    }
  }
  
  /// Extract features for transaction date
  void _extractDateFeatures(String text, Map<String, double> features) {
    // Look for lines with date patterns or date keywords
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      
      if (line.contains('date') || 
          line.contains(RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}'))) {
        features['has_date_line_$i'] = 1.0;
        
        // Add n-grams from this line
        _addNGrams(line, features, prefix: 'date_line_');
      }
    }
  }
  
  /// Extract features for merchant address
  void _extractAddressFeatures(String text, Map<String, double> features) {
    // Look for lines with address patterns
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      
      if (line.contains(RegExp(r'\d+\s+[A-Za-z]+')) || // Street number and name
          line.contains(RegExp(r'[A-Za-z]+,\s*[A-Za-z]{2}')) || // City, State
          line.contains(RegExp(r'\d{5}(-\d{4})?'))) { // ZIP code
        features['has_address_line_$i'] = 1.0;
        
        // Add n-grams from this line
        _addNGrams(line, features, prefix: 'address_line_');
      }
    }
  }
  
  /// Extract generic features
  void _extractGenericFeatures(String text, Map<String, double> features) {
    // Add word n-grams from the entire text
    _addNGrams(text, features);
    
    // Add character n-grams
    _addCharNGrams(text, features);
  }
  
  /// Add word n-grams to features
  void _addNGrams(String text, Map<String, double> features, {String prefix = ''}) {
    // Tokenize
    final tokens = text.split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    
    // Add unigrams
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final featureKey = '${prefix}unigram_$token';
      features[featureKey] = (features[featureKey] ?? 0.0) + 1.0;
    }
    
    // Add bigrams
    for (int i = 0; i < tokens.length - 1; i++) {
      final bigram = '${tokens[i]}_${tokens[i + 1]}';
      final featureKey = '${prefix}bigram_$bigram';
      features[featureKey] = (features[featureKey] ?? 0.0) + 1.0;
    }
  }
  
  /// Add character n-grams to features
  void _addCharNGrams(String text, Map<String, double> features, {String prefix = ''}) {
    // Add character trigrams
    for (int i = 0; i < text.length - 2; i++) {
      final trigram = text.substring(i, i + 3);
      final featureKey = '${prefix}char_trigram_$trigram';
      features[featureKey] = (features[featureKey] ?? 0.0) + 1.0;
    }
  }
  
  /// Predict a value for a field using the trained model
  String? predictField(String field, String text) {
    if (!_fieldModels.containsKey(field)) {
      return null; // No model for this field
    }
    
    final model = _fieldModels[field]!;
    final features = _extractFeatures(text, field);
    
    return model.predict(features);
  }
  
  /// Get the confidence score for a prediction
  double getPredictionConfidence(String field, String text) {
    if (!_fieldModels.containsKey(field)) {
      return 0.0; // No model for this field
    }
    
    final model = _fieldModels[field]!;
    final features = _extractFeatures(text, field);
    
    return model.getConfidence(features);
  }
  
  /// Get all field models
  Map<String, FieldModel> get fieldModels => _fieldModels;
  
  /// Check if a model exists for a field
  bool hasModelForField(String field) => _fieldModels.containsKey(field);
  
  /// Get the number of training examples for a field
  int getTrainingExampleCount(String field) {
    if (!_fieldModels.containsKey(field)) {
      return 0;
    }
    
    return _fieldModels[field]!.exampleCount;
  }
}

/// A simple model for a specific field
class FieldModel {
  final String field;
  final Map<String, Map<String, double>> _examples = {};
  final Map<String, int> _labelCounts = {};
  int _totalExamples = 0;
  
  // Trained model parameters
  final Map<String, Map<String, double>> _featureWeights = {};
  String? _defaultLabel;
  
  FieldModel(this.field);
  
  /// Add a training example
  void addExample(Map<String, double> features, String label) {
    // Store the example
    _examples[_totalExamples.toString()] = features;
    
    // Update label counts
    _labelCounts[label] = (_labelCounts[label] ?? 0) + 1;
    
    _totalExamples++;
  }
  
  /// Train the model
  void train() {
    // Find the most common label (for default prediction)
    int maxCount = 0;
    for (final entry in _labelCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        _defaultLabel = entry.key;
      }
    }
    
    // Calculate feature weights for each label
    for (final label in _labelCounts.keys) {
      final labelWeights = <String, double>{};
      
      // Count feature occurrences for this label
      final featureCounts = <String, double>{};
      int labelExampleCount = 0;
      
      for (final exampleEntry in _examples.entries) {
        final exampleFeatures = exampleEntry.value;
        final exampleId = exampleEntry.key;
        
        // Check if this example has the current label
        bool hasLabel = false;
        for (final otherExampleId in _examples.keys) {
          if (otherExampleId == exampleId) {
            hasLabel = true;
            break;
          }
        }
        
        if (hasLabel) {
          labelExampleCount++;
          
          // Update feature counts
          for (final featureEntry in exampleFeatures.entries) {
            final feature = featureEntry.key;
            final value = featureEntry.value;
            
            featureCounts[feature] = (featureCounts[feature] ?? 0.0) + value;
          }
        }
      }
      
      // Calculate weights (TF-IDF like)
      for (final featureEntry in featureCounts.entries) {
        final feature = featureEntry.key;
        final count = featureEntry.value;
        
        // Calculate weight
        final weight = count / labelExampleCount;
        
        labelWeights[feature] = weight;
      }
      
      _featureWeights[label] = labelWeights;
    }
  }
  
  /// Predict the label for a new example
  String? predict(Map<String, double> features) {
    if (_featureWeights.isEmpty) {
      return _defaultLabel;
    }
    
    // Calculate score for each label
    final scores = <String, double>{};
    
    for (final labelEntry in _featureWeights.entries) {
      final label = labelEntry.key;
      final weights = labelEntry.value;
      
      double score = 0.0;
      
      // Calculate dot product of features and weights
      for (final featureEntry in features.entries) {
        final feature = featureEntry.key;
        final value = featureEntry.value;
        
        if (weights.containsKey(feature)) {
          score += value * weights[feature]!;
        }
      }
      
      scores[label] = score;
    }
    
    // Find label with highest score
    String? bestLabel;
    double bestScore = double.negativeInfinity;
    
    for (final scoreEntry in scores.entries) {
      final label = scoreEntry.key;
      final score = scoreEntry.value;
      
      if (score > bestScore) {
        bestScore = score;
        bestLabel = label;
      }
    }
    
    return bestLabel ?? _defaultLabel;
  }
  
  /// Get the confidence score for a prediction
  double getConfidence(Map<String, double> features) {
    if (_featureWeights.isEmpty) {
      return 0.0;
    }
    
    // Calculate score for each label
    final scores = <String, double>{};
    
    for (final labelEntry in _featureWeights.entries) {
      final label = labelEntry.key;
      final weights = labelEntry.value;
      
      double score = 0.0;
      
      // Calculate dot product of features and weights
      for (final featureEntry in features.entries) {
        final feature = featureEntry.key;
        final value = featureEntry.value;
        
        if (weights.containsKey(feature)) {
          score += value * weights[feature]!;
        }
      }
      
      scores[label] = score;
    }
    
    // Find highest and second highest scores
    double highestScore = double.negativeInfinity;
    double secondHighestScore = double.negativeInfinity;
    
    for (final score in scores.values) {
      if (score > highestScore) {
        secondHighestScore = highestScore;
        highestScore = score;
      } else if (score > secondHighestScore) {
        secondHighestScore = score;
      }
    }
    
    // Calculate confidence as the difference between highest and second highest
    if (highestScore == double.negativeInfinity) {
      return 0.0;
    }
    
    if (secondHighestScore == double.negativeInfinity) {
      return 1.0; // Only one label
    }
    
    // Normalize to [0, 1]
    double confidence = (highestScore - secondHighestScore) / (highestScore + 1e-10);
    return min(1.0, max(0.0, confidence));
  }
  
  /// Get the number of training examples
  int get exampleCount => _totalExamples;
}
