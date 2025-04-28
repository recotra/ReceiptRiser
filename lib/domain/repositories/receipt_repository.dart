import '../entities/receipt.dart';

abstract class ReceiptRepository {
  Future<List<Receipt>> getReceipts();
  Future<Receipt?> getReceiptById(String id);
  Future<void> saveReceipt(Receipt receipt);
  Future<void> updateReceipt(Receipt receipt);
  Future<void> deleteReceipt(String id);
}
