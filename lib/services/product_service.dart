import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import 'database_helper.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Get all products with their variants (with pagination support)
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int perPage = 15,
    String? search,
    int? categoryId,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      whereClause = 'WHERE p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?';
      whereArgs = ['%$search%', '%$search%', '%$search%'];
    }

    if (categoryId != null) {
      whereClause = whereClause.isEmpty
          ? 'WHERE p.category_id = ?'
          : '$whereClause AND p.category_id = ?';
      whereArgs.add(categoryId);
    }

    final List<Map<String, dynamic>> productMaps = await db.rawQuery('''
      SELECT p.*, c.name as category_name, c.slug as category_slug
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      $whereClause
      ORDER BY p.name ASC
    ''', whereArgs);

    List<Product> products = [];
    for (var productMap in productMaps) {
      // Get variants for this product
      final variants = await _getVariantsByProductId(db, productMap['id']);

      // Parse category if exists
      Category? category;
      if (productMap['category_id'] != null) {
        category = Category(
          id: productMap['category_id'],
          shopId: productMap['shop_id'],
          name: productMap['category_name'] ?? '',
          slug: productMap['category_slug'],
          parentId: null,
          createdAt: DateTime.parse(productMap['created_at']),
          updatedAt: DateTime.parse(productMap['updated_at']),
        );
      }

      products.add(Product(
        id: productMap['id'] as int,
        shopId: productMap['shop_id'] as int,
        sku: productMap['sku'] as String?,
        barcode: productMap['barcode'] as String?,
        name: productMap['name'] as String,
        categoryId: productMap['category_id'] as int?,
        description: productMap['description'] as String?,
        unit: (productMap['unit'] as String?) ?? 'pcs',
        isService: productMap['is_service'] == 1,
        imagePath: productMap['image_path'] as String?,
        attributes: _dbHelper.decodeJson(productMap['attributes']),
        metadata: _dbHelper.decodeJson(productMap['metadata']),
        createdAt: DateTime.parse(productMap['created_at'] as String),
        updatedAt: DateTime.parse(productMap['updated_at'] as String),
        category: category,
        variants: variants,
      ));
    }

    // Return with pagination info for compatibility with API
    return {
      'products': products,
      'total': products.length,
      'current_page': 1,
      'last_page': 1,
    };
  }

  // Get product by ID
  Future<Product?> getProductById(int id) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final productMap = maps.first;
    final variants = await _getVariantsByProductId(db, id);

    return Product(
      id: productMap['id'] as int,
      shopId: productMap['shop_id'] as int,
      sku: productMap['sku'] as String?,
      barcode: productMap['barcode'] as String?,
      name: productMap['name'] as String,
      categoryId: productMap['category_id'] as int?,
      description: productMap['description'] as String?,
      unit: (productMap['unit'] as String?) ?? 'pcs',
      isService: productMap['is_service'] == 1,
      imagePath: productMap['image_path'] as String?,
      attributes: _dbHelper.decodeJson(productMap['attributes']),
      metadata: _dbHelper.decodeJson(productMap['metadata']),
      createdAt: DateTime.parse(productMap['created_at'] as String),
      updatedAt: DateTime.parse(productMap['updated_at'] as String),
      variants: variants,
    );
  }

  // Search product by barcode
  Future<Product?> searchByBarcode(String barcode) async {
    final db = await _dbHelper.database;

    // First check if barcode exists in products
    var maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (maps.isNotEmpty) {
      final productMap = maps.first;
      final variants = await _getVariantsByProductId(db, productMap['id'] as int);

      return Product(
        id: productMap['id'] as int,
        shopId: productMap['shop_id'] as int,
        sku: productMap['sku'] as String?,
        barcode: productMap['barcode'] as String?,
        name: productMap['name'] as String,
        categoryId: productMap['category_id'] as int?,
        description: productMap['description'] as String?,
        unit: (productMap['unit'] as String?) ?? 'pcs',
        isService: productMap['is_service'] == 1,
        imagePath: productMap['image_path'] as String?,
        attributes: _dbHelper.decodeJson(productMap['attributes']),
        metadata: _dbHelper.decodeJson(productMap['metadata']),
        createdAt: DateTime.parse(productMap['created_at'] as String),
        updatedAt: DateTime.parse(productMap['updated_at'] as String),
        variants: variants,
      );
    }

    // Check if barcode exists in variants
    final variantMaps = await db.query(
      'product_variants',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (variantMaps.isNotEmpty) {
      final variantMap = variantMaps.first;
      return await getProductById(variantMap['product_id'] as int);
    }

    return null;
  }

  // Create product
  Future<Product> createProduct(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('products', {
      'shop_id': 1, // Default shop ID for offline mode
      'sku': data['sku'],
      'barcode': data['barcode'],
      'name': data['name'],
      'category_id': data['category_id'],
      'description': data['description'],
      'unit': data['unit'] ?? 'pcs',
      'is_service': data['is_service'] == true ? 1 : 0,
      'image_path': data['image_path'],
      'attributes': _dbHelper.encodeJson(null),
      'metadata': _dbHelper.encodeJson(null),
      'created_at': now,
      'updated_at': now,
    });

    // Create default variant if variants provided
    if (data['variants'] != null && (data['variants'] as List).isNotEmpty) {
      for (var variant in (data['variants'] as List)) {
        await db.insert('product_variants', {
          'product_id': id,
          'code': null,
          'barcode': variant['barcode'],
          'name': variant['name'] ?? 'Default',
          'price': variant['price'],
          'cost_price': variant['cost_price'] ?? 0.0,
          'track_inventory': 1,
          'stock_quantity': variant['stock_quantity'] ?? 0.0,
          'attributes': _dbHelper.encodeJson(null),
          'metadata': _dbHelper.encodeJson(null),
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    return (await getProductById(id))!;
  }

  // Update product
  Future<Product> updateProduct(int id, Product product) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'products',
      {
        'sku': product.sku,
        'barcode': product.barcode,
        'name': product.name,
        'category_id': product.categoryId,
        'description': product.description,
        'unit': product.unit,
        'is_service': product.isService ? 1 : 0,
        'attributes': _dbHelper.encodeJson(product.attributes),
        'metadata': _dbHelper.encodeJson(product.metadata),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return (await getProductById(id))!;
  }

  // Delete product
  Future<void> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Get all categories
  Future<List<Category>> getCategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return Category(
        id: maps[i]['id'],
        shopId: maps[i]['shop_id'],
        name: maps[i]['name'],
        slug: maps[i]['slug'],
        parentId: maps[i]['parent_id'],
        createdAt: DateTime.parse(maps[i]['created_at']),
        updatedAt: DateTime.parse(maps[i]['updated_at']),
      );
    });
  }

  // Create category
  Future<Category> createCategory(String name) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('categories', {
      'shop_id': 1,
      'name': name,
      'slug': name.toLowerCase().replaceAll(' ', '-'),
      'created_at': now,
      'updated_at': now,
    });

    return Category(
      id: id,
      shopId: 1,
      name: name,
      slug: name.toLowerCase().replaceAll(' ', '-'),
      parentId: null,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
    );
  }

  // Update category
  Future<Category> updateCategory(int id, String name) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'categories',
      {
        'name': name,
        'slug': name.toLowerCase().replaceAll(' ', '-'),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return Category(
      id: id,
      shopId: 1,
      name: name,
      slug: name.toLowerCase().replaceAll(' ', '-'),
      parentId: null,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
    );
  }

  // Delete category
  Future<void> deleteCategory(int id) async {
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Update variant stock
  Future<void> updateVariantStock(int variantId, double quantity) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('''
      UPDATE product_variants
      SET stock_quantity = stock_quantity + ?, updated_at = ?
      WHERE id = ?
    ''', [quantity, DateTime.now().toIso8601String(), variantId]);
  }

  // Private helper to get variants by product ID
  Future<List<ProductVariant>> _getVariantsByProductId(
      Database db, int productId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'product_variants',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );

    return List.generate(maps.length, (i) {
      return ProductVariant(
        id: maps[i]['id'],
        productId: maps[i]['product_id'],
        code: maps[i]['code'],
        barcode: maps[i]['barcode'],
        name: maps[i]['name'],
        price: maps[i]['price'],
        costPrice: maps[i]['cost_price'] ?? 0.0,
        trackInventory: maps[i]['track_inventory'] == 1,
        attributes: _dbHelper.decodeJson(maps[i]['attributes']),
        metadata: _dbHelper.decodeJson(maps[i]['metadata']),
        createdAt: DateTime.parse(maps[i]['created_at']),
        updatedAt: DateTime.parse(maps[i]['updated_at']),
        stockQuantity: maps[i]['stock_quantity'],
      );
    });
  }
}
