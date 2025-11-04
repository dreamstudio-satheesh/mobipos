import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstinController = TextEditingController();

  bool _gstEnabled = true;
  bool _inventoryEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final storeInfo = await _settingsService.getStoreInfo();
      final gstEnabled = await _settingsService.isGSTEnabled();
      final inventoryEnabled = await _settingsService.isInventoryEnabled();

      if (!mounted) return;

      setState(() {
        _storeNameController.text = storeInfo['storeName'] ?? '';
        _addressLine1Controller.text = storeInfo['addressLine1'] ?? '';
        _addressLine2Controller.text = storeInfo['addressLine2'] ?? '';
        _phoneController.text = storeInfo['phone'] ?? '';
        _gstinController.text = storeInfo['gstin'] ?? '';
        _gstEnabled = gstEnabled;
        _inventoryEnabled = inventoryEnabled;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _settingsService.setStoreName(_storeNameController.text.trim());
      await _settingsService.setAddressLine1(_addressLine1Controller.text.trim());
      await _settingsService.setAddressLine2(_addressLine2Controller.text.trim());
      await _settingsService.setPhone(_phoneController.text.trim());
      await _settingsService.setGSTIN(_gstinController.text.trim());
      await _settingsService.setGSTEnabled(_gstEnabled);
      await _settingsService.setInventoryEnabled(_inventoryEnabled);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_isLoading && !_isSaving)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Information Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: const Text(
                        'Store Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _storeNameController,
                            decoration: const InputDecoration(
                              labelText: 'Store Name',
                              hintText: 'Enter your store name',
                              prefixIcon: Icon(Icons.store),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Store name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressLine1Controller,
                            decoration: const InputDecoration(
                              labelText: 'Address Line 1',
                              hintText: 'Street address',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressLine2Controller,
                            decoration: const InputDecoration(
                              labelText: 'Address Line 2 (Optional)',
                              hintText: 'City, State, Pincode',
                              prefixIcon: Icon(Icons.location_city),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '+91 1234567890',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _gstinController,
                            decoration: const InputDecoration(
                              labelText: 'GSTIN (Optional)',
                              hintText: '22AAAAA0000A1Z5',
                              prefixIcon: Icon(Icons.receipt_long),
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Features Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.green.shade50,
                      child: const Text(
                        'Features',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Card(
                            child: SwitchListTile(
                              title: const Text(
                                'GST/Tax Management',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text(
                                'Calculate and show tax on invoices',
                              ),
                              value: _gstEnabled,
                              onChanged: (value) {
                                setState(() => _gstEnabled = value);
                              },
                              secondary: const Icon(
                                Icons.account_balance,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: SwitchListTile(
                              title: const Text(
                                'Inventory Management',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text(
                                'Track product stock quantities',
                              ),
                              value: _inventoryEnabled,
                              onChanged: (value) {
                                setState(() => _inventoryEnabled = value);
                              },
                              secondary: const Icon(
                                Icons.inventory,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info Note
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.amber.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber.shade800),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Empty fields will be hidden in print receipts',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: _isLoading || _isSaving
          ? null
          : FloatingActionButton.extended(
              onPressed: _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
              backgroundColor: Colors.blue,
            ),
    );
  }
}
