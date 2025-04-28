import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'model_training_service.dart';

/// A scheduler for periodic model training
class TrainingScheduler {
  static const String _lastTrainingTimeKey = 'last_model_training_time';
  static const Duration _trainingInterval = Duration(days: 1); // Train once a day
  static const int _minTrainingExamples = 10; // Minimum number of examples to trigger training
  
  final ModelTrainingService _trainingService;
  Timer? _scheduledTraining;
  
  TrainingScheduler({ModelTrainingService? trainingService})
      : _trainingService = trainingService ?? ModelTrainingService();
  
  /// Start the training scheduler
  void start() {
    // Schedule periodic check
    _scheduledTraining = Timer.periodic(Duration(hours: 1), (_) {
      _checkAndTrain();
    });
    
    // Also check immediately
    _checkAndTrain();
  }
  
  /// Stop the training scheduler
  void stop() {
    _scheduledTraining?.cancel();
    _scheduledTraining = null;
  }
  
  /// Check if training is needed and train if necessary
  Future<void> _checkAndTrain() async {
    try {
      // Check if we have enough training examples
      final exampleCount = await _getTrainingExampleCount();
      if (exampleCount < _minTrainingExamples) {
        return; // Not enough examples
      }
      
      // Check if it's time to train
      final lastTrainingTime = await _getLastTrainingTime();
      final now = DateTime.now();
      
      if (lastTrainingTime != null && 
          now.difference(lastTrainingTime) < _trainingInterval) {
        return; // Too soon to train again
      }
      
      // Check if device is in a good state for training
      if (!_isDeviceReadyForTraining()) {
        return; // Device not ready
      }
      
      // Train the models
      final success = await _trainingService.trainModels();
      
      if (success) {
        // Update last training time
        await _setLastTrainingTime(now);
      }
    } catch (e) {
      print('Error in training scheduler: $e');
    }
  }
  
  /// Get the last training time
  Future<DateTime?> _getLastTrainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastTrainingTimeKey);
    
    if (timestamp == null) {
      return null;
    }
    
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  
  /// Set the last training time
  Future<void> _setLastTrainingTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTrainingTimeKey, time.millisecondsSinceEpoch);
  }
  
  /// Get the number of training examples
  Future<int> _getTrainingExampleCount() async {
    // This is a placeholder - in a real implementation, you would
    // get this from the training data storage
    return 20; // Assume we have enough examples
  }
  
  /// Check if the device is ready for training
  bool _isDeviceReadyForTraining() {
    // In a real implementation, you would check:
    // - Battery level (e.g., > 20%)
    // - Device is charging
    // - Device is idle (e.g., screen off)
    // - Device is on Wi-Fi (not using mobile data)
    // - Device is not in power saving mode
    
    return true; // Assume device is ready
  }
  
  /// Force training now, regardless of schedule
  Future<bool> forceTrainNow() async {
    final success = await _trainingService.trainModels();
    
    if (success) {
      // Update last training time
      await _setLastTrainingTime(DateTime.now());
    }
    
    return success;
  }
  
  /// Get the training service
  ModelTrainingService get trainingService => _trainingService;
}
