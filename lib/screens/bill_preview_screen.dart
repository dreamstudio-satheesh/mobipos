import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../services/sales_service.dart';
import '../services/print_service.dart';
import '../services/settings_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class BillPreviewScreen extends StatefulWidget {
  final List<BillItem> items;
  final Customer? customer;
  final String paymentMethod;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;

  const BillPreviewScreen({
    super.key,
    required this.items,
    required this.customer,
    required this.paymentMethod,
    required this.subtotal,
    required this.tax,
    this.discount = 0.0,
    required this.total,
  });

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  final SalesService _salesService = SalesService();
  final PrintService _printService = PrintService();
  final SettingsService _settingsService = SettingsService();
  Sale? _savedSale;
  bool _isSaving = false;
  bool _isPrinting = false;
  bool _showThermalPreview = true; // Default to thermal preview
  bool _gstEnabled = true; // Default to true
  BluetoothDevice? _cachedPrinter; // Cache the printer device

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _saveSale();
  }

  Future<void> _loadSettings() async {
    final gstEnabled = await _settingsService.isGSTEnabled();
    if (mounted) {
      setState(() {
        _gstEnabled = gstEnabled;
      });
    }
  }

  Future<void> _saveSale() async {
    if (_isSaving || _savedSale != null) return;

    setState(() => _isSaving = true);

    try {
      final saleItems = widget.items
          .map((item) => {
                'product_id': item.productId,
                'variant_id': item.variantId,
                'product_name': item.productName,
                'variant_name': item.variantName,
                'quantity': item.quantity.toDouble(),
                'unit_price': item.price,
                'track_inventory': item.trackInventory,
              })
          .toList();

      final sale = await _salesService.createSale(
        customerId: widget.customer?.id ?? 1, // Default to walk-in customer
        items: saleItems,
        discount: widget.discount,
        taxRate: (widget.tax / widget.subtotal) * 100, // Calculate tax rate
        paymentMethod: widget.paymentMethod.toLowerCase(),
        notes: '',
      );

      setState(() {
        _savedSale = sale;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale saved! Invoice: ${sale.invoiceNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printPDF() async {
    if (_savedSale == null) return;

    setState(() => _isPrinting = true);

    try {
      await _printService.printInvoice(_savedSale!, widget.customer);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening print preview...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _printThermal() async {
    if (_savedSale == null) return;

    setState(() => _isPrinting = true);

    try {
      // Get the saved printer from settings
      final prefs = await SharedPreferences.getInstance();
      final savedPrinterId = prefs.getString('selected_printer_id');

      if (!mounted) return;

      // If no saved printer, prompt user to go to settings
      if (savedPrinterId == null) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No default printer set. Please go to Printer Settings to select a printer.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      BluetoothDevice? selectedPrinter;

      // Check if we have cached printer and it matches saved ID
      if (_cachedPrinter != null && _cachedPrinter!.remoteId.toString() == savedPrinterId) {
        selectedPrinter = _cachedPrinter;
      } else {
        // Not cached, check in connected devices first
        final connectedDevices = FlutterBluePlus.connectedDevices;
        try {
          selectedPrinter = connectedDevices.firstWhere(
            (device) => device.remoteId.toString() == savedPrinterId,
          );
          _cachedPrinter = selectedPrinter; // Cache it for next time
        } catch (e) {
          // Not in connected devices, need to scan (this is slow)
        }

        // If not found in connected devices, scan for it
        if (selectedPrinter == null) {
          if (!mounted) return;

          // Show scanning indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Searching for printer...'),
              duration: Duration(seconds: 2),
            ),
          );

          final printers = await _printService.findBluetoothPrinters();

          if (!mounted) return;

          // Try to find the saved printer in scan results
          try {
            selectedPrinter = printers.firstWhere(
              (device) => device.remoteId.toString() == savedPrinterId,
            );
            _cachedPrinter = selectedPrinter; // Cache it for next time
          } catch (e) {
            // Saved printer not found
            setState(() => _isPrinting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Printer not found. Please turn on your printer and try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }

      // Get saved paper size
      final savedPaperSizeStr = prefs.getString('paper_size') ?? '58mm';
      final paperSize =
          savedPaperSizeStr == '80mm' ? PaperSize.mm80 : PaperSize.mm58;

      // Ensure we have a valid printer before printing
      if (selectedPrinter == null) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect to printer'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Print to thermal printer
      await _printService.printToBluetoothPrinter(
        selectedPrinter,
        _savedSale!,
        widget.customer,
        paperSize: paperSize,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Widget _buildThermalPreview() {
    final dateTime = _savedSale?.saleDate ?? DateTime.now();
    final invoiceNumber = _savedSale?.invoiceNumber ?? 'Pending...';

    return Container(
      width: 384, // 58mm = ~384px at 72 DPI
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top tear line
          Container(
            width: double.infinity,
            height: 20,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: CustomPaint(
              painter: TearLinePainter(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Store Name
                const Text(
                  'YOUR STORE NAME',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // Store Address
                const Text(
                  'Address Line 1\nAddress Line 2',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),

                const Text(
                  'Phone: +91 1234567890',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),

                const Text(
                  'GSTIN: 22AAAAA0000A1Z5',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),

                const Divider(thickness: 1, color: Colors.black),

                // Invoice Details
                Text(
                  'Invoice: $invoiceNumber',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy hh:mm a').format(dateTime),
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                ),

                const Divider(thickness: 1, color: Colors.black),

                // Items Header
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Item',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Qty',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        'Price',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),

                const Divider(thickness: 1, color: Colors.black),

                // Items
                ...widget.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Courier',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Courier',
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const Divider(thickness: 1, color: Colors.black),

                // Totals
                _buildTotalRow('Subtotal', widget.subtotal),
                if (widget.discount > 0)
                  _buildTotalRow('Discount', -widget.discount),
                if (_gstEnabled)
                  _buildTotalRow('Tax (GST)', widget.tax),

                const Divider(thickness: 2, color: Colors.black),

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                    Text(
                      '₹${widget.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),

                const Divider(thickness: 2, color: Colors.black),

                // Payment Method
                Text(
                  'Payment: ${widget.paymentMethod}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),

                const Divider(thickness: 1, color: Colors.black),

                // Footer
                const SizedBox(height: 8),
                const Text(
                  'Thank you for your business!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Visit again!',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Bottom tear line
          Container(
            width: double.infinity,
            height: 20,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: CustomPaint(
              painter: TearLinePainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Courier',
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = _savedSale?.saleDate ?? DateTime.now();
    final invoiceNumber = _savedSale?.invoiceNumber ?? 'Pending...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          // Toggle between thermal and A4 preview
          IconButton(
            icon: Icon(
                _showThermalPreview ? Icons.receipt_long : Icons.description),
            tooltip: _showThermalPreview
                ? 'Show A4 Preview'
                : 'Show Thermal Preview',
            onPressed: () {
              setState(() {
                _showThermalPreview = !_showThermalPreview;
              });
            },
          ),
        ],
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving sale...'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: _showThermalPreview
                          ? _buildThermalPreview()
                          : Container(
                              constraints: const BoxConstraints(maxWidth: 600),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Center(
                                    child: Column(
                                      children: [
                                        const Text(
                                          'INVOICE',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Invoice #: $invoiceNumber',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(dateTime)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Store Info (you can customize this)
                                  const Text(
                                    'Your Store Name',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Address Line 1\nAddress Line 2\nPhone: +91 1234567890',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Payment Method
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Payment Method:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.paymentMethod,
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),

                                  // Items Table
                                  Table(
                                    border: TableBorder.all(
                                        color: Colors.grey.shade300),
                                    columnWidths: const {
                                      0: FlexColumnWidth(3),
                                      1: FlexColumnWidth(1),
                                      2: FlexColumnWidth(1.5),
                                      3: FlexColumnWidth(1.5),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                            color: Colors.grey.shade100),
                                        children: const [
                                          Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Text(
                                              'Item',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Text(
                                              'Qty',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Text(
                                              'Price',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Text(
                                              'Total',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                      ...widget.items.map((item) => TableRow(
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Text(item.productName),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Text(
                                                  '${item.quantity}',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Text(
                                                  '₹${item.price.toStringAsFixed(2)}',
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Text(
                                                  '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          )),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Totals
                                  Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          const SizedBox(
                                            width: 150,
                                            child: Text('Subtotal:'),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              '₹${widget.subtotal.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_gstEnabled)
                                        const SizedBox(height: 8),
                                      if (_gstEnabled)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            const SizedBox(
                                              width: 150,
                                              child: Text('Tax (GST):'),
                                            ),
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                '₹${widget.tax.toStringAsFixed(2)}',
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          const SizedBox(
                                            width: 150,
                                            child: Text(
                                              'Total:',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              '₹${widget.total.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 48),

                                  // Footer
                                  Center(
                                    child: Text(
                                      'Thank you for your business!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(_isPrinting ? 'Printing...' : 'PDF'),
                          onPressed: _isPrinting || _savedSale == null
                              ? null
                              : _printPDF,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.print),
                          label: Text(_isPrinting ? 'Printing...' : 'Print'),
                          onPressed: _isPrinting || _savedSale == null
                              ? null
                              : _printThermal,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class BillItem {
  final int productId;
  final int variantId;
  final String productName;
  final String? variantName;
  final int quantity;
  final double price;
  final bool trackInventory;

  BillItem({
    required this.productId,
    required this.variantId,
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.price,
    this.trackInventory = true,
  });
}

// Custom painter for thermal paper tear line effect
class TearLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    const circleRadius = 3.0;
    const spacing = 12.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawCircle(
        Offset(x, size.height / 2),
        circleRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
