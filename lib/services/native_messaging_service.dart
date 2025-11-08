import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class NativeMessagingService {
  /// Send SMS using device's native SMS app
  static Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Clean phone number
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Open SMS app with pre-filled message
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        queryParameters: {'body': message},
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }

  /// Send SMS by opening device's SMS app (user confirms before sending)
  static Future<bool> openSMSApp({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error opening SMS app: $e');
      return false;
    }
  }

  /// Send email using device's email app
  static Future<bool> sendEmail({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: recipientEmail,
        query: _encodeQueryParameters({
          'subject': subject,
          'body': body,
        }),
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  /// Helper to encode email query parameters
  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Request necessary permissions
  static Future<Map<String, bool>> requestPermissions() async {
    final results = {
      'sms': false,
      'phone': false,
    };

    try {
      // Request SMS permission
      final smsStatus = await Permission.sms.request();
      results['sms'] = smsStatus.isGranted;

      // Request phone permission (for reading contacts if needed)
      final phoneStatus = await Permission.phone.request();
      results['phone'] = phoneStatus.isGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }

    return results;
  }

  /// Check if permissions are granted
  static Future<Map<String, bool>> checkPermissions() async {
    return {
      'sms': await Permission.sms.isGranted,
      'phone': await Permission.phone.isGranted,
    };
  }

  /// Send transaction notification via SMS
  static Future<bool> sendTransactionSMS({
    required String phoneNumber,
    required String recipientName,
    required double amount,
    required String transactionType, // 'received', 'sent', 'withdrawal'
  }) async {
    String message;
    
    switch (transactionType) {
      case 'received':
        message = 'BlackWallet: You received \$${amount.toStringAsFixed(2)} from $recipientName. Check your wallet for details.';
        break;
      case 'sent':
        message = 'BlackWallet: You sent \$${amount.toStringAsFixed(2)} to $recipientName. Transaction complete.';
        break;
      case 'withdrawal':
        message = 'BlackWallet: Withdrawal of \$${amount.toStringAsFixed(2)} initiated. Expected in 1-3 business days.';
        break;
      default:
        message = 'BlackWallet: Transaction of \$${amount.toStringAsFixed(2)} processed.';
    }

    return await sendSMS(phoneNumber: phoneNumber, message: message);
  }

  /// Send transaction notification via Email
  static Future<bool> sendTransactionEmail({
    required String email,
    required String recipientName,
    required double amount,
    required String transactionType,
  }) async {
    String subject;
    String body;
    
    switch (transactionType) {
      case 'received':
        subject = 'Money Received - BlackWallet';
        body = '''Hi,

You have received \$${amount.toStringAsFixed(2)} from $recipientName.

Your BlackWallet balance has been updated. Log in to your account to view the transaction details.

Thank you for using BlackWallet!

Best regards,
BlackWallet Team
''';
        break;
      case 'sent':
        subject = 'Money Sent - BlackWallet';
        body = '''Hi,

You have successfully sent \$${amount.toStringAsFixed(2)} to $recipientName.

Transaction Details:
- Amount: \$${amount.toStringAsFixed(2)}
- Recipient: $recipientName
- Status: Completed

Thank you for using BlackWallet!

Best regards,
BlackWallet Team
''';
        break;
      case 'withdrawal':
        subject = 'Withdrawal Initiated - BlackWallet';
        body = '''Hi,

Your withdrawal of \$${amount.toStringAsFixed(2)} has been initiated.

Expected Processing Time: 1-3 business days

You will receive another notification once the withdrawal is complete.

Thank you for using BlackWallet!

Best regards,
BlackWallet Team
''';
        break;
      default:
        subject = 'Transaction Notification - BlackWallet';
        body = '''Hi,

A transaction of \$${amount.toStringAsFixed(2)} has been processed on your account.

Log in to your BlackWallet account for more details.

Best regards,
BlackWallet Team
''';
    }

    return await sendEmail(
      recipientEmail: email,
      subject: subject,
      body: body,
    );
  }

  /// Send password reset code via SMS
  static Future<bool> sendPasswordResetSMS({
    required String phoneNumber,
    required String resetCode,
  }) async {
    final message = 'BlackWallet: Your password reset code is: $resetCode. This code will expire in 10 minutes.';
    return await sendSMS(phoneNumber: phoneNumber, message: message);
  }

  /// Send password reset code via Email
  static Future<bool> sendPasswordResetEmail({
    required String email,
    required String resetCode,
  }) async {
    final subject = 'Password Reset Code - BlackWallet';
    final body = '''Hi,

You requested a password reset for your BlackWallet account.

Your reset code is: $resetCode

This code will expire in 10 minutes.

If you did not request this reset, please ignore this message and your password will remain unchanged.

Best regards,
BlackWallet Team
''';

    return await sendEmail(
      recipientEmail: email,
      subject: subject,
      body: body,
    );
  }
}
