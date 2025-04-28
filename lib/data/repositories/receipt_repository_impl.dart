import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class ReceiptRepositoryImpl implements ReceiptRepository {
  static const String tableName = 'receipts';
  static Database? _database;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'receipt_riser.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName(
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            merchantName TEXT NOT NULL,
            merchantAddress TEXT,
            transactionDate INTEGER NOT NULL,
            amount REAL NOT NULL,
            currency TEXT,
            category TEXT,
            imageUrl TEXT,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER
          )
        ''');
      },
    );
  }

  @override
  Future<List<Receipt>> getReceipts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return List.generate(maps.length, (i) => Receipt.fromMap(maps[i]));
  }

  @override
  Future<Receipt?> getReceiptById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Receipt.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<void> saveReceipt(Receipt receipt) async {
    final db = await database;
    await db.insert(
      tableName,
      receipt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateReceipt(Receipt receipt) async {
    final db = await database;
    await db.update(
      tableName,
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  @override
  Future<void> deleteReceipt(String id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get all receipts (for sync)
  Future<List<Receipt>> getAllReceipts() async {
    return await getReceipts();
  }
}
