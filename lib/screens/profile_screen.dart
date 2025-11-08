import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import 'login_screen.dart';
import 'pin_setup_screen.dart';
import 'pin_unlock_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  double? _balance;
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _hasPinEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkBiometrics();
  }

  Future<void> _loadUserData() async {
    final username = await ApiService.getCurrentUsername();
    final balance = await ApiService.getBalance();
    final prefs = await SharedPreferences.getInstance();
    final hasPin = await PinService.hasPin();
    
    setState(() {
      _username = username;
      _balance = balance;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _hasPinEnabled = hasPin;
    });
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await auth.canCheckBiometrics;
      setState(() => _canCheckBiometrics = canCheck);
    } catch (e) {
      print('Error checking biometrics: $e');
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      try {
        final authenticated = await auth.authenticate(
          localizedReason: 'Enable biometric authentication',
        );
        
        if (authenticated) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('biometric_enabled', true);
          setState(() => _biometricEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication enabled')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      setState(() => _biometricEnabled = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      _username?[0].toUpperCase() ?? '?',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '@${_username ?? 'Loading...'}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_balance != null)
                    Text(
                      'Balance: \$${_balance!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[300],
                      ),
                    ),
                ],
              ),
            ),
            
            // Settings Section
            const SizedBox(height: 8),
            _buildSection(
              'Security',
              [
                if (_canCheckBiometrics)
                  _buildSwitchTile(
                    'Biometric Authentication',
                    'Use fingerprint/face ID',
                    Icons.fingerprint,
                    _biometricEnabled,
                    _toggleBiometric,
                  ),
                _buildTile(
                  _hasPinEnabled ? 'Change PIN' : 'Set up PIN',
                  _hasPinEnabled ? 'Update your PIN code' : 'Create a PIN for quick access',
                  Icons.pin,
                  () async {
                    if (_hasPinEnabled) {
                      // Verify current PIN before allowing change
                      final verified = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => PinUnlockScreen()),
                      );
                      if (verified == true && mounted) {
                        // Show setup screen to create new PIN
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => PinSetupScreen()),
                        );
                        if (result == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN updated successfully')),
                          );
                          _loadUserData();
                        }
                      }
                    } else {
                      // Direct to setup
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => PinSetupScreen()),
                      );
                      if (result == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN created successfully')),
                        );
                        _loadUserData();
                      }
                    }
                  },
                ),
                if (_hasPinEnabled)
                  _buildTile(
                    'Remove PIN',
                    'Disable PIN authentication',
                    Icons.remove_circle_outline,
                    () async {
                      // Verify PIN before removal
                      final verified = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => PinUnlockScreen()),
                      );
                      if (verified == true && mounted) {
                        await PinService.removePin();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN removed successfully')),
                        );
                        _loadUserData();
                      }
                    },
                  ),
                _buildTile(
                  'Change Password',
                  'Update your password',
                  Icons.lock,
                  () {
                    // TODO: Implement change password
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Change password feature coming soon')),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            _buildSection(
              'Preferences',
              [
                _buildSwitchTile(
                  'Push Notifications',
                  'Get notified about transactions',
                  Icons.notifications,
                  _notificationsEnabled,
                  (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('notifications_enabled', value);
                    setState(() => _notificationsEnabled = value);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            _buildSection(
              'Support',
              [
                _buildTile(
                  'Help & Support',
                  'Get help with your account',
                  Icons.help,
                  () {},
                ),
                _buildTile(
                  'Terms of Service',
                  'View terms and conditions',
                  Icons.description,
                  () {},
                ),
                _buildTile(
                  'Privacy Policy',
                  'How we protect your data',
                  Icons.privacy_tip,
                  () {},
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'BlackWallet v1.0.0',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, color: Colors.black),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFFDC143C),
      activeTrackColor: const Color(0xFFDC143C).withValues(alpha: 0.5),
    );
  }
}
