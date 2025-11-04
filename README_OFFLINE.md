# POS Billing System - Offline Version

This is an offline version of the POS (Point of Sale) Billing System that uses SQLite local database instead of Laravel backend. The app can run completely without internet connection.

## Key Changes from Online Version

### Database
- **Before**: Laravel backend with MySQL database via REST API
- **After**: SQLite local database stored on device

### Authentication
- **Before**: Login required with backend authentication
- **After**: Device biometric authentication (fingerprint/face ID) or device PIN/pattern lock

### Data Storage
- All products, customers, and sales data stored locally on device
- Data persists across app restarts
- No internet connection needed

## Project Structure

### New Files Created

```
lib/
├── services/
│   ├── database_helper.dart          # SQLite database initialization & schema
│   ├── offline_product_service.dart   # Product CRUD operations
│   ├── offline_customer_service.dart  # Customer CRUD operations
│   ├── offline_sales_service.dart     # Sales/billing operations
│   └── local_auth_service.dart        # Device biometric/PIN authentication
└── models/
    └── sale.dart                      # Sale and SaleItem models
```

### Services

#### DatabaseHelper
- Manages SQLite database connection
- Creates tables: products, product_variants, categories, customers, sales, sale_items
- Pre-loads sample data on first run
- Location: `lib/services/database_helper.dart`

#### OfflineProductService
- Create, read, update, delete products
- Search products by name, SKU, or barcode
- Manage product variants with stock tracking
- Manage categories
- Location: `lib/services/offline_product_service.dart`

#### OfflineCustomerService
- Create, read, update, delete customers
- Search customers by name, phone, or email
- Location: `lib/services/offline_customer_service.dart`

#### OfflineSalesService
- Create sales/bills with multiple items
- Auto-generate invoice numbers (format: INV202411XXXX)
- Automatic stock deduction on sale
- Sales history and reporting
- Sales summary (total revenue, sales count, etc.)
- Location: `lib/services/offline_sales_service.dart`

#### LocalAuthService
- Uses device biometric authentication (fingerprint, face ID, iris)
- Falls back to device PIN/pattern/password if biometrics not available
- Can be enabled/disabled via settings
- Secure app access without managing user passwords
- Location: `lib/services/local_auth_service.dart`

## Database Schema

### Products Table
- id, shop_id, sku, barcode, name, category_id, description, unit, is_service
- attributes (JSON), metadata (JSON)
- created_at, updated_at

### Product Variants Table
- id, product_id, code, barcode, name, price, cost_price
- track_inventory, stock_quantity
- attributes (JSON), metadata (JSON)
- created_at, updated_at

### Categories Table
- id, shop_id, name, slug, parent_id
- created_at, updated_at

### Customers Table
- id, shop_id, name, phone, email, address, city, state, pincode, tax_id
- metadata (JSON)
- created_at, updated_at

### Sales Table
- id, shop_id, invoice_number, customer_id, sale_date
- subtotal, discount, tax, total
- payment_method, payment_status, notes
- metadata (JSON)
- created_at, updated_at

### Sale Items Table
- id, sale_id, product_id, variant_id
- product_name, variant_name, quantity, unit_price
- subtotal, discount, tax, total
- created_at, updated_at

## Sample Data

The database is pre-populated with sample data:

### Categories
- General
- Groceries
- Electronics

### Products
1. Rice 1kg (₹50, 100 units in stock)
2. Cooking Oil 1L (₹120, 50 units in stock)

### Customers
1. Walk-in Customer (default)
2. John Doe (sample customer with full details)

## How to Use the Services

### Example: Get All Products

```dart
import 'services/offline_product_service.dart';

final productService = OfflineProductService();

// Get all products
final products = await productService.getProducts();

// Search products
final searchResults = await productService.getProducts(search: 'rice');

// Get products by category
final groceries = await productService.getProducts(categoryId: 2);

// Search by barcode
final product = await productService.searchByBarcode('1234567890123');
```

### Example: Create a Sale

```dart
import 'services/offline_sales_service.dart';

final salesService = OfflineSalesService();

final sale = await salesService.createSale(
  customerId: 1,
  items: [
    {
      'product_id': 1,
      'variant_id': 1,
      'product_name': 'Rice 1kg',
      'variant_name': 'Standard',
      'quantity': 2.0,
      'unit_price': 50.0,
      'track_inventory': true,
    },
    {
      'product_id': 2,
      'variant_id': 2,
      'product_name': 'Cooking Oil 1L',
      'variant_name': 'Standard',
      'quantity': 1.0,
      'unit_price': 120.0,
      'track_inventory': true,
    },
  ],
  discount: 10.0,
  taxRate: 5.0, // 5% GST
  paymentMethod: 'cash',
  notes: 'Sample sale',
);

print('Invoice: ${sale.invoiceNumber}');
print('Total: ₹${sale.total}');
```

### Example: Get Sales Summary

```dart
import 'services/offline_sales_service.dart';

final salesService = OfflineSalesService();

// Today's sales
final todaySales = await salesService.getTodaySales();

// Sales summary for a date range
final now = DateTime.now();
final startOfMonth = DateTime(now.year, now.month, 1);
final summary = await salesService.getSalesSummary(
  startDate: startOfMonth,
  endDate: now,
);

print('Total Sales: ${summary['total_sales']}');
print('Total Revenue: ₹${summary['total_revenue']}');
```

## Features

### Stock Management
- Automatic stock deduction when items are sold
- Stock restoration when sales are deleted
- Track inventory per product variant

### Invoice Numbering
- Auto-generated invoice numbers
- Format: INV + YYYYMM + sequential number (e.g., INV2024110001)
- Unique invoice numbers guaranteed

### Data Persistence
- All data stored in SQLite database
- Database file: `pos_offline.db` in app documents directory
- Data survives app restarts and updates

## Authentication

The app uses **device-level security** instead of traditional username/password:

### How It Works
1. **On App Launch**: System checks if device has security enabled (fingerprint, face ID, PIN, pattern)
2. **Authentication Required**: User must authenticate using their device's existing security method
3. **No User Table**: No username/password database needed - leverages device security

### Supported Methods
- 👆 **Fingerprint** (most common on Android)
- 🤳 **Face ID** (iOS, newer Android)
- 👁️ **Iris scan** (Samsung devices)
- 🔢 **Device PIN/Pattern** (fallback if biometrics not available)

### Security Settings
- **Enable/Disable**: Can be toggled in app (stored in SharedPreferences)
- **Default**: Security enabled by default
- **Dev Mode**: "Skip Authentication" button for testing (can be removed in production)

### Required Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access POS System</string>
```

## Setup & Installation

1. Navigate to project folder:
   ```bash
   cd /home/satheesh/Projects/POS_Offline/flutter_pos_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. **Add permissions** (see Authentication section above)

4. Run the app:
   ```bash
   flutter run
   ```

5. On first launch:
   - Database will be created automatically
   - Sample data will be inserted
   - Device authentication prompt will appear (if device security is set up)

## Updating the UI Screens

To integrate the offline services into your existing screens, replace the API service calls with offline service calls:

### Before (Online):
```dart
import 'services/product_service.dart';
final products = await ProductService().getProducts();
```

### After (Offline):
```dart
import 'services/offline_product_service.dart';
final products = await OfflineProductService().getProducts();
```

### Screen Files to Update
- `lib/screens/products_screen.dart` - Use `OfflineProductService`
- `lib/screens/customers_screen.dart` - Use `OfflineCustomerService`
- `lib/screens/pos_screen.dart` - Use `OfflineSalesService` and `OfflineProductService`
- `lib/screens/bill_preview_screen.dart` - Use `OfflineSalesService`

## Database Management

### Clear All Data
```dart
await DatabaseHelper().clearAllData();
```

### Backup Recommendation
The database file is located at:
```
{app_documents_directory}/pos_offline.db
```

You can implement backup/restore functionality by copying this file.

## Dependencies

Already included in pubspec.yaml:
- `sqflite: ^2.3.2` - SQLite database
- `path_provider: ^2.1.2` - Get app directory paths
- `shared_preferences: ^2.2.2` - Store simple preferences

## Differences from Online Version

| Feature | Online (Laravel) | Offline (SQLite) |
|---------|-----------------|------------------|
| Authentication | Username/Password | Device biometric/PIN |
| User Management | User table in database | No user table needed |
| Data Storage | MySQL on server | SQLite on device |
| Network | Required | Not required |
| Multi-user | Supported | Single device only |
| Data Sync | Real-time | Not applicable |
| Backup | Server-side | Manual (file copy) |

## Next Steps

1. Update UI screens to use offline services
2. Test all CRUD operations
3. Add data export/import functionality
4. Implement local backup mechanism
5. Add data migration if needed

## Support

For issues or questions about the offline version, refer to the service files for implementation details. All methods are documented with examples above.
