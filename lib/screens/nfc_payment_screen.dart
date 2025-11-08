import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/biometric_service.dart';

class NfcPaymentScreen extends StatefulWidget {
  @override
  _NfcPaymentScreenState createState() => _NfcPaymentScreenState();
}

class _NfcPaymentScreenState extends State<NfcPaymentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  
  bool _isNfcAvailable = false;
  bool _isScanning = false;
  bool _isWriting = false;
  String _statusMessage = '';
  String? _username;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkNfcAvailability();
    _loadUsername();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    // _nfcService.stopSession(); // NFC service removed
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    // final isAvailable = await _nfcService.isNfcAvailable(); // NFC service removed
    final isAvailable = false; // NFC temporarily disabled
    setState(() {
      _isNfcAvailable = isAvailable;
      if (!isAvailable) {
        _statusMessage = 'NFC is not available on this device';
      }
    });
  }

  Future<void> _loadUsername() async {
    final username = await ApiService.getCurrentUsername();
    setState(() {
      _username = username;
    });
  }

  Future<void> _startPayment() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'NFC feature temporarily disabled';
    });

    // NFC service removed - showing placeholder message
    setState(() {
      _statusMessage = 'NFC payment feature is currently unavailable';
      _isScanning = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('NFC feature is temporarily disabled'),
        backgroundColor: Colors.orange,
      ),
    );

    /* Commented out NFC service code:
    await _nfcService.startPaymentSession(
      onSuccess: (message) async {
        setState(() {
          _statusMessage = message;
        });
        
        // Show success notification
        final notificationService = NotificationService();
        await notificationService.showTransactionNotification(
          title: '✅ NFC Payment Complete',
          body: 'Payment processed successfully',
          type: 'nfc_payment',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _isScanning = false;
        });
      },
      onError: (error) {
        setState(() {
          _statusMessage = error;
          _isScanning = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
    */
  }

  Future<void> _createReceiveTag() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load user info')),
      );
      return;
    }

    setState(() {
      _isWriting = true;
      _statusMessage = 'NFC feature temporarily disabled';
    });

    // NFC service removed - showing placeholder
    setState(() {
      _statusMessage = 'NFC tag writing is currently unavailable';
      _isWriting = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('NFC feature is temporarily disabled'),
        backgroundColor: Colors.orange,
      ),
    );

    /* Commented out NFC service code:
    await _nfcService.writePaymentTag(
      username: _username!,
      amount: amount,
      onSuccess: (message) {
        setState(() {
          _statusMessage = message;
          _isWriting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('NFC payment tag created!'),
            backgroundColor: Colors.green,
          ),
        );
      },
      onError: (error) {
        setState(() {
          _statusMessage = error;
          _isWriting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
    */
  }

  Future<void> _sendP2PPayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load user info')),
      );
      return;
    }

    // Require biometric for P2P payments over $100
    if (amount >= 100) {
      final biometricService = BiometricService();
      final authenticated = await biometricService.authenticateTransaction(amount);
      if (!authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication required'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      _isScanning = false;
      _statusMessage = 'NFC peer-to-peer payment not yet implemented';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('NFC peer-to-peer payment not yet implemented'),
        backgroundColor: Colors.orange,
      ),
    );

    /*
    // NFC service not implemented
    await _nfcService.sendP2PPayment(
      username: _username!,
      amount: amount,
      onSuccess: (message) async {
        setState(() {
          _statusMessage = message;
          _isScanning = false;
        });

        // Show notification
        final notificationService = NotificationService();
        await notificationService.showMoneySentNotification(amount, 'NFC User');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment sent!'),
            backgroundColor: Colors.green,
          ),
        );

        _amountController.clear();
      },
      onError: (error) {
        setState(() {
          _statusMessage = error;
          _isScanning = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('NFC Tap-to-Pay'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFDC143C),
          labelColor: const Color(0xFFDC143C),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(icon: Icon(Icons.tap_and_play), text: 'Pay'),
            Tab(icon: Icon(Icons.nfc), text: 'Receive'),
          ],
        ),
      ),
      body: !_isNfcAvailable
          ? _buildNfcUnavailable()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPayTab(),
                _buildReceiveTab(),
              ],
            ),
    );
  }

  Widget _buildNfcUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.nfc,
              size: 100,
              color: Colors.grey,
            ),
            SizedBox(height: 24),
            Text(
              'NFC Not Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This device does not support NFC payments. Please use QR code or other payment methods.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDC143C).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFFDC143C),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap your phone on an NFC payment terminal to pay',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // NFC Animation
          Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 500),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isScanning
                    ? LinearGradient(
                        colors: [
                          Color(0xFFDC143C),
                          Color(0xFFFF1744),
                        ],
                      )
                    : null,
                color: _isScanning ? null : Color(0xFF1A1A1A),
                boxShadow: _isScanning
                    ? [
                        BoxShadow(
                          color: Color(0xFFDC143C).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                Icons.tap_and_play,
                size: 100,
                color: _isScanning ? Colors.white : Color(0xFFDC143C),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Status Message
          Center(
            child: Text(
              _statusMessage.isEmpty ? 'Ready to pay' : _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _isScanning ? Color(0xFFDC143C) : Colors.grey[400],
                fontWeight: _isScanning ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Start Payment Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startPayment,
              icon: Icon(_isScanning ? Icons.stop : Icons.nfc),
              label: Text(
                _isScanning ? 'Scanning...' : 'Start NFC Payment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // P2P Payment Section
          Divider(color: Colors.grey[800], height: 40),
          
          Text(
            'Phone-to-Phone Payment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),

          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '0.00',
              labelText: 'Amount',
              prefixIcon: Icon(Icons.attach_money, color: Color(0xFFDC143C)),
              filled: true,
              fillColor: Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade800),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFDC143C), width: 2),
              ),
            ),
          ),
          SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isScanning ? null : _sendP2PPayment,
              icon: Icon(Icons.phone_android),
              label: Text('Send via Phone Tap'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00E676).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF00E676),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create an NFC tag that others can tap to pay you',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Amount Input
          Text(
            'Set Amount to Receive',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),

          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixIcon: Icon(Icons.attach_money, color: Color(0xFF00E676)),
              filled: true,
              fillColor: Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade800),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF00E676), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // NFC Tag Animation
          Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 500),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isWriting
                    ? LinearGradient(
                        colors: [
                          Color(0xFF00E676),
                          Color(0xFF00C853),
                        ],
                      )
                    : null,
                color: _isWriting ? null : Color(0xFF1A1A1A),
                boxShadow: _isWriting
                    ? [
                        BoxShadow(
                          color: Color(0xFF00E676).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                Icons.nfc,
                size: 100,
                color: _isWriting ? Colors.white : Color(0xFF00E676),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Status Message
          if (_statusMessage.isNotEmpty)
            Center(
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _isWriting ? Color(0xFF00E676) : Colors.grey[400],
                  fontWeight: _isWriting ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          const SizedBox(height: 40),

          // Create Tag Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isWriting ? null : _createReceiveTag,
              icon: Icon(_isWriting ? Icons.stop : Icons.create),
              label: Text(
                _isWriting ? 'Writing to NFC tag...' : 'Create Payment Tag',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                _buildInstructionStep('1', 'Enter the amount you want to receive'),
                _buildInstructionStep('2', 'Tap "Create Payment Tag"'),
                _buildInstructionStep('3', 'Hold your phone near an NFC sticker/card'),
                _buildInstructionStep('4', 'Tag is created! Others can now tap to pay you'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF00E676),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
