import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyStoreName = 'store_name';
  static const String _keyAddressLine1 = 'address_line1';
  static const String _keyAddressLine2 = 'address_line2';
  static const String _keyPhone = 'phone';
  static const String _keyGSTIN = 'gstin';
  static const String _keyGSTEnabled = 'gst_enabled';
  static const String _keyInventoryEnabled = 'inventory_enabled';

  // Store Information
  Future<String?> getStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreName);
  }

  Future<void> setStoreName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoreName, value);
  }

  Future<String?> getAddressLine1() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAddressLine1);
  }

  Future<void> setAddressLine1(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAddressLine1, value);
  }

  Future<String?> getAddressLine2() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAddressLine2);
  }

  Future<void> setAddressLine2(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAddressLine2, value);
  }

  Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  Future<void> setPhone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, value);
  }

  Future<String?> getGSTIN() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGSTIN);
  }

  Future<void> setGSTIN(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGSTIN, value);
  }

  // Feature Toggles
  Future<bool> isGSTEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGSTEnabled) ?? true; // Default enabled
  }

  Future<void> setGSTEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGSTEnabled, enabled);
  }

  Future<bool> isInventoryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyInventoryEnabled) ?? true; // Default enabled
  }

  Future<void> setInventoryEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInventoryEnabled, enabled);
  }

  // Get all store info at once
  Future<Map<String, String?>> getStoreInfo() async {
    return {
      'storeName': await getStoreName(),
      'addressLine1': await getAddressLine1(),
      'addressLine2': await getAddressLine2(),
      'phone': await getPhone(),
      'gstin': await getGSTIN(),
    };
  }
}
