import '../models/customer.dart';
import 'database_helper.dart';

class CustomerService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Get all customers with pagination support
  Future<Map<String, dynamic>> getCustomers({
    int page = 1,
    String? search,
  }) async {
    final db = await _dbHelper.database;

    // For offline mode, we'll return all results but simulate pagination
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      whereClause = 'WHERE name LIKE ? OR phone LIKE ?';
      whereArgs = ['%$search%', '%$search%'];
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM customers
      $whereClause
      ORDER BY name ASC
    ''', whereArgs);

    final customers = List.generate(maps.length, (i) {
      return Customer(
        id: maps[i]['id'],
        shopId: maps[i]['shop_id'],
        name: maps[i]['name'],
        phone: maps[i]['phone'],
        email: maps[i]['email'],
        address: maps[i]['address'],
        city: maps[i]['city'],
        state: maps[i]['state'],
        pincode: maps[i]['pincode'],
        taxId: maps[i]['tax_id'],
        metadata: _dbHelper.decodeJson(maps[i]['metadata']),
        createdAt: DateTime.parse(maps[i]['created_at']),
        updatedAt: DateTime.parse(maps[i]['updated_at']),
      );
    });

    return {
      'customers': customers,
      'current_page': 1,
      'last_page': 1,
      'total': customers.length,
    };
  }

  // Get customer by ID
  Future<Customer?> getCustomerById(int id) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Customer(
      id: map['id'],
      shopId: map['shop_id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      pincode: map['pincode'],
      taxId: map['tax_id'],
      metadata: _dbHelper.decodeJson(map['metadata']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  // Search customer by phone
  Future<Customer?> searchByPhone(String phone) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Customer(
      id: map['id'],
      shopId: map['shop_id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      pincode: map['pincode'],
      taxId: map['tax_id'],
      metadata: _dbHelper.decodeJson(map['metadata']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  // Create customer
  Future<Customer> createCustomer(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // Check if phone number already exists (if phone is provided)
    if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
      final existingCustomer = await searchByPhone(data['phone']);
      if (existingCustomer != null) {
        throw Exception('Phone number already exists. Please use a different phone number.');
      }
    }

    final id = await db.insert('customers', {
      'shop_id': 1, // Default shop ID for offline mode
      'name': data['name'],
      'phone': data['phone'],
      'email': data['email'],
      'address': data['address'],
      'city': data['city'],
      'state': data['state'],
      'pincode': data['pincode'],
      'tax_id': data['tax_id'],
      'metadata': _dbHelper.encodeJson(data['metadata']),
      'created_at': now,
      'updated_at': now,
    });

    return (await getCustomerById(id))!;
  }

  // Update customer
  Future<Customer> updateCustomer(int id, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'customers',
      {
        'name': data['name'],
        'phone': data['phone'],
        'email': data['email'],
        'address': data['address'],
        'city': data['city'],
        'state': data['state'],
        'pincode': data['pincode'],
        'tax_id': data['tax_id'],
        'metadata': _dbHelper.encodeJson(data['metadata']),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return (await getCustomerById(id))!;
  }

  // Delete customer
  Future<void> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
