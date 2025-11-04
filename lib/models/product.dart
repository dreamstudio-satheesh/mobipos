class Product {
  final int id;
  final int shopId;
  final String? sku;
  final String? barcode;
  final String name;
  final int? categoryId;
  final String? description;
  final String unit;
  final bool isService;
  final String? imagePath;
  final Map<String, dynamic>? attributes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Category info (if loaded)
  final Category? category;

  // Variants (if loaded)
  final List<ProductVariant>? variants;

  Product({
    required this.id,
    required this.shopId,
    this.sku,
    this.barcode,
    required this.name,
    this.categoryId,
    this.description,
    this.unit = 'pcs',
    this.isService = false,
    this.imagePath,
    this.attributes,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.variants,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      shopId: json['shop_id'],
      sku: json['sku'],
      barcode: json['barcode'],
      name: json['name'],
      categoryId: json['category_id'],
      description: json['description'],
      unit: json['unit'] ?? 'pcs',
      isService: json['is_service'] == 1 || json['is_service'] == true,
      imagePath: json['image_path'],
      attributes: json['attributes'] is Map ? json['attributes'] : null,
      metadata: json['metadata'] is Map ? json['metadata'] : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
      variants: json['variants'] != null
          ? (json['variants'] as List).map((v) => ProductVariant.fromJson(v)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'sku': sku,
      'barcode': barcode,
      'name': name,
      'category_id': categoryId,
      'description': description,
      'unit': unit,
      'is_service': isService,
      'image_path': imagePath,
      'attributes': attributes,
      'metadata': metadata,
    };
  }
}

class ProductVariant {
  final int id;
  final int productId;
  final String? code;
  final String? barcode;
  final String? name;
  final double price;
  final double costPrice;
  final bool trackInventory;
  final Map<String, dynamic>? attributes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Stock info (if loaded)
  final double? stockQuantity;

  ProductVariant({
    required this.id,
    required this.productId,
    this.code,
    this.barcode,
    this.name,
    required this.price,
    this.costPrice = 0.0,
    this.trackInventory = true,
    this.attributes,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.stockQuantity,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'],
      productId: json['product_id'],
      code: json['code'],
      barcode: json['barcode'],
      name: json['name'],
      price: double.parse(json['price'].toString()),
      costPrice: json['cost_price'] != null
          ? double.parse(json['cost_price'].toString())
          : 0.0,
      trackInventory: json['track_inventory'] == 1 || json['track_inventory'] == true,
      attributes: json['attributes'] is Map ? json['attributes'] : null,
      metadata: json['metadata'] is Map ? json['metadata'] : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      stockQuantity: json['stock_quantity'] != null
          ? double.parse(json['stock_quantity'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'code': code,
      'barcode': barcode,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'track_inventory': trackInventory,
      'attributes': attributes,
      'metadata': metadata,
    };
  }
}

class Category {
  final int id;
  final int shopId;
  final String name;
  final String? slug;
  final int? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.shopId,
    required this.name,
    this.slug,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      shopId: json['shop_id'],
      name: json['name'],
      slug: json['slug'],
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'slug': slug,
      'parent_id': parentId,
    };
  }
}
