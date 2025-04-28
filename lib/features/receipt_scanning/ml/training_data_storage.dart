import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// A class to store and manage training data for on-device learning
class TrainingDataStorage {
  static const String _trainingDataKey = 'receipt_training_data';
  static const int _maxTrainingExamples = 200; // Maximum number of training examples to store
  
  /// Add a new training example
  /// 
  /// [text] is the receipt text
  /// [labels] is a map of field names to extracted values
  Future<void> addTrainingExample(String text, Map<String, dynamic> labels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing training data
      final trainingDataJson = prefs.getStringList(_trainingDataKey) ?? [];
      final trainingData = trainingDataJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      // Create new training example
      final example = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'text': text,
        'labels': labels,
        'textHash': _hashText(text),
      };
      
      // Check if we already have a similar example
      final similarExampleIndex = _findSimilarExample(trainingData, example);
      if (similarExampleIndex >= 0) {
        // Replace the similar example with the new one
        trainingData[similarExampleIndex] = example;
      } else {
        // Add to training data
        trainingData.add(example);
      }
      
      // Limit training data size
      if (trainingData.length > _maxTrainingExamples) {
        // Remove oldest examples, but keep a balanced dataset
        _balanceTrainingData(trainingData);
      }
      
      // Save back to preferences
      final updatedTrainingDataJson = trainingData
          .map((entry) => jsonEncode(entry))
          .toList();
      
      await prefs.setStringList(_trainingDataKey, updatedTrainingDataJson);
      
      // Also save to a file for larger datasets
      await _saveToFile(trainingData);
    } catch (e) {
      print('Error adding training example: $e');
    }
  }
  
  /// Get all training examples
  Future<List<Map<String, dynamic>>> getTrainingExamples() async {
    try {
      // First try to load from file (for larger datasets)
      final fileData = await _loadFromFile();
      if (fileData.isNotEmpty) {
        return fileData;
      }
      
      // Fall back to shared preferences
      final prefs = await SharedPreferences.getInstance();
      final trainingDataJson = prefs.getStringList(_trainingDataKey) ?? [];
      
      return trainingDataJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting training examples: $e');
      return [];
    }
  }
  
  /// Get training examples for a specific field
  Future<List<Map<String, dynamic>>> getTrainingExamplesForField(String field) async {
    final allExamples = await getTrainingExamples();
    
    return allExamples.where((example) {
      final labels = example['labels'] as Map<String, dynamic>;
      return labels.containsKey(field) && labels[field] != null;
    }).toList();
  }
  
  /// Clear all training data
  Future<void> clearTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trainingDataKey);
      
      // Also remove the file
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/receipt_training_data.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing training data: $e');
    }
  }
  
  /// Export training data to a file
  Future<String> exportTrainingData() async {
    try {
      final trainingData = await getTrainingExamples();
      final jsonData = jsonEncode(trainingData);
      
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/receipt_training_data_export.json');
      await file.writeAsString(jsonData);
      
      return file.path;
    } catch (e) {
      print('Error exporting training data: $e');
      return '';
    }
  }
  
  /// Import training data from a file
  Future<bool> importTrainingData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      
      final jsonData = await file.readAsString();
      final trainingData = jsonDecode(jsonData) as List<dynamic>;
      
      // Convert to the correct format
      final formattedData = trainingData
          .map((item) => item as Map<String, dynamic>)
          .toList();
      
      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      final trainingDataJson = formattedData
          .map((entry) => jsonEncode(entry))
          .toList();
      
      await prefs.setStringList(_trainingDataKey, trainingDataJson);
      
      // Also save to file
      await _saveToFile(formattedData);
      
      return true;
    } catch (e) {
      print('Error importing training data: $e');
      return false;
    }
  }
  
  /// Save training data to a file (for larger datasets)
  Future<void> _saveToFile(List<Map<String, dynamic>> trainingData) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/receipt_training_data.json');
      
      final jsonData = jsonEncode(trainingData);
      await file.writeAsString(jsonData);
    } catch (e) {
      print('Error saving training data to file: $e');
    }
  }
  
  /// Load training data from a file
  Future<List<Map<String, dynamic>>> _loadFromFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/receipt_training_data.json');
      
      if (!await file.exists()) {
        return [];
      }
      
      final jsonData = await file.readAsString();
      final trainingData = jsonDecode(jsonData) as List<dynamic>;
      
      return trainingData
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error loading training data from file: $e');
      return [];
    }
  }
  
  /// Find a similar example in the training data
  int _findSimilarExample(List<Map<String, dynamic>> trainingData, Map<String, dynamic> newExample) {
    final newTextHash = newExample['textHash'] as int;
    
    for (int i = 0; i < trainingData.length; i++) {
      final example = trainingData[i];
      final textHash = example['textHash'] as int;
      
      // If the hash matches, it's likely the same receipt
      if (textHash == newTextHash) {
        return i;
      }
    }
    
    return -1;
  }
  
  /// Balance the training data to keep a diverse dataset
  void _balanceTrainingData(List<Map<String, dynamic>> trainingData) {
    // Sort by timestamp (oldest first)
    trainingData.sort((a, b) => 
        (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    
    // Keep only the most recent examples
    while (trainingData.length > _maxTrainingExamples) {
      trainingData.removeAt(0); // Remove oldest
    }
  }
  
  /// Calculate a simple hash of the text for quick comparison
  int _hashText(String text) {
    // Remove whitespace and convert to uppercase for normalization
    final normalized = text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    
    // Simple hash function
    int hash = 0;
    for (int i = 0; i < normalized.length; i++) {
      hash = (hash * 31 + normalized.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    
    return hash;
  }
}
