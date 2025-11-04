import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import 'settings_service.dart';

class PrintService {
  final SettingsService _settingsService = SettingsService();

  // Generate PDF for preview and regular printing
  Future<Uint8List> generateInvoicePdf(Sale sale, Customer? customer) async {
    final pdf = pw.Document();
    final storeInfo = await _settingsService.getStoreInfo();
    final gstEnabled = await _settingsService.isGSTEnabled();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Invoice #: ${sale.invoiceNumber}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(sale.saleDate)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Store and Customer Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Store Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (storeInfo['storeName'] != null && storeInfo['storeName']!.isNotEmpty)
                        pw.Text(
                          storeInfo['storeName']!,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (storeInfo['storeName'] != null && storeInfo['storeName']!.isNotEmpty)
                        pw.SizedBox(height: 4),
                      if (storeInfo['addressLine1'] != null && storeInfo['addressLine1']!.isNotEmpty)
                        pw.Text(storeInfo['addressLine1']!, style: const pw.TextStyle(fontSize: 10)),
                      if (storeInfo['addressLine2'] != null && storeInfo['addressLine2']!.isNotEmpty)
                        pw.Text(storeInfo['addressLine2']!, style: const pw.TextStyle(fontSize: 10)),
                      if (storeInfo['phone'] != null && storeInfo['phone']!.isNotEmpty)
                        pw.Text('Phone: ${storeInfo['phone']}', style: const pw.TextStyle(fontSize: 10)),
                      if (storeInfo['gstin'] != null && storeInfo['gstin']!.isNotEmpty)
                        pw.Text('GSTIN: ${storeInfo['gstin']}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),

                  // Customer Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Bill To:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customer?.name ?? 'Walk-in Customer',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      if (customer?.phone != null)
                        pw.Text(
                          'Phone: ${customer!.phone}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (customer?.taxId != null)
                        pw.Text(
                          'GSTIN: ${customer!.taxId}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Items Table
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                headers: ['Item', 'Qty', 'Price', 'Total'],
                data: sale.items?.map((item) {
                  return [
                    item.productName,
                    '${item.quantity}',
                    '₹${item.unitPrice.toStringAsFixed(2)}',
                    '₹${item.total.toStringAsFixed(2)}',
                  ];
                }).toList() ?? [],
              ),
              pw.SizedBox(height: 24),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(
                          width: 150,
                          child: pw.Text('Subtotal:'),
                        ),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            '₹${sale.subtotal.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    if (sale.discount > 0)
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.SizedBox(
                            width: 150,
                            child: pw.Text('Discount:'),
                          ),
                          pw.SizedBox(
                            width: 100,
                            child: pw.Text(
                              '-₹${sale.discount.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(
                          width: 150,
                          child: pw.Text('Tax (GST):'),
                        ),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            '₹${sale.tax.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(
                          width: 150,
                          child: pw.Text(
                            'Total:',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            '₹${sale.total.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Payment Method
              pw.Text(
                'Payment Method: ${sale.paymentMethod}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 32),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Visit again!',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Print to regular printer (preview and print)
  Future<void> printInvoice(Sale sale, Customer? customer) async {
    final pdfData = await generateInvoicePdf(sale, customer);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    );
  }

  // Generate thermal receipt (for 58mm or 80mm thermal printers)
  Future<List<int>> generateThermalReceipt(
    Sale sale,
    Customer? customer, {
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    final storeInfo = await _settingsService.getStoreInfo();

    // Store name
    if (storeInfo['storeName'] != null && storeInfo['storeName']!.isNotEmpty) {
      bytes += generator.text(
        storeInfo['storeName']!,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }

    if (storeInfo['addressLine1'] != null && storeInfo['addressLine1']!.isNotEmpty) {
      bytes += generator.text(
        storeInfo['addressLine1']!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (storeInfo['addressLine2'] != null && storeInfo['addressLine2']!.isNotEmpty) {
      bytes += generator.text(
        storeInfo['addressLine2']!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (storeInfo['phone'] != null && storeInfo['phone']!.isNotEmpty) {
      bytes += generator.text(
        'Phone: ${storeInfo['phone']}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (storeInfo['gstin'] != null && storeInfo['gstin']!.isNotEmpty) {
      bytes += generator.text(
        'GSTIN: ${storeInfo['gstin']}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr();

    // Invoice details
    bytes += generator.text(
      'Invoice: ${sale.invoiceNumber}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      DateFormat('dd/MM/yyyy hh:mm a').format(sale.saleDate),
    );
    bytes += generator.hr();

    // Customer
    bytes += generator.text(
      'Customer: ${customer?.name ?? 'Walk-in Customer'}',
    );
    if (customer?.phone != null) {
      bytes += generator.text('Phone: ${customer!.phone}');
    }
    bytes += generator.hr();

    // Items
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(text: 'Price', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    if (sale.items != null) {
      for (var item in sale.items!) {
        // Wrap long product names
        final wrappedLines = _wrapText(item.productName, 15);

        // Print first line with quantity and price
        bytes += generator.row([
          PosColumn(text: wrappedLines[0], width: 6),
          PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: item.total.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);

        // Print continuation lines if product name wrapped
        for (int i = 1; i < wrappedLines.length; i++) {
          bytes += generator.row([
            PosColumn(text: '  ${wrappedLines[i]}', width: 12),
          ]);
        }
      }
    }

    bytes += generator.hr();

    // Totals
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(text: sale.subtotal.toStringAsFixed(2), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (sale.discount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6),
        PosColumn(text: '-${sale.discount.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: 'Tax (GST)', width: 6),
      PosColumn(text: sale.tax.toStringAsFixed(2), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Rs.${sale.total.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
        ),
      ),
    ]);

    bytes += generator.hr();

    // Payment method
    bytes += generator.text(
      'Payment: ${sale.paymentMethod}',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr();

    // Footer
    bytes += generator.text(
      'Thank you for your business!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Visit again!',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(1);
    bytes += generator.cut();

    return bytes;
  }

  // Find available Bluetooth thermal printers
  Future<List<BluetoothDevice>> findBluetoothPrinters() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth not supported by this device');
      }

      List<BluetoothDevice> devices = [];

      // Get already connected devices
      final connectedDevices = FlutterBluePlus.connectedDevices;
      devices.addAll(connectedDevices);

      // Start scanning for more devices
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      // Collect scan results
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          if (!devices.any((d) => d.remoteId == result.device.remoteId)) {
            devices.add(result.device);
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));

      // Cancel subscription and stop scanning
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      return devices;
    } catch (e) {
      throw Exception('Error finding printers: $e');
    }
  }

  // Print to Bluetooth thermal printer
  Future<void> printToBluetoothPrinter(
    BluetoothDevice device,
    Sale sale,
    Customer? customer, {
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    try {
      // Connect to device
      await device.connect();

      // Generate receipt bytes
      final bytes = await generateThermalReceipt(sale, customer, paperSize: paperSize);

      // Find print service and characteristic
      List<BluetoothService> services = await device.discoverServices();

      bool printed = false;
      for (BluetoothService service in services) {
        if (printed) break;
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            // Split data into chunks (some printers have MTU limitations)
            const chunkSize = 20;
            for (int i = 0; i < bytes.length; i += chunkSize) {
              final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
              final chunk = bytes.sublist(i, end);
              await characteristic.write(chunk, withoutResponse: true);
              await Future.delayed(const Duration(milliseconds: 50));
            }
            printed = true;
            break;
          }
        }
      }

      // Disconnect
      await device.disconnect();
    } catch (e) {
      throw Exception('Error printing to Bluetooth printer: $e');
    }
  }

  // Helper function to wrap long text into multiple lines
  List<String> _wrapText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return [text];
    }

    List<String> lines = [];
    String remaining = text;

    while (remaining.length > maxLength) {
      // Try to find a space before maxLength to break at word boundary
      int breakPoint = maxLength;
      int lastSpace = remaining.substring(0, maxLength).lastIndexOf(' ');

      if (lastSpace > 0 && lastSpace > maxLength * 0.6) {
        // Break at word boundary if space is not too far back
        breakPoint = lastSpace;
      }

      lines.add(remaining.substring(0, breakPoint).trim());
      remaining = remaining.substring(breakPoint).trim();
    }

    // Add the remaining text
    if (remaining.isNotEmpty) {
      lines.add(remaining);
    }

    return lines;
  }
}
