import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_messaging_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _smsEnabled = false;
  bool _emailEnabled = false;
  bool _pushEnabled = true;
  bool _smsPermissionGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissions = await NativeMessagingService.checkPermissions();
      
      setState(() {
        _smsEnabled = prefs.getBool('notifications_sms') ?? false;
        _emailEnabled = prefs.getBool('notifications_email') ?? false;
        _pushEnabled = prefs.getBool('notifications_push') ?? true;
        _smsPermissionGranted = permissions['sms'] ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_sms', _smsEnabled);
      await prefs.setBool('notifications_email', _emailEnabled);
      await prefs.setBool('notifications_push', _pushEnabled);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  Future<void> _requestSMSPermission() async {
    final permissions = await NativeMessagingService.requestPermissions();
    setState(() {
      _smsPermissionGranted = permissions['sms'] ?? false;
    });

    if (_smsPermissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission granted'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission denied. Please enable it in Settings.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _testSMS() async {
    final result = await NativeMessagingService.openSMSApp(
      phoneNumber: '',
      message: 'Test message from BlackWallet',
    );

    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS app opened')),
      );
    }
  }

  Future<void> _testEmail() async {
    final result = await NativeMessagingService.sendEmail(
      recipientEmail: '',
      subject: 'Test Email from BlackWallet',
      body: 'This is a test email from your BlackWallet app.',
    );

    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email app opened')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notification Preferences',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose how you want to receive transaction notifications',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Push Notifications
                ListTile(
                  leading: const Icon(Icons.notifications_active, color: Colors.blue),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('In-app notifications'),
                  trailing: Switch(
                    value: _pushEnabled,
                    onChanged: (value) {
                      setState(() => _pushEnabled = value);
                      _saveSettings();
                    },
                  ),
                ),

                const Divider(),

                // SMS Notifications
                ListTile(
                  leading: const Icon(Icons.sms, color: Colors.green),
                  title: const Text('SMS Notifications'),
                  subtitle: Text(
                    _smsPermissionGranted
                        ? 'Send via your device SMS'
                        : 'Permission required',
                  ),
                  trailing: Switch(
                    value: _smsEnabled && _smsPermissionGranted,
                    onChanged: _smsPermissionGranted
                        ? (value) {
                            setState(() => _smsEnabled = value);
                            _saveSettings();
                          }
                        : null,
                  ),
                ),

                if (!_smsPermissionGranted)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: _requestSMSPermission,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Grant SMS Permission'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),

                if (_smsEnabled && _smsPermissionGranted)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: _testSMS,
                      icon: const Icon(Icons.send),
                      label: const Text('Test SMS'),
                    ),
                  ),

                const Divider(),

                // Email Notifications
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.red),
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Send via your email app'),
                  trailing: Switch(
                    value: _emailEnabled,
                    onChanged: (value) {
                      setState(() => _emailEnabled = value);
                      _saveSettings();
                    },
                  ),
                ),

                if (_emailEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: _testEmail,
                      icon: const Icon(Icons.send),
                      label: const Text('Test Email'),
                    ),
                  ),

                const SizedBox(height: 24),

                // Info Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        icon: Icons.info_outline,
                        title: 'Native Messaging',
                        description:
                            'SMS and emails are sent through your device\'s native apps. No third-party services required.',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy First',
                        description:
                            'Your messages are sent directly from your device. We never store your SMS or email content.',
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.speed,
                        title: 'Instant Delivery',
                        description:
                            'Messages are sent immediately using your device\'s messaging capabilities.',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),

                // Notification Events
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You will receive notifications for:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildEventItem('Money received'),
                      _buildEventItem('Money sent'),
                      _buildEventItem('Withdrawal initiated'),
                      _buildEventItem('Password reset codes'),
                      _buildEventItem('Security alerts'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
