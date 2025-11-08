import 'dart:convert';

/// QR Code service for generating and parsing various payment QR formats
class QRCodeService {
  // Supported QR code types
  static const String typeBlackWallet = 'blackwallet';
  static const String typeCashApp = 'cashapp';
  static const String typeVenmo = 'venmo';
  static const String typePayPal = 'paypal';
  static const String typeGeneric = 'generic';

  /// Generate BlackWallet QR code data
  static String generateBlackWalletQR({
    required String username,
    double? amount,
    String? note,
  }) {
    final params = <String, String>{
      'to': username,
    };
    
    if (amount != null && amount > 0) {
      params['amount'] = amount.toStringAsFixed(2);
    }
    
    if (note != null && note.isNotEmpty) {
      params['note'] = note;
    }
    
    final uri = Uri(
      scheme: 'blackwallet',
      host: 'pay',
      queryParameters: params,
    );
    
    return uri.toString();
  }

  /// Parse any supported QR code format
  static Map<String, dynamic>? parseQRCode(String qrData) {
    try {
      // Try to parse as URI first
      final uri = Uri.tryParse(qrData);
      
      if (uri == null) {
        // Try parsing as plain text (might be username or handle)
        return _parseAsPlainText(qrData);
      }
      
      // Check scheme to determine type
      switch (uri.scheme.toLowerCase()) {
        case 'blackwallet':
          return _parseBlackWalletQR(uri);
        case 'https':
        case 'http':
          return _parseWebBasedQR(uri);
        default:
          // Try parsing as custom scheme (cashapp://, venmo://, etc.)
          return _parseCustomScheme(uri);
      }
    } catch (e) {
      print('Error parsing QR code: $e');
      return null;
    }
  }

  static Map<String, dynamic> _parseBlackWalletQR(Uri uri) {
    if (uri.host != 'pay') {
      throw Exception('Invalid BlackWallet QR code');
    }
    
    final recipient = uri.queryParameters['to'];
    if (recipient == null || recipient.isEmpty) {
      throw Exception('Missing recipient');
    }
    
    return {
      'type': typeBlackWallet,
      'recipient': recipient,
      'amount': double.tryParse(uri.queryParameters['amount'] ?? '0') ?? 0.0,
      'note': uri.queryParameters['note'],
      'displayName': '@$recipient',
    };
  }

  static Map<String, dynamic>? _parseWebBasedQR(Uri uri) {
    final host = uri.host.toLowerCase();
    
    // CashApp web format: https://cash.app/\$username
    if (host.contains('cash.app')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final cashtag = pathSegments.last.replaceAll('\$', '');
        return {
          'type': typeCashApp,
          'recipient': cashtag,
          'amount': double.tryParse(uri.queryParameters['amount'] ?? '0') ?? 0.0,
          'displayName': '\$$cashtag',
          'note': 'CashApp payment',
        };
      }
    }
    
    // Venmo web format: https://venmo.com/username
    if (host.contains('venmo.com')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final username = pathSegments.last.replaceAll('@', '');
        return {
          'type': typeVenmo,
          'recipient': username,
          'amount': double.tryParse(uri.queryParameters['amount'] ?? '0') ?? 0.0,
          'displayName': '@$username',
          'note': 'Venmo payment',
        };
      }
    }
    
    // PayPal web format: https://paypal.me/username
    if (host.contains('paypal.me')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final username = pathSegments.first;
        return {
          'type': typePayPal,
          'recipient': username,
          'amount': double.tryParse(uri.queryParameters['amount'] ?? '0') ?? 0.0,
          'displayName': username,
          'note': 'PayPal payment',
        };
      }
    }
    
    return null;
  }

  static Map<String, dynamic>? _parseCustomScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    
    // CashApp custom scheme: cashapp://\$username
    if (scheme == 'cashapp') {
      final cashtag = uri.host.replaceAll('\$', '');
      return {
        'type': typeCashApp,
        'recipient': cashtag,
        'amount': double.tryParse(uri.queryParameters['amount'] ?? '0') ?? 0.0,
        'displayName': '\$$cashtag',
        'note': 'CashApp payment',
      };
    }
    
    // Venmo custom scheme: venmo://paycharge?recipients=username
    if (scheme == 'venmo') {
      final recipients = uri.queryParameters['recipients'];
      if (recipients != null && recipients.isNotEmpty) {
        return {
          'type': typeVenmo,
          'recipient': recipients,
          'amount': double.tryParse(uri.queryParameters['amount'] ?? '0') ?? 0.0,
          'displayName': '@$recipients',
          'note': uri.queryParameters['note'] ?? 'Venmo payment',
        };
      }
    }
    
    return null;
  }

  static Map<String, dynamic>? _parseAsPlainText(String text) {
    // Try to detect patterns
    text = text.trim();
    
    // CashApp cashtag: \$username
    if (text.startsWith('\$')) {
      final cashtag = text.substring(1);
      return {
        'type': typeCashApp,
        'recipient': cashtag,
        'amount': 0.0,
        'displayName': text,
        'note': 'CashApp payment',
      };
    }
    
    // Venmo/Twitter style: @username
    if (text.startsWith('@')) {
      final username = text.substring(1);
      return {
        'type': typeGeneric,
        'recipient': username,
        'amount': 0.0,
        'displayName': text,
        'note': 'Payment',
      };
    }
    
    // Plain username (could be anything)
    if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(text)) {
      return {
        'type': typeGeneric,
        'recipient': text,
        'amount': 0.0,
        'displayName': text,
        'note': 'Payment',
      };
    }
    
    return null;
  }

  /// Get icon for QR code type
  static String getIconForType(String type) {
    switch (type) {
      case typeCashApp:
        return '💵'; // CashApp
      case typeVenmo:
        return '💳'; // Venmo
      case typePayPal:
        return '💰'; // PayPal
      case typeBlackWallet:
        return '🔒'; // BlackWallet
      default:
        return '📱'; // Generic
    }
  }

  /// Get color for QR code type
  static String getColorForType(String type) {
    switch (type) {
      case typeCashApp:
        return '#00D632'; // CashApp green
      case typeVenmo:
        return '#3D95CE'; // Venmo blue
      case typePayPal:
        return '#003087'; // PayPal blue
      case typeBlackWallet:
        return '#DC143C'; // BlackWallet red
      default:
        return '#666666'; // Generic grey
    }
  }

  /// Check if QR type is supported for sending money
  static bool canSendMoney(String type) {
    // For now, only BlackWallet QR codes can directly send money
    // Others would need external app integration
    return type == typeBlackWallet;
  }

  /// Get user-friendly type name
  static String getTypeName(String type) {
    switch (type) {
      case typeCashApp:
        return 'CashApp';
      case typeVenmo:
        return 'Venmo';
      case typePayPal:
        return 'PayPal';
      case typeBlackWallet:
        return 'BlackWallet';
      default:
        return 'Generic';
    }
  }

  /// Validate QR data format
  static bool isValidQRData(String qrData) {
    return parseQRCode(qrData) != null;
  }

  /// Generate sample QR codes for testing
  static Map<String, String> getSampleQRCodes() {
    return {
      'BlackWallet': generateBlackWalletQR(username: 'john_doe', amount: 50.00),
      'CashApp': 'https://cash.app/\$johndoe',
      'Venmo': 'https://venmo.com/johndoe',
      'PayPal': 'https://paypal.me/johndoe',
      'Generic': '@johndoe',
    };
  }
}
