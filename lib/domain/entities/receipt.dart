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
  final String? notes;
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
    this.notes,
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
    String? notes,
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
      notes: notes,
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
    String? notes,
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
      notes: notes ?? this.notes,
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
      'notes': notes,
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
      notes: map['notes'],
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
    notes,
    createdAt,
    updatedAt
  ];
}
