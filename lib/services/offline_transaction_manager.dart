import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'api_service.dart';

class OfflineTransactionManager {
  static const String _queueKey = 'offline_transaction_queue';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _deviceIdKey = 'device_id';

  // Check if device is online
  static Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Double-check with actual network request
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Get or create device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      } else {
        deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  // Add transaction to offline queue
  static Future<void> queueTransaction(Map<String, dynamic> transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();

    // Add metadata
    transaction['device_id'] = deviceId;
    transaction['queued_at'] = DateTime.now().toIso8601String();
    transaction['is_offline'] = true;
    transaction['status'] = 'queued_offline';

    // Get existing queue
    List<dynamic> queue = await getQueuedTransactions();
    queue.add(transaction);

    // Save queue
    await prefs.setString(_queueKey, json.encode(queue));
  }

  // Get all queued transactions
  static Future<List<dynamic>> getQueuedTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey);

    if (queueJson == null || queueJson.isEmpty) {
      return [];
    }

    try {
      return json.decode(queueJson) as List<dynamic>;
    } catch (e) {
      print('Error parsing queue: $e');
      return [];
    }
  }

  // Sync offline transactions with server
  static Future<Map<String, dynamic>> syncTransactions() async {
    if (!await isOnline()) {
      return {
        'success': false,
        'message': 'Device is offline',
        'synced': 0,
        'failed': 0,
      };
    }

    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueuedTransactions();

    if (queue.isEmpty) {
      return {
        'success': true,
        'message': 'No transactions to sync',
        'synced': 0,
        'failed': 0,
      };
    }

    int synced = 0;
    int failed = 0;
    List<dynamic> remainingQueue = [];

    for (var transaction in queue) {
      try {
        // Send transaction to server based on type
        bool success = false;

        switch (transaction['transaction_type']) {
          case 'nfc_payment':
            success = await _syncNFCPayment(transaction);
            break;
          case 'transfer':
            success = await _syncTransfer(transaction);
            break;
          case 'internal':
            success = await _syncInternalTransaction(transaction);
            break;
          default:
            print('Unknown transaction type: ${transaction['transaction_type']}');
            failed++;
            continue;
        }

        if (success) {
          synced++;
        } else {
          failed++;
          remainingQueue.add(transaction);
        }
      } catch (e) {
        print('Error syncing transaction: $e');
        failed++;
        remainingQueue.add(transaction);
      }
    }

    // Update queue with remaining failed transactions
    await prefs.setString(_queueKey, json.encode(remainingQueue));

    // Update last sync timestamp
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    return {
      'success': failed == 0,
      'message': 'Synced $synced transactions, $failed failed',
      'synced': synced,
      'failed': failed,
      'remaining': remainingQueue.length,
    };
  }

  static Future<bool> _syncNFCPayment(Map<String, dynamic> transaction) async {
    try {
      final response = await ApiService.syncOfflineTransaction(transaction);
      return response != null;
    } catch (e) {
      print('NFC payment sync failed: $e');
      return false;
    }
  }

  static Future<bool> _syncTransfer(Map<String, dynamic> transaction) async {
    try {
      final response = await ApiService.syncOfflineTransaction(transaction);
      return response != null;
    } catch (e) {
      print('Transfer sync failed: $e');
      return false;
    }
  }

  static Future<bool> _syncInternalTransaction(Map<String, dynamic> transaction) async {
    try {
      final response = await ApiService.syncOfflineTransaction(transaction);
      return response != null;
    } catch (e) {
      print('Internal transaction sync failed: $e');
      return false;
    }
  }

  // Clear all queued transactions (use with caution)
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  // Get last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);

    if (lastSync == null) return null;

    try {
      return DateTime.parse(lastSync);
    } catch (e) {
      return null;
    }
  }

  // Store data for offline use
  static Future<void> cacheUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_data', json.encode(userData));
  }

  // Get cached user data
  static Future<Map<String, dynamic>?> getCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_user_data');

    if (cachedData == null) return null;

    try {
      return json.decode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Check if auto-sync should run
  static Future<bool> shouldAutoSync() async {
    if (!await isOnline()) return false;

    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    // Auto-sync every 5 minutes
    final minutesSinceSync = DateTime.now().difference(lastSync).inMinutes;
    return minutesSinceSync >= 5;
  }

  // Get queue count
  static Future<int> getQueueCount() async {
    final queue = await getQueuedTransactions();
    return queue.length;
  }
}
