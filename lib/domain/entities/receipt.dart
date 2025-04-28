import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Receipt extends Equatable {
  final String id;
  final String userId;
  final String merchantName;
  final String? merchantAddress;
  final DateTime transactionDate;
  final double amount;
  final String? currency;
  final String? category;
  final String? imageUrl;
  final String? imagePath;
  final String? notes;
  final String? receiptType;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Receipt({
    required this.id,
    required this.userId,
    required this.merchantName,
    this.merchantAddress,
    required this.transactionDate,
    required this.amount,
    this.currency,
    this.category,
    this.imageUrl,
    this.imagePath,
    this.notes,
    this.receiptType,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create a new Receipt with a generated ID
  factory Receipt.create({
    required String userId,
    required String merchantName,
    String? merchantAddress,
    required DateTime transactionDate,
    required double amount,
    String? currency,
    String? category,
    String? imageUrl,
    String? imagePath,
    String? notes,
    String? receiptType,
  }) {
    final now = DateTime.now();
    return Receipt(
      id: const Uuid().v4(),
      userId: userId,
      merchantName: merchantName,
      merchantAddress: merchantAddress,
      transactionDate: transactionDate,
      amount: amount,
      currency: currency ?? 'USD',
      category: category,
      imageUrl: imageUrl,
      imagePath: imagePath,
      notes: notes,
      receiptType: receiptType ?? 'retail',
      createdAt: now,
      updatedAt: now,
    );
  }

  // Copy with method to create a new instance with updated fields
  Receipt copyWith({
    String? id,
    String? userId,
    String? merchantName,
    String? merchantAddress,
    DateTime? transactionDate,
    double? amount,
    String? currency,
    String? category,
    String? imageUrl,
    String? imagePath,
    String? notes,
    String? receiptType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      merchantName: merchantName ?? this.merchantName,
      merchantAddress: merchantAddress ?? this.merchantAddress,
      transactionDate: transactionDate ?? this.transactionDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      receiptType: receiptType ?? this.receiptType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'merchantName': merchantName,
      'merchantAddress': merchantAddress,
      'transactionDate': transactionDate.millisecondsSinceEpoch,
      'amount': amount,
      'currency': currency,
      'category': category,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'notes': notes,
      'receiptType': receiptType,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  // Create Receipt from Map (from database)
  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'],
      userId: map['userId'],
      merchantName: map['merchantName'],
      merchantAddress: map['merchantAddress'],
      transactionDate: DateTime.fromMillisecondsSinceEpoch(map['transactionDate']),
      amount: map['amount'],
      currency: map['currency'],
      category: map['category'],
      imageUrl: map['imageUrl'],
      imagePath: map['imagePath'],
      notes: map['notes'],
      receiptType: map['receiptType'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    merchantName,
    merchantAddress,
    transactionDate,
    amount,
    currency,
    category,
    imageUrl,
    imagePath,
    notes,
    receiptType,
    createdAt,
    updatedAt
  ];
}
