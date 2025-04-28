import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/receipt.dart';
import '../../data/repositories/receipt_repository_impl.dart';
import '../../features/receipt_scanning/receipt_classifier.dart';
import '../../features/receipt_scanning/ml/receipt_learning_service.dart';

class ReceiptConfirmationScreen extends StatefulWidget {
  final File imageFile;
  final String recognizedText;
  final String? merchantName;
  final String? merchantAddress;
  final DateTime? transactionDate;
  final double? amount;
  final String? currency;
  final String receiptType;
  final Map<String, dynamic>? additionalFields;
  final double confidenceScore;
  final Map<String, List<String>>? suggestions;

  const ReceiptConfirmationScreen({
    super.key,
    required this.imageFile,
    required this.recognizedText,
    this.merchantName,
    this.merchantAddress,
    this.transactionDate,
    this.amount,
    this.currency,
    this.receiptType = ReceiptClassifier.retail,
    this.additionalFields,
    this.confidenceScore = 0.0,
    this.suggestions,
  });

  @override
  State<ReceiptConfirmationScreen> createState() => _ReceiptConfirmationScreenState();
}

class _ReceiptConfirmationScreenState extends State<ReceiptConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantNameController = TextEditingController();
  final _merchantAddressController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // Additional field controllers
  final _taxController = TextEditingController();
  final _tipController = TextEditingController();
  final _gallonsController = TextEditingController();
  final _pricePerGallonController = TextEditingController();

  // Learning service
  final _learningService = ReceiptLearningService();

  DateTime _transactionDate = DateTime.now();
  String _currency = 'USD';
  String _category = 'Uncategorized';
  String? _paymentMethod;
  String? _fuelType;
  bool _isSaving = false;

  final List<String> _categories = [
    'Uncategorized',
    'Groceries',
    'Dining',
    'Shopping',
    'Transportation',
    'Entertainment',
    'Utilities',
    'Healthcare',
    'Travel',
    'Business',
    'Other'
  ];

  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CNY'];

  final List<String> _paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'Visa',
    'MasterCard',
    'American Express',
    'Discover',
    'Apple Pay',
    'Google Pay',
    'Check',
    'Gift Card',
    'Other'
  ];

  final List<String> _fuelTypes = [
    'Regular',
    'Unleaded',
    'Premium',
    'Super',
    'Diesel',
    'E85',
    'Midgrade'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controllers with extracted data
    _merchantNameController.text = widget.merchantName ?? '';
    _merchantAddressController.text = widget.merchantAddress ?? '';
    _amountController.text = widget.amount?.toString() ?? '';
    _transactionDate = widget.transactionDate ?? DateTime.now();
    _currency = widget.currency ?? 'USD';

    // Set category based on receipt type
    if (widget.receiptType == ReceiptClassifier.restaurant) {
      _category = 'Dining';
    } else if (widget.receiptType == ReceiptClassifier.gas) {
      _category = 'Transportation';
    }

    // Initialize additional fields if available
    if (widget.additionalFields != null) {
      final additionalFields = widget.additionalFields!;

      // Tax
      if (additionalFields['tax'] != null) {
        _taxController.text = additionalFields['tax'].toString();
      }

      // Tip (for restaurant receipts)
      if (additionalFields['tip'] != null) {
        _tipController.text = additionalFields['tip'].toString();
      }

      // Gallons (for gas receipts)
      if (additionalFields['gallons'] != null) {
        _gallonsController.text = additionalFields['gallons'].toString();
      }

      // Price per gallon (for gas receipts)
      if (additionalFields['pricePerGallon'] != null) {
        _pricePerGallonController.text = additionalFields['pricePerGallon'].toString();
      }

      // Payment method
      if (additionalFields['paymentMethod'] != null) {
        final extractedMethod = additionalFields['paymentMethod'].toString().toUpperCase();
        for (final method in _paymentMethods) {
          if (method.toUpperCase().contains(extractedMethod) ||
              extractedMethod.contains(method.toUpperCase())) {
            _paymentMethod = method;
            break;
          }
        }
      }

      // Fuel type (for gas receipts)
      if (additionalFields['fuelType'] != null) {
        final extractedType = additionalFields['fuelType'].toString().toUpperCase();
        for (final type in _fuelTypes) {
          if (type.toUpperCase().contains(extractedType) ||
              extractedType.contains(type.toUpperCase())) {
            _fuelType = type;
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _merchantNameController.dispose();
    _merchantAddressController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _taxController.dispose();
    _tipController.dispose();
    _gallonsController.dispose();
    _pricePerGallonController.dispose();
    super.dispose();
  }

  Future<void> _saveReceipt() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        // Create a new receipt
        final receipt = Receipt.create(
          userId: 'user123', // TODO: Replace with actual user ID from auth
          merchantName: _merchantNameController.text,
          merchantAddress: _merchantAddressController.text.isEmpty ? null : _merchantAddressController.text,
          transactionDate: _transactionDate,
          amount: double.parse(_amountController.text),
          currency: _currency,
          category: _category,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          // TODO: Save image to storage and get URL
          imageUrl: null,
        );

        // Save to database
        final repository = ReceiptRepositoryImpl();
        await repository.saveReceipt(receipt);

        // Store corrections for learning
        await _storeCorrections();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt saved successfully')),
          );
          Navigator.pop(context, true); // Return success
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving receipt: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  /// Store corrections for learning
  Future<void> _storeCorrections() async {
    // Store merchant name correction if changed
    if (widget.merchantName != _merchantNameController.text) {
      await _learningService.storeCorrection(
        widget.recognizedText,
        'merchantName',
        widget.merchantName,
        _merchantNameController.text,
      );
    }

    // Store merchant address correction if changed
    if (widget.merchantAddress != _merchantAddressController.text) {
      await _learningService.storeCorrection(
        widget.recognizedText,
        'merchantAddress',
        widget.merchantAddress,
        _merchantAddressController.text,
      );
    }

    // Store amount correction if changed
    if (widget.amount?.toString() != _amountController.text) {
      await _learningService.storeCorrection(
        widget.recognizedText,
        'amount',
        widget.amount,
        double.tryParse(_amountController.text),
      );
    }

    // Store date correction if changed
    if (widget.transactionDate != _transactionDate) {
      await _learningService.storeCorrection(
        widget.recognizedText,
        'transactionDate',
        widget.transactionDate,
        _transactionDate,
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _transactionDate) {
      setState(() {
        _transactionDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Receipt'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Receipt image
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.file(widget.imageFile, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 16),

                    // Merchant name with suggestions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _merchantNameController,
                          decoration: const InputDecoration(
                            labelText: 'Merchant Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter merchant name';
                            }
                            return null;
                          },
                        ),
                        if (widget.suggestions != null &&
                            widget.suggestions!.containsKey('merchantName') &&
                            widget.suggestions!['merchantName']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Wrap(
                              spacing: 8.0,
                              children: widget.suggestions!['merchantName']!.map((suggestion) {
                                return ActionChip(
                                  label: Text(suggestion),
                                  backgroundColor: Colors.blue.shade100,
                                  onPressed: () {
                                    setState(() {
                                      _merchantNameController.text = suggestion;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Merchant address with suggestions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _merchantAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Merchant Address (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (widget.suggestions != null &&
                            widget.suggestions!.containsKey('merchantAddress') &&
                            widget.suggestions!['merchantAddress']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Wrap(
                              spacing: 8.0,
                              children: widget.suggestions!['merchantAddress']!.map((suggestion) {
                                return ActionChip(
                                  label: Text(suggestion),
                                  backgroundColor: Colors.blue.shade100,
                                  onPressed: () {
                                    setState(() {
                                      _merchantAddressController.text = suggestion;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Transaction date
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Transaction Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMM dd, yyyy').format(_transactionDate)),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount and currency
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter amount';
                                  }
                                  try {
                                    double.parse(value);
                                  } catch (e) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              ),
                              if (widget.suggestions != null &&
                                  widget.suggestions!.containsKey('amount') &&
                                  widget.suggestions!['amount']!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Wrap(
                                    spacing: 8.0,
                                    children: widget.suggestions!['amount']!.map((suggestion) {
                                      return ActionChip(
                                        label: Text(suggestion),
                                        backgroundColor: Colors.blue.shade100,
                                        onPressed: () {
                                          setState(() {
                                            _amountController.text = suggestion;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _currency,
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                              border: OutlineInputBorder(),
                            ),
                            items: _currencies.map((String currency) {
                              return DropdownMenuItem<String>(
                                value: currency,
                                child: Text(currency),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _currency = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _category = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Additional fields based on receipt type
                    if (widget.receiptType == ReceiptClassifier.restaurant)
                      _buildRestaurantFields(),

                    if (widget.receiptType == ReceiptClassifier.gas)
                      _buildGasFields(),

                    if (widget.receiptType == ReceiptClassifier.retail)
                      _buildRetailFields(),

                    // Payment method
                    if (_paymentMethod != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                          ),
                          items: _paymentMethods.map((String method) {
                            return DropdownMenuItem<String>(
                              value: method,
                              child: Text(method),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _paymentMethod = newValue;
                              });
                            }
                          },
                        ),
                      ),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confidence score indicator
                    if (widget.confidenceScore > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Extraction Confidence: ${(widget.confidenceScore * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: _getConfidenceColor(widget.confidenceScore),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: widget.confidenceScore,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getConfidenceColor(widget.confidenceScore),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Recognized text (collapsible)
                    ExpansionTile(
                      title: const Text('Recognized Text'),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(widget.recognizedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveReceipt,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Save Receipt'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper method to get color based on confidence score
  Color _getConfidenceColor(double score) {
    if (score >= 0.8) {
      return Colors.green;
    } else if (score >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Build restaurant-specific fields
  Widget _buildRestaurantFields() {
    return Column(
      children: [
        // Tip field
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _tipController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tip Amount',
              border: OutlineInputBorder(),
            ),
          ),
        ),

        // Tax field
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _taxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tax Amount',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  // Build gas-specific fields
  Widget _buildGasFields() {
    return Column(
      children: [
        // Gallons field
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _gallonsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Gallons',
              border: OutlineInputBorder(),
            ),
          ),
        ),

        // Price per gallon field
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _pricePerGallonController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price per Gallon',
              border: OutlineInputBorder(),
            ),
          ),
        ),

        // Fuel type dropdown
        if (_fuelType != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              value: _fuelType,
              decoration: const InputDecoration(
                labelText: 'Fuel Type',
                border: OutlineInputBorder(),
              ),
              items: _fuelTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _fuelType = newValue;
                  });
                }
              },
            ),
          ),
      ],
    );
  }

  // Build retail-specific fields
  Widget _buildRetailFields() {
    return Column(
      children: [
        // Tax field
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _taxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tax Amount',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
