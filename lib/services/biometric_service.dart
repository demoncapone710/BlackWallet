import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastAuthTimeKey = 'last_auth_time';
  static const int _sessionTimeoutMinutes = 5;

  // Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
      );

      if (didAuthenticate) {
        await _updateLastAuthTime();
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric authentication error: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error during authentication: $e');
      return false;
    }
  }

  // Check if biometric authentication is enabled in settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  // Check if session is still valid (within timeout period)
  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAuthTimeStr = prefs.getString(_lastAuthTimeKey);
    
    if (lastAuthTimeStr == null) return false;

    final lastAuthTime = DateTime.parse(lastAuthTimeStr);
    final now = DateTime.now();
    final difference = now.difference(lastAuthTime);

    return difference.inMinutes < _sessionTimeoutMinutes;
  }

  // Update last authentication time
  Future<void> _updateLastAuthTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAuthTimeKey, DateTime.now().toIso8601String());
  }

  // Clear session (logout)
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastAuthTimeKey);
  }

  // Get biometric type name for display
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Biometric';
    
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  // Authenticate for high-value transactions
  Future<bool> authenticateTransaction(double amount) async {
    final String reason = amount >= 1000
        ? 'Authenticate to confirm large transaction of \$${amount.toStringAsFixed(2)}'
        : 'Authenticate to confirm transaction';
    
    return await authenticate(reason: reason);
  }

  // Authenticate for app access
  Future<bool> authenticateForAppAccess() async {
    // Check if session is still valid
    if (await isSessionValid()) {
      return true;
    }

    // Check if biometric is enabled
    if (!await isBiometricEnabled()) {
      return true; // Skip biometric if disabled
    }

    // Authenticate
    return await authenticate(
      reason: 'Authenticate to access BlackWallet',
      useErrorDialogs: true,
      stickyAuth: true,
    );
  }
}
