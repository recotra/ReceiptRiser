import 'package:flutter/material.dart';
import '../../features/receipt_scanning/ml/ml_receipt_parser.dart';
import '../../features/receipt_scanning/ml/training_data_storage.dart';

class ModelTrainingScreen extends StatefulWidget {
  final MLReceiptParser mlParser;

  const ModelTrainingScreen({
    super.key,
    required this.mlParser,
  });

  @override
  State<ModelTrainingScreen> createState() => _ModelTrainingScreenState();
}

class _ModelTrainingScreenState extends State<ModelTrainingScreen> {
  final TrainingDataStorage _trainingDataStorage = TrainingDataStorage();
  bool _isLoading = false;
  int _trainingExampleCount = 0;
  Map<String, dynamic> _trainingStats = {};
  String _exportPath = '';
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get training examples
      final examples = await _trainingDataStorage.getTrainingExamples();
      
      // Get training stats
      final stats = widget.mlParser.getTrainingStats();

      setState(() {
        _trainingExampleCount = examples.length;
        _trainingStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _startTraining() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Start training
      final success = await widget.mlParser.forceTraining();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? 'Training started successfully' 
              : 'Failed to start training'),
          ),
        );
      }

      // Reload data
      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting training: $e')),
        );
      }
    }
  }

  Future<void> _exportTrainingData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Export training data
      final path = await _trainingDataStorage.exportTrainingData();

      setState(() {
        _exportPath = path;
        _isExporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path.isNotEmpty 
              ? 'Training data exported to: $path' 
              : 'Failed to export training data'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting training data: $e')),
        );
      }
    }
  }

  Future<void> _clearTrainingData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Training Data'),
        content: const Text(
          'Are you sure you want to clear all training data? '
          'This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Clear training data
      await _trainingDataStorage.clearTrainingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training data cleared')),
        );
      }

      // Reload data
      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing training data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Training'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Training data summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Training Data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Total examples: $_trainingExampleCount'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _exportTrainingData,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Export'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _clearTrainingData,
                                icon: const Icon(Icons.delete),
                                label: const Text('Clear'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Training status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Training Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTrainingStatus(),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startTraining,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Training'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Model details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Model Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildModelDetails(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTrainingStatus() {
    final isTraining = _trainingStats['isTraining'] as bool? ?? false;
    final progress = _trainingStats['trainingProgress'] as double? ?? 0.0;
    final status = _trainingStats['trainingStatus'] as String? ?? 'Not started';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status: $status'),
        const SizedBox(height: 8),
        if (isTraining) ...[
          const Text('Progress:'),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text('${(progress * 100).toStringAsFixed(1)}%'),
        ],
      ],
    );
  }

  Widget _buildModelDetails() {
    final fieldModels = _trainingStats['fieldModels'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in [
          'merchantName',
          'merchantAddress',
          'transactionDate',
          'amount',
        ])
          _buildFieldModelDetails(field, fieldModels[field] as Map<String, dynamic>? ?? {}),
      ],
    );
  }

  Widget _buildFieldModelDetails(String field, Map<String, dynamic> details) {
    final available = details['available'] as bool? ?? false;
    final exampleCount = details['exampleCount'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel,
            color: available ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              field,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text('Examples: $exampleCount'),
        ],
      ),
    );
  }
}
