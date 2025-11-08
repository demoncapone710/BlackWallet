import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const baseUrl = "http://10.0.0.104:8000";

  static Future<String?> login(String username, String password) async {
    try {
      print("Attempting login to $baseUrl/login");
      final res = await http.post(
        Uri.parse("$baseUrl/login"),
        body: jsonEncode({"username": username, "password": password}),
        headers: {"Content-Type": "application/json"},
      ).timeout(Duration(seconds: 10));
      
      print("Login response status: ${res.statusCode}");
      print("Login response body: ${res.body}");
      
      if (res.statusCode == 200) return jsonDecode(res.body)["token"];
      return null;
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  static Future<bool> signup(
    String username,
    String password,
    String email,
    String phone,
    String fullName,
  ) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/signup"),
        body: jsonEncode({
          "username": username,
          "password": password,
          "email": email,
          "phone": phone,
          "full_name": fullName,
        }),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Signup error: $e");
      return false;
    }
  }

  static Future<double?> getBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.get(
        Uri.parse("$baseUrl/balance"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        return (jsonDecode(res.body)["balance"] as num).toDouble();
      }
      return null;
    } catch (e) {
      print("Get balance error: $e");
      return null;
    }
  }

  static Future<bool> transfer(String sender, String receiver, double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.post(
        Uri.parse("$baseUrl/transfer"),
        body: jsonEncode({
          "sender": sender,
          "receiver": receiver,
          "amount": amount,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Transfer error: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/transactions"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data["transactions"]);
      }
      return [];
    } catch (e) {
      print("Get transactions error: $e");
      return [];
    }
  }

  static Future<String?> getCurrentUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.get(
        Uri.parse("$baseUrl/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body)["username"];
      }
      return null;
    } catch (e) {
      print("Get username error: $e");
      return null;
    }
  }

  // Payment Methods APIs
  static Future<bool> addCard(String paymentMethodId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.post(
        Uri.parse("$baseUrl/api/payment/payment-methods/card"),
        body: jsonEncode({"payment_method_id": paymentMethodId}),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Add card error: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/api/payment/payment-methods"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data["payment_methods"]);
      }
      return [];
    } catch (e) {
      print("Get payment methods error: $e");
      return [];
    }
  }

  static Future<bool> removePaymentMethod(int paymentMethodId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.delete(
        Uri.parse("$baseUrl/api/payment/payment-methods/$paymentMethodId"),
        headers: {"Authorization": "Bearer $token"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Remove payment method error: $e");
      return false;
    }
  }

  static Future<bool> depositFromCard(String paymentMethodId, double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.post(
        Uri.parse("$baseUrl/api/payment/deposit"),
        body: jsonEncode({
          "payment_method_id": paymentMethodId,
          "amount": amount,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Deposit error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> withdrawToBank(
    String bankAccountId, 
    double amount,
    {bool instantTransfer = false}
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/api/payment/withdraw"),
        body: jsonEncode({
          "bank_account_id": bankAccountId,
          "amount": amount,
          "instant_transfer": instantTransfer,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Withdraw error: $e");
      return null;
    }
  }

  static Future<bool> addBankAccount(String accountNumber, String routingNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.post(
        Uri.parse("$baseUrl/api/payment/payment-methods/bank"),
        body: jsonEncode({
          "account_number": accountNumber,
          "routing_number": routingNumber,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Add bank account error: $e");
      return false;
    }
  }

  // Password Reset APIs
  static Future<Map<String, dynamic>?> forgotPassword(String identifier) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/auth/forgot-password"),
        body: jsonEncode({"identifier": identifier}),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Forgot password error: $e");
      return null;
    }
  }

  static Future<bool> verifyResetCode(String identifier, String code) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/auth/verify-reset-code"),
        body: jsonEncode({"identifier": identifier, "code": code}),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Verify reset code error: $e");
      return false;
    }
  }

  static Future<bool> resetPassword(
    String identifier,
    String code,
    String newPassword,
  ) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/auth/reset-password"),
        body: jsonEncode({
          "identifier": identifier,
          "code": code,
          "new_password": newPassword,
        }),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Reset password error: $e");
      return false;
    }
  }

  // Contact-based Transfer APIs
  static Future<Map<String, dynamic>?> getUserByContact(String contact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.get(
        Uri.parse("$baseUrl/api/auth/user-by-contact/$contact"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Get user by contact error: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> sendMoneyByContact(
    String contact,
    double amount,
    String contactType,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/api/auth/send-money-by-contact"),
        body: jsonEncode({
          "contact": contact,
          "amount": amount,
          "contact_type": contactType,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Send money by contact error: $e");
      return null;
    }
  }

  // ==================== QUICK WIN FEATURES ====================

  // FAVORITES
  static Future<bool> addFavorite(
    String recipientType,
    String recipientIdentifier,
    String? nickname,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.post(
        Uri.parse("$baseUrl/api/favorites/add"),
        body: jsonEncode({
          "recipient_type": recipientType,
          "recipient_identifier": recipientIdentifier,
          "nickname": nickname,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Add favorite error: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/api/favorites"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data["favorites"]);
      }
      return [];
    } catch (e) {
      print("Get favorites error: $e");
      return [];
    }
  }

  static Future<bool> removeFavorite(int favoriteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.delete(
        Uri.parse("$baseUrl/api/favorites/$favoriteId"),
        headers: {"Authorization": "Bearer $token"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Remove favorite error: $e");
      return false;
    }
  }

  // SCHEDULED PAYMENTS
  static Future<Map<String, dynamic>?> createScheduledPayment({
    required String recipientType,
    required String recipientIdentifier,
    required double amount,
    required DateTime scheduledDate,
    required String scheduleType,
    String? note,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/api/scheduled-payments/create"),
        body: jsonEncode({
          "recipient_type": recipientType,
          "recipient_identifier": recipientIdentifier,
          "amount": amount,
          "scheduled_date": scheduledDate.toIso8601String(),
          "schedule_type": scheduleType,
          "note": note,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Create scheduled payment error: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getScheduledPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/api/scheduled-payments"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data["payments"]);
      }
      return [];
    } catch (e) {
      print("Get scheduled payments error: $e");
      return [];
    }
  }

  static Future<bool> cancelScheduledPayment(int paymentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.delete(
        Uri.parse("$baseUrl/api/scheduled-payments/$paymentId"),
        headers: {"Authorization": "Bearer $token"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Cancel scheduled payment error: $e");
      return false;
    }
  }

  // PAYMENT LINKS
  static Future<Map<String, dynamic>?> createPaymentLink({
    double? amount,
    String? description,
    int? maxUses,
    int? expiresInHours,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/api/payment-links/create"),
        body: jsonEncode({
          "amount": amount,
          "description": description,
          "max_uses": maxUses,
          "expires_in_hours": expiresInHours,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Create payment link error: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getMyPaymentLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/api/payment-links"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data["links"]);
      }
      return [];
    } catch (e) {
      print("Get payment links error: $e");
      return [];
    }
  }

  // TRANSACTION SEARCH
  static Future<List<Map<String, dynamic>>> searchTransactions({
    String? query,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
    List<String>? tags,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return [];

      final res = await http.post(
        Uri.parse("$baseUrl/api/transactions/search"),
        body: jsonEncode({
          "query": query,
          "min_amount": minAmount,
          "max_amount": maxAmount,
          "start_date": startDate?.toIso8601String(),
          "end_date": endDate?.toIso8601String(),
          "transaction_type": transactionType,
          "tags": tags,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data["transactions"]);
      }
      return [];
    } catch (e) {
      print("Search transactions error: $e");
      return [];
    }
  }

  // TRANSACTION TAGS
  static Future<bool> addTransactionTag(int transactionId, String tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return false;

      final res = await http.post(
        Uri.parse("$baseUrl/api/transactions/tags/add"),
        body: jsonEncode({
          "transaction_id": transactionId,
          "tag": tag,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Add transaction tag error: $e");
      return false;
    }
  }

  // SUB-WALLETS
  static Future<Map<String, dynamic>?> createSubWallet({
    required String name,
    required String walletType,
    String icon = "wallet",
    String color = "#DC143C",
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/api/wallets/create"),
        body: jsonEncode({
          "name": name,
          "wallet_type": walletType,
          "icon": icon,
          "color": color,
        }),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Create sub-wallet error: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getSubWallets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return [];

      final res = await http.get(
        Uri.parse("$baseUrl/api/wallets"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data["wallets"]);
      }
      return [];
    } catch (e) {
      print("Get sub-wallets error: $e");
      return [];
    }
  }

  // QR LIMITS
  static Future<Map<String, dynamic>?> getQRLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.get(
        Uri.parse("$baseUrl/api/qr-limits"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Get QR limits error: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> checkQRLimit(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return null;

      final res = await http.post(
        Uri.parse("$baseUrl/api/qr-limits/check"),
        body: jsonEncode({"amount": amount}),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("Check QR limit error: $e");
      return null;
    }
  }
}
