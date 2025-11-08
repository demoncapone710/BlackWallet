import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../services/pin_service.dart';
import '../services/notification_service.dart';
import '../services/receipt_service.dart';
import '../services/api_service.dart';

/// Developer Testing Screen - Quick access to test all features
/// WARNING: Remove or disable before production release!
class DevTestingScreen extends StatefulWidget {
  const DevTestingScreen({Key? key}) : super(key: key);

  @override
  State<DevTestingScreen> createState() => _DevTestingScreenState();
}

class _DevTestingScreenState extends State<DevTestingScreen> {
  final _biometricService = BiometricService();
  final _notificationService = NotificationService();
  
  String _testResults = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
  }

  void _log(String message) {
    setState(() {
      _testResults += '${DateTime.now().toString().substring(11, 19)} - $message\n';
    });
    print('[DEV TEST] $message');
  }

  void _clearLog() {
    setState(() => _testResults = '');
  }

  Future<void> _testBiometrics() async {
    setState(() => _testing = true);
    _log('Testing Biometric Authentication...');
    
    try {
      final canCheck = await _biometricService.isBiometricAvailable();
      _log('Can check biometrics: $canCheck');
      
      if (canCheck) {
        _log('Biometric hardware detected');
        
        _log('Attempting authentication...');
        final result = await _biometricService.authenticateForAppAccess();
        _log('Auth result: ${result ? "SUCCESS" : "FAILED"}');
      } else {
        _log('Biometrics not available on this device');
      }
    } catch (e) {
      _log('ERROR: $e');
    }
    
    setState(() => _testing = false);
  }

  Future<void> _testPin() async {
    setState(() => _testing = true);
    _log('Testing PIN Service...');
    
    try {
      final hasPin = await PinService.hasPin();
      _log('Has PIN configured: $hasPin');
      
      if (!hasPin) {
        _log('Setting test PIN: 1234');
        await PinService.setPin('1234');
        _log('PIN set successfully');
      }
      
      _log('Verifying correct PIN (1234)...');
      final correct = await PinService.verifyPin('1234');
      _log('Correct PIN result: ${correct ? "PASS" : "FAIL"}');
      
      _log('Verifying incorrect PIN (9999)...');
      final incorrect = await PinService.verifyPin('9999');
      _log('Incorrect PIN result: ${!incorrect ? "PASS (correctly rejected)" : "FAIL (should reject)"}');
      
    } catch (e) {
      _log('ERROR: $e');
    }
    
    setState(() => _testing = false);
  }

  Future<void> _testNotifications() async {
    setState(() => _testing = true);
    _log('Testing Notification Service...');
    
    try {
      _log('Showing deposit notification...');
      await _notificationService.showDepositNotification(125.50, 'Credit Card');
      await Future.delayed(const Duration(seconds: 2));
      
      _log('Showing money sent notification...');
      await _notificationService.showMoneySentNotification(50.00, 'test_user');
      await Future.delayed(const Duration(seconds: 2));
      
      _log('Showing payment request notification...');
      await _notificationService.showPaymentRequestNotification(25.00, 'test_user', 'Coffee');
      await Future.delayed(const Duration(seconds: 2));
      
      _log('Showing money received notification...');
      await _notificationService.showMoneyReceivedNotification(15.00, 'test_user');
      
      _log('All notifications sent successfully');
    } catch (e) {
      _log('ERROR: $e');
    }
    
    setState(() => _testing = false);
  }

  Future<void> _testReceipts() async {
    setState(() => _testing = true);
    _log('Testing Receipt Service...');
    
    try {
      final receiptService = ReceiptService();
      
      // Mock transaction data
      final mockTransaction = {
        'id': 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        'type': 'sent',
        'amount': 50.00,
        'recipient': 'test_user',
        'sender': 'current_user',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'completed',
        'note': 'Test transaction for receipt generation',
      };
      
      _log('Generating PDF receipt...');
      final pdfFile = await receiptService.generateTransactionPdf(mockTransaction);
      _log('PDF generated: ${pdfFile.path}');
      _log('Size: ${await pdfFile.length()} bytes');
      
      // Test CSV export
      _log('Generating CSV export...');
      final transactions = [mockTransaction];
      final csvFile = await receiptService.exportTransactionsCsv(transactions);
      _log('CSV generated: ${csvFile.path}');
      _log('Size: ${await csvFile.length()} bytes');
      
      _log('Receipt generation successful!');
    } catch (e) {
      _log('ERROR: $e');
    }
    
    setState(() => _testing = false);
  }

  Future<void> _testApiConnection() async {
    setState(() => _testing = true);
    _log('Testing API Connection...');
    
    try {
      _log('Fetching user balance...');
      final balance = await ApiService.getBalance();
      if (balance != null) {
        _log('Balance: \$${balance.toStringAsFixed(2)}');
      } else {
        _log('Balance: null (not logged in or error)');
      }
      
      _log('Fetching username...');
      final username = await ApiService.getCurrentUsername();
      _log('Username: $username');
      
      _log('Fetching transactions...');
      final transactions = await ApiService.getTransactions();
      _log('Transaction count: ${transactions.length}');
      
      _log('API connection test successful!');
    } catch (e) {
      _log('ERROR: $e');
    }
    
    setState(() => _testing = false);
  }

  Future<void> _runAllTests() async {
    _clearLog();
    _log('========================================');
    _log('RUNNING ALL TESTS');
    _log('========================================');
    
    await _testApiConnection();
    await Future.delayed(const Duration(seconds: 1));
    
    await _testBiometrics();
    await Future.delayed(const Duration(seconds: 1));
    
    await _testPin();
    await Future.delayed(const Duration(seconds: 1));
    
    await _testNotifications();
    await Future.delayed(const Duration(seconds: 1));
    
    await _testReceipts();
    
    _log('========================================');
    _log('ALL TESTS COMPLETED');
    _log('========================================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Testing'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLog,
            tooltip: 'Clear log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Warning banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.orange[900],
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Developer Mode - Remove before production!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Test buttons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTestButton(
                  'Run All Tests',
                  Icons.play_circle_filled,
                  Colors.green,
                  _runAllTests,
                ),
                const Divider(height: 24),
                _buildTestButton(
                  'Test API Connection',
                  Icons.cloud,
                  Colors.blue,
                  _testApiConnection,
                ),
                _buildTestButton(
                  'Test Biometric Auth',
                  Icons.fingerprint,
                  Colors.purple,
                  _testBiometrics,
                ),
                _buildTestButton(
                  'Test PIN Service',
                  Icons.pin,
                  Colors.indigo,
                  _testPin,
                ),
                _buildTestButton(
                  'Test Notifications',
                  Icons.notifications,
                  Colors.orange,
                  _testNotifications,
                ),
                _buildTestButton(
                  'Test Receipts',
                  Icons.receipt,
                  Colors.brown,
                  _testReceipts,
                ),
              ],
            ),
          ),
          
          // Results log
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Text(
                        'Test Results',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_testing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      _testResults.isEmpty ? 'No tests run yet. Tap a button above to start.' : _testResults,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: _testing ? null : onTap,
        icon: Icon(icon),
        label: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
