import '../models/sale.dart';
import 'database_helper.dart';
import 'product_service.dart';

class SalesService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ProductService _productService = ProductService();

  // Create a new sale
  Future<Sale> createSale({
    required int customerId,
    required List<Map<String, dynamic>> items,
    double discount = 0.0,
    double taxRate = 0.0,
    String? paymentMethod,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    // Calculate totals
    double subtotal = 0.0;
    for (var item in items) {
      subtotal += (item['quantity'] * item['unit_price']);
    }

    final tax = (subtotal - discount) * (taxRate / 100);
    final total = subtotal - discount + tax;

    // Generate invoice number
    final invoiceNumber = await _generateInvoiceNumber();

    // Insert sale
    final saleId = await db.insert('sales', {
      'shop_id': 1,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'sale_date': now.toIso8601String(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod ?? 'cash',
      'payment_status': 'paid',
      'notes': notes,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // Insert sale items and update stock
    for (var item in items) {
      final itemSubtotal = item['quantity'] * item['unit_price'];
      final itemTotal = itemSubtotal; // Can add item-level discounts/taxes later

      await db.insert('sale_items', {
        'sale_id': saleId,
        'product_id': item['product_id'],
        'variant_id': item['variant_id'],
        'product_name': item['product_name'],
        'variant_name': item['variant_name'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'subtotal': itemSubtotal,
        'discount': 0.0,
        'tax': 0.0,
        'total': itemTotal,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Update stock if variant tracks inventory
      if (item['variant_id'] != null && item['track_inventory'] == true) {
        await _productService.updateVariantStock(
          item['variant_id'],
          -item['quantity'],
        );
      }
    }

    return (await getSaleById(saleId))!;
  }

  // Get sale by ID
  Future<Sale?> getSaleById(int id) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final saleMap = maps.first;
    final items = await _getSaleItems(db, id);

    return Sale(
      id: saleMap['id'],
      shopId: saleMap['shop_id'],
      invoiceNumber: saleMap['invoice_number'],
      customerId: saleMap['customer_id'],
      saleDate: DateTime.parse(saleMap['sale_date']),
      subtotal: saleMap['subtotal'],
      discount: saleMap['discount'] ?? 0.0,
      tax: saleMap['tax'] ?? 0.0,
      total: saleMap['total'],
      paymentMethod: saleMap['payment_method'],
      paymentStatus: saleMap['payment_status'],
      notes: saleMap['notes'],
      metadata: _dbHelper.decodeJson(saleMap['metadata']),
      createdAt: DateTime.parse(saleMap['created_at']),
      updatedAt: DateTime.parse(saleMap['updated_at']),
      items: items,
    );
  }

  // Get all sales with optional filters
  Future<List<Sale>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    int? customerId,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause = 'WHERE sale_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause = whereClause.isEmpty
          ? 'WHERE sale_date <= ?'
          : '$whereClause AND sale_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (customerId != null) {
      whereClause = whereClause.isEmpty
          ? 'WHERE customer_id = ?'
          : '$whereClause AND customer_id = ?';
      whereArgs.add(customerId);
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM sales
      $whereClause
      ORDER BY sale_date DESC, id DESC
      LIMIT ?
    ''', [...whereArgs, limit]);

    List<Sale> sales = [];
    for (var saleMap in maps) {
      final items = await _getSaleItems(db, saleMap['id']);

      sales.add(Sale(
        id: saleMap['id'],
        shopId: saleMap['shop_id'],
        invoiceNumber: saleMap['invoice_number'],
        customerId: saleMap['customer_id'],
        saleDate: DateTime.parse(saleMap['sale_date']),
        subtotal: saleMap['subtotal'],
        discount: saleMap['discount'] ?? 0.0,
        tax: saleMap['tax'] ?? 0.0,
        total: saleMap['total'],
        paymentMethod: saleMap['payment_method'],
        paymentStatus: saleMap['payment_status'],
        notes: saleMap['notes'],
        metadata: _dbHelper.decodeJson(saleMap['metadata']),
        createdAt: DateTime.parse(saleMap['created_at']),
        updatedAt: DateTime.parse(saleMap['updated_at']),
        items: items,
      ));
    }

    return sales;
  }

  // Get today's sales
  Future<List<Sale>> getTodaySales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return await getSales(startDate: startOfDay, endDate: endOfDay);
  }

  // Get sales summary for a date range
  Future<Map<String, dynamic>> getSalesSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause = 'WHERE sale_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause = whereClause.isEmpty
          ? 'WHERE sale_date <= ?'
          : '$whereClause AND sale_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_sales,
        SUM(subtotal) as total_subtotal,
        SUM(discount) as total_discount,
        SUM(tax) as total_tax,
        SUM(total) as total_revenue
      FROM sales
      $whereClause
    ''', whereArgs);

    final row = result.first;

    return {
      'total_sales': row['total_sales'] ?? 0,
      'total_subtotal': row['total_subtotal'] ?? 0.0,
      'total_discount': row['total_discount'] ?? 0.0,
      'total_tax': row['total_tax'] ?? 0.0,
      'total_revenue': row['total_revenue'] ?? 0.0,
    };
  }

  // Delete sale (with stock adjustment)
  Future<void> deleteSale(int id) async {
    final db = await _dbHelper.database;

    // Get sale items to adjust stock
    final items = await _getSaleItems(db, id);

    // Restore stock for each item
    for (var item in items) {
      if (item.variantId != null) {
        await _productService.updateVariantStock(
          item.variantId!,
          item.quantity, // Add back the quantity
        );
      }
    }

    // Delete sale (cascade will delete items)
    await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  // Private helper to get sale items
  Future<List<SaleItem>> _getSaleItems(db, int saleId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );

    return List.generate(maps.length, (i) {
      return SaleItem(
        id: maps[i]['id'],
        saleId: maps[i]['sale_id'],
        productId: maps[i]['product_id'],
        variantId: maps[i]['variant_id'],
        productName: maps[i]['product_name'],
        variantName: maps[i]['variant_name'],
        quantity: maps[i]['quantity'],
        unitPrice: maps[i]['unit_price'],
        subtotal: maps[i]['subtotal'],
        discount: maps[i]['discount'] ?? 0.0,
        tax: maps[i]['tax'] ?? 0.0,
        total: maps[i]['total'],
        createdAt: DateTime.parse(maps[i]['created_at']),
        updatedAt: DateTime.parse(maps[i]['updated_at']),
      );
    });
  }

  // Generate unique invoice number
  Future<String> _generateInvoiceNumber() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final prefix = 'INV${now.year}${now.month.toString().padLeft(2, '0')}';

    // Get the last invoice number for this month
    final result = await db.rawQuery('''
      SELECT invoice_number FROM sales
      WHERE invoice_number LIKE ?
      ORDER BY id DESC
      LIMIT 1
    ''', ['$prefix%']);

    if (result.isEmpty) {
      return '${prefix}0001';
    }

    final lastInvoice = result.first['invoice_number'] as String;
    final lastNumber = int.parse(lastInvoice.substring(prefix.length));
    final newNumber = lastNumber + 1;

    return '$prefix${newNumber.toString().padLeft(4, '0')}';
  }
}
