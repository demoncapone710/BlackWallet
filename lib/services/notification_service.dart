import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  // Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  // Show transaction notification
  Future<void> showTransactionNotification({
    required String title,
    required String body,
    required String type, // 'sent', 'received', 'deposit', 'withdraw'
    double? amount,
  }) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: 'transaction_$type',
      importance: Importance.high,
    );
  }

  // Show deposit success notification
  Future<void> showDepositNotification(double amount, String method) async {
    await showTransactionNotification(
      title: '💰 Deposit Successful',
      body: '\$${amount.toStringAsFixed(2)} has been added to your wallet via $method',
      type: 'deposit',
      amount: amount,
    );
  }

  // Show withdrawal success notification
  Future<void> showWithdrawalNotification(double amount, String destination) async {
    await showTransactionNotification(
      title: '💸 Withdrawal Successful',
      body: '\$${amount.toStringAsFixed(2)} has been sent to $destination',
      type: 'withdraw',
      amount: amount,
    );
  }

  // Show money sent notification
  Future<void> showMoneySentNotification(double amount, String recipient) async {
    await showTransactionNotification(
      title: '📤 Money Sent',
      body: 'You sent \$${amount.toStringAsFixed(2)} to $recipient',
      type: 'sent',
      amount: amount,
    );
  }

  // Show money received notification
  Future<void> showMoneyReceivedNotification(double amount, String sender) async {
    await showTransactionNotification(
      title: '📥 Money Received',
      body: 'You received \$${amount.toStringAsFixed(2)} from $sender',
      type: 'received',
      amount: amount,
    );
  }

  // Show payment request received notification
  Future<void> showPaymentRequestNotification(double amount, String sender, String? reason) async {
    final reasonText = reason != null && reason.isNotEmpty ? ' for "$reason"' : '';
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '💰 Payment Request',
      body: '$sender is requesting \$${amount.toStringAsFixed(2)}$reasonText',
      payload: 'payment_request',
      importance: Importance.high,
    );
  }

  // Show payment request accepted notification
  Future<void> showPaymentRequestAcceptedNotification(double amount, String recipient) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✅ Request Accepted',
      body: '$recipient paid your request of \$${amount.toStringAsFixed(2)}',
      payload: 'request_accepted',
      importance: Importance.high,
    );
  }

  // Show payment request declined notification
  Future<void> showPaymentRequestDeclinedNotification(double amount, String recipient) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '❌ Request Declined',
      body: '$recipient declined your request of \$${amount.toStringAsFixed(2)}',
      payload: 'request_declined',
      importance: Importance.defaultImportance,
    );
  }

  // Show security alert notification
  Future<void> showSecurityAlert(String message) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🔒 Security Alert',
      body: message,
      payload: 'security_alert',
      importance: Importance.max,
    );
  }

  // Show low balance notification
  Future<void> showLowBalanceNotification(double balance) async {
    await _showNotification(
      id: 9999, // Use same ID so it updates instead of creating multiple
      title: '⚠️ Low Balance',
      body: 'Your balance is low: \$${balance.toStringAsFixed(2)}',
      payload: 'low_balance',
      importance: Importance.defaultImportance,
    );
  }

  // Generic notification method
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    Importance importance = Importance.defaultImportance,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'blackwallet_channel',
      'BlackWallet Notifications',
      channelDescription: 'Notifications for BlackWallet transactions and alerts',
      importance: importance,
      priority: Priority.high,
      showWhen: true,
      color: const Color(0xFFDC143C),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Schedule a notification (for reminders, etc.)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Note: Scheduling requires additional setup with timezone package
    // For now, this is a placeholder. Full implementation would use:
    // await flutterLocalNotificationsPlugin.zonedSchedule(...)
    print('Scheduled notification for $scheduledDate: $title');
  }
}
