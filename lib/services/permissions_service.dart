import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionsService {
  // Check if all required permissions are granted
  static Future<bool> checkAllPermissions() async {
    final camera = await Permission.camera.isGranted;
    final contacts = await Permission.contacts.isGranted;
    final photos = await Permission.photos.isGranted;
    
    return camera && contacts && photos;
  }

  // Request camera permission
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    
    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Camera Permission Required',
          'Camera access is needed to scan QR codes for payments and capture receipts.',
          status.isPermanentlyDenied,
        );
      }
      return false;
    }
    
    return status.isGranted;
  }

  // Request contacts permission
  static Future<bool> requestContactsPermission(BuildContext context) async {
    final status = await Permission.contacts.request();
    
    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Contacts Permission Required',
          'Contact access allows you to easily send money to your contacts via phone or email.',
          status.isPermanentlyDenied,
        );
      }
      return false;
    }
    
    return status.isGranted;
  }

  // Request photos permission
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    final status = await Permission.photos.request();
    
    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Photos Permission Required',
          'Photo access is needed to scan checks, upload receipts, and attach payment documents.',
          status.isPermanentlyDenied,
        );
      }
      return false;
    }
    
    return status.isGranted;
  }

  // Request notification permission
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.request();
    
    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Notification Permission Required',
          'Notifications keep you updated about transactions, money received, and security alerts.',
          status.isPermanentlyDenied,
        );
      }
      return false;
    }
    
    return status.isGranted;
  }

  // Request SMS permission (Android only)
  static Future<bool> requestSMSPermission(BuildContext context) async {
    final status = await Permission.sms.request();
    
    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'SMS Permission Required',
          'SMS access allows you to send money invites directly via text message.',
          status.isPermanentlyDenied,
        );
      }
      return false;
    }
    
    return status.isGranted;
  }

  // Request all permissions at once (during signup)
  static Future<Map<String, bool>> requestAllPermissions(BuildContext context) async {
    return {
      'camera': await requestCameraPermission(context),
      'contacts': await requestContactsPermission(context),
      'photos': await requestPhotosPermission(context),
      'notifications': await requestNotificationPermission(context),
    };
  }

  // Check if NFC is available and enabled
  static Future<bool> isNFCAvailable() async {
    try {
      // NFC check will be done with nfc_manager package
      // Return true for now, will be implemented when needed
      return true;
    } catch (e) {
      return false;
    }
  }

  // Show permission rationale dialog
  static void _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    bool isPermanentlyDenied,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (isPermanentlyDenied) ...[
              const SizedBox(height: 16),
              const Text(
                'Please enable this permission in your device settings.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (isPermanentlyDenied)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }

  // Get permission status for display
  static Future<Map<String, String>> getPermissionsStatus() async {
    final camera = await Permission.camera.status;
    final contacts = await Permission.contacts.status;
    final photos = await Permission.photos.status;
    final notifications = await Permission.notification.status;
    
    return {
      'Camera': _getStatusString(camera),
      'Contacts': _getStatusString(contacts),
      'Photos': _getStatusString(photos),
      'Notifications': _getStatusString(notifications),
    };
  }

  static String _getStatusString(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '✅ Granted';
      case PermissionStatus.denied:
        return '❌ Denied';
      case PermissionStatus.permanentlyDenied:
        return '🚫 Permanently Denied';
      case PermissionStatus.restricted:
        return '⚠️ Restricted';
      case PermissionStatus.limited:
        return '⚠️ Limited';
      default:
        return '❓ Unknown';
    }
  }
}
