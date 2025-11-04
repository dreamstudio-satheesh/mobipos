import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  // Check if device has any authentication enabled (biometric or PIN/pattern)
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Authenticate user using biometric or device PIN/pattern
  Future<bool> authenticate({String reason = 'Please authenticate to access POS'}) async {
    try {
      // Check if device supports authentication
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return false;
      }

      // Try to authenticate
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true, // Authentication dialog stays visible until success or manual cancellation
          biometricOnly: false, // Allow device PIN/pattern as fallback
        ),
      );

      return authenticated;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  // Check if app security is enabled
  Future<bool> isSecurityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('security_enabled') ?? true; // Default: enabled
  }

  // Enable/disable app security
  Future<void> setSecurityEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('security_enabled', enabled);
  }

  // Check if user should be authenticated (on app launch)
  Future<bool> shouldAuthenticate() async {
    final securityEnabled = await isSecurityEnabled();
    if (!securityEnabled) return false;

    final deviceSupported = await isDeviceSupported();
    return deviceSupported;
  }

  // Get authentication status message for UI
  Future<String> getAuthenticationStatusMessage() async {
    final isSupported = await isDeviceSupported();
    if (!isSupported) {
      return 'No device security detected. Please set up PIN, pattern, or biometric in device settings.';
    }

    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint authentication available';
    } else if (biometrics.contains(BiometricType.face)) {
      return 'Face authentication available';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris authentication available';
    } else {
      return 'Device PIN/Pattern authentication available';
    }
  }
}
