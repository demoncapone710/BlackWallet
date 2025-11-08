import 'package:flutter/services.dart';

class HceService {
  static const MethodChannel _channel = MethodChannel('com.blackwallet/hce');

  /// Check if device supports HCE
  static Future<bool> isHceSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod('isHceSupported');
      return supported ?? false;
    } catch (e) {
      print('Error checking HCE support: $e');
      return false;
    }
  }

  /// Check if this app is the default payment app
  static Future<bool> isDefaultPaymentApp() async {
    try {
      final bool? isDefault = await _channel.invokeMethod('isDefaultPaymentApp');
      return isDefault ?? false;
    } catch (e) {
      print('Error checking default payment app: $e');
      return false;
    }
  }

  /// Request to set this app as default payment app
  static Future<bool> requestDefaultPaymentApp() async {
    try {
      final bool? success = await _channel.invokeMethod('requestDefaultPaymentApp');
      return success ?? false;
    } catch (e) {
      print('Error requesting default payment app: $e');
      return false;
    }
  }

  /// Prepare payment with tokenized card data
  static Future<bool> preparePayment({
    required String cardholderName,
    required String cardToken,
    required String expiryDate, // Format: MMYY
  }) async {
    try {
      final bool? success = await _channel.invokeMethod('preparePayment', {
        'cardholderName': cardholderName,
        'cardToken': cardToken,
        'expiryDate': expiryDate,
      });
      return success ?? false;
    } catch (e) {
      print('Error preparing payment: $e');
      return false;
    }
  }

  /// Cancel prepared payment
  static Future<void> cancelPayment() async {
    try {
      await _channel.invokeMethod('cancelPayment');
    } catch (e) {
      print('Error canceling payment: $e');
    }
  }

  /// Check if payment is currently active/ready
  static Future<bool> isPaymentReady() async {
    try {
      final bool? ready = await _channel.invokeMethod('isPaymentReady');
      return ready ?? false;
    } catch (e) {
      print('Error checking payment ready: $e');
      return false;
    }
  }

  /// Generate a tokenized card number from actual card data
  /// In production, this should call backend API for secure tokenization
  static Future<String> tokenizeCard({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  }) async {
    try {
      // In production: Call your backend tokenization service
      // For now, return a masked version with last 4 digits
      final last4 = cardNumber.substring(cardNumber.length - 4);
      final token = '4000${last4}${DateTime.now().millisecondsSinceEpoch % 100000}';
      return token.padLeft(16, '0');
    } catch (e) {
      print('Error tokenizing card: $e');
      throw Exception('Failed to tokenize card');
    }
  }

  /// Open device NFC settings
  static Future<void> openNfcSettings() async {
    try {
      await _channel.invokeMethod('openNfcSettings');
    } catch (e) {
      print('Error opening NFC settings: $e');
    }
  }
}
