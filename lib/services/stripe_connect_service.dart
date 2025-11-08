import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StripeConnectService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  // Get auth token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Create Stripe Connect account (usually auto-created at signup)
  static Future<Map<String, dynamic>?> createAccount({String country = "US"}) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe-connect/create-account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'country': country,
          'business_type': 'individual',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Create account error: $e');
      return null;
    }
  }

  // Get onboarding link to complete Stripe Connect setup
  static Future<String?> getOnboardingLink({
    required String refreshUrl,
    required String returnUrl,
  }) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe-connect/onboarding-link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'refresh_url': refreshUrl,
          'return_url': returnUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['onboarding_url'];
      }
      return null;
    } catch (e) {
      print('Get onboarding link error: $e');
      return null;
    }
  }

  // Check Stripe account status
  static Future<Map<String, dynamic>?> getAccountStatus() async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stripe-connect/account-status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Get account status error: $e');
      return null;
    }
  }

  // List connected bank accounts
  static Future<List<dynamic>?> getBankAccounts() async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stripe-connect/bank-accounts'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['bank_accounts'];
      }
      return null;
    } catch (e) {
      print('Get bank accounts error: $e');
      return null;
    }
  }

  // Deposit money from bank to wallet
  static Future<Map<String, dynamic>?> deposit({
    required double amount,
    required String paymentMethodId,
  }) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe-connect/deposit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'amount': amount,
          'payment_method_id': paymentMethodId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Deposit failed');
      }
    } catch (e) {
      print('Deposit error: $e');
      rethrow;
    }
  }

  // Withdraw money from wallet to bank
  static Future<Map<String, dynamic>?> withdraw({
    required double amount,
  }) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe-connect/withdraw'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Withdrawal failed');
      }
    } catch (e) {
      print('Withdrawal error: $e');
      rethrow;
    }
  }

  // Get transaction history
  static Future<List<dynamic>?> getTransactions({int limit = 10}) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stripe-connect/transactions?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['transactions'];
      }
      return null;
    } catch (e) {
      print('Get transactions error: $e');
      return null;
    }
  }
}
