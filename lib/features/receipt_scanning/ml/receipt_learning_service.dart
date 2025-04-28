import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A service that learns from user corrections to improve receipt parsing
class ReceiptLearningService {
  static const String _correctionHistoryKey = 'receipt_correction_history';
  static const int _maxHistorySize = 100; // Maximum number of corrections to store
  
  /// Store a correction made by the user
  /// 
  /// [originalText] is the original receipt text
  /// [originalField] is the field that was corrected (e.g., 'merchantName', 'amount')
  /// [originalValue] is the original extracted value
  /// [correctedValue] is the value after user correction
  Future<void> storeCorrection(
    String originalText,
    String originalField,
    dynamic originalValue,
    dynamic correctedValue,
  ) async {
    if (originalValue == correctedValue) {
      // No correction was made
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing correction history
      final historyJson = prefs.getStringList(_correctionHistoryKey) ?? [];
      final history = historyJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      // Create new correction entry
      final correction = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'field': originalField,
        'originalValue': originalValue?.toString() ?? '',
        'correctedValue': correctedValue?.toString() ?? '',
        'textHash': _hashText(originalText),
        'textSample': _extractRelevantTextSample(originalText, originalField),
      };
      
      // Add to history
      history.add(correction);
      
      // Limit history size
      if (history.length > _maxHistorySize) {
        history.removeAt(0); // Remove oldest entry
      }
      
      // Save back to preferences
      final updatedHistoryJson = history
          .map((entry) => jsonEncode(entry))
          .toList();
      
      await prefs.setStringList(_correctionHistoryKey, updatedHistoryJson);
    } catch (e) {
      print('Error storing correction: $e');
    }
  }
  
  /// Get correction suggestions for a field based on learning history
  /// 
  /// [text] is the receipt text
  /// [field] is the field to get suggestions for
  /// [extractedValue] is the currently extracted value
  /// 
  /// Returns a list of suggested values, sorted by relevance
  Future<List<String>> getSuggestions(
    String text,
    String field,
    dynamic extractedValue,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing correction history
      final historyJson = prefs.getStringList(_correctionHistoryKey) ?? [];
      if (historyJson.isEmpty) {
        return [];
      }
      
      final history = historyJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      // Filter corrections for the specified field
      final fieldCorrections = history
          .where((correction) => correction['field'] == field)
          .toList();
      
      if (fieldCorrections.isEmpty) {
        return [];
      }
      
      // Calculate similarity scores
      final textHash = _hashText(text);
      final textSample = _extractRelevantTextSample(text, field);
      
      final scoredSuggestions = <String, double>{};
      
      for (final correction in fieldCorrections) {
        final correctedValue = correction['correctedValue'] as String;
        final originalValue = correction['originalValue'] as String;
        final correctionTextHash = correction['textHash'] as int;
        final correctionTextSample = correction['textSample'] as String;
        
        // Skip if the corrected value is the same as the current extracted value
        if (correctedValue == extractedValue?.toString()) {
          continue;
        }
        
        // Calculate similarity score
        double score = 0.0;
        
        // Exact hash match is a strong signal
        if (textHash == correctionTextHash) {
          score += 10.0;
        }
        
        // Text sample similarity
        final sampleSimilarity = _calculateTextSimilarity(textSample, correctionTextSample);
        score += sampleSimilarity * 5.0;
        
        // If the original extracted value matches, that's a good signal
        if (originalValue == extractedValue?.toString()) {
          score += 3.0;
        }
        
        // Add or update score for this suggestion
        scoredSuggestions[correctedValue] = (scoredSuggestions[correctedValue] ?? 0.0) + score;
      }
      
      // Sort suggestions by score
      final sortedSuggestions = scoredSuggestions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      // Return top suggestions
      return sortedSuggestions
          .take(5)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      print('Error getting suggestions: $e');
      return [];
    }
  }
  
  /// Extract a relevant text sample around the field
  String _extractRelevantTextSample(String text, String field) {
    // Different extraction strategies based on field type
    switch (field) {
      case 'merchantName':
        // For merchant name, take the first few lines
        final lines = text.split('\n');
        return lines.take(5).join(' ');
        
      case 'amount':
        // For amount, look for lines containing total, amount, etc.
        final lines = text.split('\n');
        final relevantLines = lines.where((line) {
          final upperLine = line.toUpperCase();
          return upperLine.contains('TOTAL') || 
                 upperLine.contains('AMOUNT') || 
                 upperLine.contains('DUE') ||
                 upperLine.contains('PAY') ||
                 upperLine.contains('\$');
        }).toList();
        
        return relevantLines.join(' ');
        
      case 'transactionDate':
        // For date, look for lines containing date patterns
        final lines = text.split('\n');
        final relevantLines = lines.where((line) {
          return line.contains(RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}')) ||
                 line.toUpperCase().contains('DATE');
        }).toList();
        
        return relevantLines.join(' ');
        
      default:
        // For other fields, take a window of text from the middle
        if (text.length <= 200) {
          return text;
        }
        
        final middle = text.length ~/ 2;
        final start = middle - 100;
        final end = middle + 100;
        
        return text.substring(start, end);
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
  
  /// Calculate text similarity using Jaccard similarity of character trigrams
  double _calculateTextSimilarity(String text1, String text2) {
    // Convert to uppercase and remove non-alphanumeric characters
    final normalized1 = text1.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final normalized2 = text2.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    // Handle edge cases
    if (normalized1.isEmpty || normalized2.isEmpty) {
      return 0.0;
    }
    
    if (normalized1 == normalized2) {
      return 1.0;
    }
    
    // Generate character trigrams
    final trigrams1 = _generateTrigrams(normalized1);
    final trigrams2 = _generateTrigrams(normalized2);
    
    // Calculate Jaccard similarity
    final intersection = trigrams1.intersection(trigrams2);
    final union = trigrams1.union(trigrams2);
    
    return intersection.length / union.length;
  }
  
  /// Generate character trigrams from text
  Set<String> _generateTrigrams(String text) {
    if (text.length < 3) {
      return {text};
    }
    
    final trigrams = <String>{};
    for (int i = 0; i <= text.length - 3; i++) {
      trigrams.add(text.substring(i, i + 3));
    }
    
    return trigrams;
  }
  
  /// Clear all stored corrections (for testing or privacy)
  Future<void> clearCorrectionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_correctionHistoryKey);
    } catch (e) {
      print('Error clearing correction history: $e');
    }
  }
}
