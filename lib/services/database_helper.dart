import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'pos_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id INTEGER NOT NULL DEFAULT 1,
        sku TEXT,
        barcode TEXT,
        name TEXT NOT NULL,
        category_id INTEGER,
        description TEXT,
        unit TEXT DEFAULT 'pcs',
        is_service INTEGER DEFAULT 0,
        image_path TEXT,
        attributes TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create product_variants table
    await db.execute('''
      CREATE TABLE product_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        code TEXT,
        barcode TEXT,
        name TEXT,
        price REAL NOT NULL,
        cost_price REAL DEFAULT 0.0,
        track_inventory INTEGER DEFAULT 1,
        stock_quantity REAL DEFAULT 0.0,
        attributes TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        slug TEXT,
        parent_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        city TEXT,
        state TEXT,
        pincode TEXT,
        tax_id TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id INTEGER NOT NULL DEFAULT 1,
        invoice_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        sale_date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        total REAL NOT NULL,
        payment_method TEXT,
        payment_status TEXT DEFAULT 'paid',
        notes TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // Create sale_items table (no FK on product_id/variant_id to allow product deletion)
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        variant_id INTEGER,
        product_name TEXT NOT NULL,
        variant_name TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_variants_barcode ON product_variants(barcode)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');

    // Insert some sample data
    await _insertSampleData(db);
  }

  Future<void> _insertSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Categories
    await db.insert('categories', {
      'shop_id': 1,
      'name': 'General',
      'slug': 'general',
      'created_at': now,
      'updated_at': now,
    });

    final groceriesCat = await db.insert('categories', {
      'shop_id': 1,
      'name': 'Groceries',
      'slug': 'groceries',
      'created_at': now,
      'updated_at': now,
    });

    // Products
    final riceId = await db.insert('products', {
      'shop_id': 1,
      'name': 'Rice 1kg',
      'category_id': groceriesCat,
      'unit': 'kg',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('product_variants', {
      'product_id': riceId,
      'name': 'Default',
      'price': 50.0,
      'cost_price': 40.0,
      'stock_quantity': 100.0,
      'created_at': now,
      'updated_at': now,
    });

    final oilId = await db.insert('products', {
      'shop_id': 1,
      'name': 'Cooking Oil 1L',
      'category_id': groceriesCat,
      'unit': 'ltr',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('product_variants', {
      'product_id': oilId,
      'name': 'Default',
      'price': 120.0,
      'cost_price': 100.0,
      'stock_quantity': 50.0,
      'created_at': now,
      'updated_at': now,
    });

    // Customers
    await db.insert('customers', {
      'shop_id': 1,
      'name': 'Walk-in Customer',
      'phone': '0000000000',
      'created_at': now,
      'updated_at': now,
    });
  }

  // Helper method to encode JSON fields
  String? encodeJson(Map<String, dynamic>? data) {
    return data != null ? jsonEncode(data) : null;
  }

  // Helper method to decode JSON fields
  Map<String, dynamic>? decodeJson(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Clear all data
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('product_variants');
    await db.delete('products');
    await db.delete('categories');
    await db.delete('customers');
  }
}
