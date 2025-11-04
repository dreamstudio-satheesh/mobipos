class Sale {
  final int id;
  final int shopId;
  final String invoiceNumber;
  final int? customerId;
  final DateTime saleDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? paymentMethod;
  final String paymentStatus;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data
  final List<SaleItem>? items;

  Sale({
    required this.id,
    required this.shopId,
    required this.invoiceNumber,
    this.customerId,
    required this.saleDate,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    this.paymentMethod,
    this.paymentStatus = 'paid',
    this.notes,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      shopId: json['shop_id'],
      invoiceNumber: json['invoice_number'],
      customerId: json['customer_id'],
      saleDate: DateTime.parse(json['sale_date']),
      subtotal: double.parse(json['subtotal'].toString()),
      discount: json['discount'] != null
          ? double.parse(json['discount'].toString())
          : 0.0,
      tax: json['tax'] != null ? double.parse(json['tax'].toString()) : 0.0,
      total: double.parse(json['total'].toString()),
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'] ?? 'paid',
      notes: json['notes'],
      metadata: json['metadata'] is Map ? json['metadata'] : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      items: json['items'] != null
          ? (json['items'] as List).map((i) => SaleItem.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'sale_date': saleDate.toIso8601String(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'notes': notes,
      'metadata': metadata,
    };
  }
}

class SaleItem {
  final int id;
  final int saleId;
  final int productId;
  final int? variantId;
  final String productName;
  final String? variantName;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final DateTime createdAt;
  final DateTime updatedAt;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    this.variantId,
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'],
      saleId: json['sale_id'],
      productId: json['product_id'],
      variantId: json['variant_id'],
      productName: json['product_name'],
      variantName: json['variant_name'],
      quantity: double.parse(json['quantity'].toString()),
      unitPrice: double.parse(json['unit_price'].toString()),
      subtotal: double.parse(json['subtotal'].toString()),
      discount: json['discount'] != null
          ? double.parse(json['discount'].toString())
          : 0.0,
      tax: json['tax'] != null ? double.parse(json['tax'].toString()) : 0.0,
      total: double.parse(json['total'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'variant_id': variantId,
      'product_name': productName,
      'variant_name': variantName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
    };
  }
}
