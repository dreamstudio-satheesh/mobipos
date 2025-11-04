import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedPrinter;
  bool _isScanning = false;
  bool _bluetoothEnabled = false;
  String? _savedPrinterId;
  bool _isPrinting = false;
  PaperSize _paperSize = PaperSize.mm58;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _checkBluetoothState();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPrinterId = prefs.getString('selected_printer_id');
      final savedPaperSize = prefs.getString('paper_size') ?? '58mm';
      _paperSize = savedPaperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58;
    });
  }

  Future<void> _savePrinter(String printerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_id', printerId);
    setState(() {
      _savedPrinterId = printerId;
    });
  }

  Future<void> _savePaperSize(PaperSize paperSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'paper_size', paperSize == PaperSize.mm58 ? '58mm' : '80mm');
    setState(() {
      _paperSize = paperSize;
    });
  }

  Future<void> _checkBluetoothState() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth is not supported on this device'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final state = await FlutterBluePlus.adapterState.first;
      setState(() {
        _bluetoothEnabled = state == BluetoothAdapterState.on;
      });

      if (!_bluetoothEnabled) {
        _showEnableBluetoothDialog();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking Bluetooth: $e')),
      );
    }
  }

  void _showEnableBluetoothDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth Disabled'),
        content: const Text(
          'Please enable Bluetooth in your device settings to scan for printers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (!mounted) return;

    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant all permissions to scan for printers'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _scanForPrinters() async {
    if (!_bluetoothEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable Bluetooth first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      // Request permissions first
      await _requestPermissions();

      // Get already connected devices
      final connectedDevices = FlutterBluePlus.connectedDevices;
      setState(() {
        _devices.addAll(connectedDevices);
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          if (!_devices.any((d) => d.remoteId == result.device.remoteId)) {
            setState(() {
              _devices.add(result.device);
            });
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));

      await FlutterBluePlus.stopScan();

      setState(() {
        _isScanning = false;
      });

      if (_devices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No Bluetooth devices found. Make sure your printer is on and in pairing mode.'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectPrinter(BluetoothDevice device) async {
    setState(() {
      _selectedPrinter = device;
    });

    await _savePrinter(device.remoteId.toString());

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Selected: ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString()}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getDeviceName(BluetoothDevice device) {
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }
    return device.remoteId.toString();
  }

  Future<void> _testPrint() async {
    if (_savedPrinterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a printer first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPrinting = true);

    try {
      // Find the saved printer
      BluetoothDevice? printer;

      // Check in connected devices
      final connectedDevices = FlutterBluePlus.connectedDevices;
      try {
        printer = connectedDevices.firstWhere(
          (device) => device.remoteId.toString() == _savedPrinterId,
        );
      } catch (e) {
        // Not in connected devices
      }

      // If not found, check in scanned devices
      if (printer == null && _devices.isNotEmpty) {
        try {
          printer = _devices.firstWhere(
            (device) => device.remoteId.toString() == _savedPrinterId,
          );
        } catch (e) {
          // Not found
        }
      }

      // If still not found, show error
      if (printer == null) {
        setState(() => _isPrinting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer not found. Please scan and select again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Connect to printer
      await printer.connect();

      // Generate test print data using saved paper size
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      List<int> bytes = [];

      bytes += generator.text(
        'TEST PRINT',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );
      bytes += generator.hr();
      bytes += generator.text(
        'Printer Connected Successfully!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Your printer is working correctly.',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();
      bytes += generator.text(
        'Paper Size: ${_paperSize == PaperSize.mm58 ? "58mm" : "80mm"}',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();

      // Sample Receipt Test
      bytes += generator.text(
        'SAMPLE RECEIPT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.feed(1);
      bytes += generator.row([
        PosColumn(text: 'Item 1', width: 6),
        PosColumn(text: '100.00', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Item 2', width: 6),
        PosColumn(text: '250.50', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: 'Subtotal', width: 6),
        PosColumn(text: '350.50', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Tax', width: 6),
        PosColumn(text: '63.09', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Rs.413.59',
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr();
      bytes += generator.text(
        'Print Test Successful!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send to printer
      List<BluetoothService> services = await printer.discoverServices();

      bool printed = false;
      for (BluetoothService service in services) {
        if (printed) break;
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.write) {
            // Split data into chunks
            const chunkSize = 20;
            for (int i = 0; i < bytes.length; i += chunkSize) {
              final end =
                  (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
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
      await printer.disconnect();

      setState(() => _isPrinting = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test print successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isPrinting = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
      ),
      body: Column(
        children: [
          // Bluetooth status card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _bluetoothEnabled
                            ? Icons.bluetooth
                            : Icons.bluetooth_disabled,
                        color: _bluetoothEnabled ? Colors.blue : Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _bluetoothEnabled
                                  ? 'Bluetooth Enabled'
                                  : 'Bluetooth Disabled',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _bluetoothEnabled
                                  ? 'Ready to scan for printers'
                                  : 'Enable Bluetooth in settings',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_savedPrinterId != null) ...[
                    const Divider(height: 24),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Default printer saved',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Paper Size',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<PaperSize>(
                            title: const Text('58mm'),
                            value: PaperSize.mm58,
                            groupValue: _paperSize,
                            onChanged: (value) {
                              if (value != null) _savePaperSize(value);
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<PaperSize>(
                            title: const Text('80mm'),
                            value: PaperSize.mm80,
                            groupValue: _paperSize,
                            onChanged: (value) {
                              if (value != null) _savePaperSize(value);
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
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
                            : const Icon(Icons.print, size: 20),
                        label: Text(_isPrinting ? 'Printing...' : 'Test Print'),
                        onPressed: _isPrinting ? null : _testPrint,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Scan button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isScanning ? 'Scanning...' : 'Scan for Printers'),
                onPressed: _isScanning ? null : _scanForPrinters,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          if (_devices.isEmpty && !_isScanning)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'How to connect',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('1. Turn on your thermal printer'),
                      const SizedBox(height: 4),
                      const Text('2. Make sure Bluetooth is enabled'),
                      const SizedBox(height: 4),
                      const Text('3. Tap "Scan for Printers"'),
                      const SizedBox(height: 4),
                      const Text('4. Select your printer from the list'),
                    ],
                  ),
                ),
              ),
            ),

          // Device list
          if (_devices.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Available Printers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_devices.length} found',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final isSelected =
                      _savedPrinterId == device.remoteId.toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.print,
                        color: isSelected ? Colors.green : Colors.blue,
                        size: 32,
                      ),
                      title: Text(
                        _getDeviceName(device),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        device.remoteId.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.chevron_right),
                      onTap: () => _selectPrinter(device),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
