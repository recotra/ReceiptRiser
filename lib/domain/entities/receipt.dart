import 'package:equatable/equatable.dart';

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
