import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../services/product_service.dart';
import '../services/customer_service.dart';
import '../services/settings_service.dart';
import 'bill_preview_screen.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with WidgetsBindingObserver {
  final ProductService _productService = ProductService();
  final CustomerService _customerService = CustomerService();
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Product> _products = [];
  final List<CartItem> _cartItems = [];
  List<Category> _categories = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;
  bool _loadingCategories = false;
  int? _selectedCategoryId;
  bool _gstEnabled = true;
  double _discount = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _loadCategories();
    _loadProducts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload products when app resumes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadProducts(categoryId: _selectedCategoryId);
    }
  }

  Future<void> _loadSettings() async {
    final gstEnabled = await _settingsService.isGSTEnabled();
    if (mounted) {
      setState(() {
        _gstEnabled = gstEnabled;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);

    try {
      final categories = await _productService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _barcodeController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({String? search, int? categoryId}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await _productService.getProducts(
        page: 1,
        search: search,
        categoryId: categoryId,
      );

      if (!mounted) return;

      setState(() {
        _products = result['products'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _loadProducts(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      categoryId: categoryId,
    );
  }

  void _handleSearch(String value) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_searchController.text == value) {
        _loadProducts(
          search: value.isEmpty ? null : value,
          categoryId: _selectedCategoryId,
        );
      }
    });
  }

  void _addToCart(Product product, ProductVariant variant) {
    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (item) =>
            item.product.id == product.id && item.variant.id == variant.id,
      );

      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItem(
          product: product,
          variant: variant,
          quantity: 1,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cartItems[index].quantity += delta;
      if (_cartItems[index].quantity <= 0) {
        _cartItems.removeAt(index);
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    return _cartItems.fold(
        0, (sum, item) => sum + (item.effectivePrice * item.quantity));
  }

  Future<void> _editItemPrice(int index) async {
    final item = _cartItems[index];
    final currentPrice = item.effectivePrice;
    final priceController =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price - ${item.product.name}'),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Price',
            prefixText: '₹',
            border: OutlineInputBorder(),
            helperText: 'Enter new price for this item',
          ),
          autofocus: true,
          onSubmitted: (value) {
            final price = double.tryParse(value);
            if (price != null && price > 0) {
              Navigator.pop(context, price);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (item.customPrice != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, item.variant.price);
              },
              child: const Text('Reset'),
            ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text);
              if (price != null && price > 0) {
                Navigator.pop(context, price);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid price')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    priceController.dispose();

    if (!mounted) return;

    if (newPrice != null) {
      setState(() {
        if (newPrice == item.variant.price) {
          _cartItems[index].customPrice = null;
        } else {
          _cartItems[index].customPrice = newPrice;
        }
      });
    }
  }

  double _calculateTax() {
    if (!_gstEnabled) return 0.0;
    // Simple 5% GST
    return _calculateSubtotal() * 0.05;
  }

  double _calculateTotal() {
    return _calculateSubtotal() - _discount + _calculateTax();
  }

  Future<void> _selectCustomer() async {
    final customers = await _customerService.getCustomers(page: 1);

    if (!mounted) return;

    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Customer'),
        content: SizedBox(
          width: double.maxFinite,
          child: customers['customers'].isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No customers found. Add a customer first.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: customers['customers'].length,
                  itemBuilder: (context, index) {
                    final customer = customers['customers'][index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: Text(
                          customer.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.purple),
                        ),
                      ),
                      title: Text(customer.name),
                      subtitle:
                          customer.phone != null ? Text(customer.phone!) : null,
                      onTap: () => Navigator.pop(context, customer),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _selectedCustomer = selected;
      });
    }
  }

  void _checkout() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_selectedCustomer?.name ?? "Walk-in"}'),
            const SizedBox(height: 8),
            Text('Items: ${_cartItems.length}'),
            const SizedBox(height: 8),
            Text('Total: ₹${_calculateTotal().toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Payment Method:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.money),
                  label: const Text('Cash'),
                  onPressed: () {
                    Navigator.pop(context);
                    _completeCheckout('Cash');
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Card'),
                  onPressed: () {
                    Navigator.pop(context);
                    _completeCheckout('Card');
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code),
                  label: const Text('UPI'),
                  onPressed: () {
                    Navigator.pop(context);
                    _completeCheckout('UPI');
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _completeCheckout(String paymentMethod) {
    // Prepare bill items
    final billItems = _cartItems
        .map((item) => BillItem(
              productId: item.product.id,
              variantId: item.variant.id,
              productName: item.product.name,
              variantName: item.variant.name,
              quantity: item.quantity,
              price: item.effectivePrice, // Use custom price if set
              trackInventory: item.variant.trackInventory,
            ))
        .toList();

    final subtotal = _calculateSubtotal();
    final tax = _calculateTax();
    final total = _calculateTotal();

    // Navigate to bill preview
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillPreviewScreen(
          items: billItems,
          customer: _selectedCustomer,
          paymentMethod: paymentMethod,
          subtotal: subtotal,
          tax: tax,
          discount: _discount,
          total: total,
        ),
      ),
    ).then((result) {
      // Clear cart when returning from bill preview if sale was completed
      if (!mounted) return;
      if (result == true) {
        setState(() {
          _cartItems.clear();
          _selectedCustomer = null;
          _discount = 0.0;
          _discountController.text = '0';
        });
      }
    });
  }

  Widget _buildCartPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Customer Selection
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.person),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCustomer?.name ?? 'Walk-in Customer',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    iconSize: 24,
                    padding: const EdgeInsets.all(12),
                    onPressed: _selectCustomer,
                    tooltip: 'Change Customer',
                  ),
                ],
              ),
            ),

            // Cart Items
            Expanded(
              child: _cartItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Cart is empty',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        return _buildCartItem(index);
                      },
                    ),
            ),

            // Total Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text('₹${_calculateSubtotal().toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount:'),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            prefixText: '₹',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _discount = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_gstEnabled)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax (5%):'),
                        Text('₹${_calculateTax().toStringAsFixed(2)}'),
                      ],
                    ),
                  if (_gstEnabled) const SizedBox(height: 8),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_calculateTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checkout,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'CHECKOUT',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final crossAxisCount = isPortrait ? 3 : 5;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Point of Sale'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCategories();
              _loadProducts(categoryId: _selectedCategoryId);
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * (isPortrait ? 0.85 : 0.4),
        child: _buildCartPanel(),
      ),
      body: Column(
        children: [
          // Categories horizontal scroll
          if (_categories.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // All products chip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedCategoryId == null,
                      onSelected: (selected) {
                        if (selected) _selectCategory(null);
                      },
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == null
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Category chips
                  ..._categories.map((category) {
                    final isSelected = _selectedCategoryId == category.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(category.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) _selectCategory(category.id);
                        },
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadProducts(categoryId: _selectedCategoryId);
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _handleSearch,
            ),
          ),

          // Products Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(
                        child: Text('No products found'),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _buildProductCard(product);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _cartItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              backgroundColor: Colors.green,
              icon: Badge(
                label: Text('${_cartItems.length}'),
                child: const Icon(Icons.shopping_cart),
              ),
              label: Text('₹${_calculateTotal().toStringAsFixed(0)}'),
            )
          : null,
    );
  }

  Widget _buildProductCard(Product product) {
    final hasVariants =
        product.variants != null && product.variants!.isNotEmpty;
    final variant = hasVariants ? product.variants!.first : null;

    if (variant == null) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _addToCart(product, variant),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product image or avatar
              if (product.imagePath != null &&
                  File(product.imagePath!).existsSync())
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      File(product.imagePath!),
                      key: ValueKey(product.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    product.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '₹${variant.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cartItems[index];

    return Dismissible(
      key: Key('cart_item_${item.product.id}_${item.variant.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Item'),
            content: Text('Remove ${item.product.name} from cart?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _removeFromCart(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.product.name} removed from cart'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => _editItemPrice(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.customPrice != null
                              ? Colors.orange.shade50
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: item.customPrice != null
                              ? Border.all(
                                  color: Colors.orange.shade200, width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${(item.effectivePrice * item.quantity).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: item.customPrice != null
                                    ? Colors.orange.shade700
                                    : Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      iconSize: 18,
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _updateQuantity(index, -1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      iconSize: 18,
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _updateQuantity(index, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartItem {
  final Product product;
  final ProductVariant variant;
  int quantity;
  double? customPrice; // If null, use variant.price

  CartItem({
    required this.product,
    required this.variant,
    required this.quantity,
    this.customPrice,
  });

  double get effectivePrice => customPrice ?? variant.price;
}
