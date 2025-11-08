import 'package:flutter/material.dart';
import '../services/hce_service.dart';
import '../services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HcePaymentScreen extends StatefulWidget {
  @override
  _HcePaymentScreenState createState() => _HcePaymentScreenState();
}

class _HcePaymentScreenState extends State<HcePaymentScreen> with SingleTickerProviderStateMixin {
  bool _isHceSupported = false;
  bool _isDefaultApp = false;
  bool _isPaymentReady = false;
  bool _isLoading = true;
  bool _showCardDetails = false;
  String _username = 'User';
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _checkHceStatus();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'User';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkHceStatus() async {
    setState(() => _isLoading = true);
    
    final supported = await HceService.isHceSupported();
    final isDefault = await HceService.isDefaultPaymentApp();
    final ready = await HceService.isPaymentReady();
    
    setState(() {
      _isHceSupported = supported;
      _isDefaultApp = isDefault;
      _isPaymentReady = ready;
      _isLoading = false;
    });
  }

  Future<void> _setAsDefaultPaymentApp() async {
    final success = await HceService.requestDefaultPaymentApp();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening payment settings...')),
      );
      // Re-check after returning
      Future.delayed(const Duration(seconds: 2), _checkHceStatus);
    }
  }

  Future<void> _activatePayment() async {
    // Require biometric authentication for payment activation
    final biometricService = BiometricService();
    final authenticated = await biometricService.authenticate(
      reason: 'Authenticate to activate contactless payment',
    );
    
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get user's payment method (in production, fetch from secure backend)
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'User';
      
      // In production: Get tokenized card from backend
      // For demonstration: Use a test token
      final cardToken = '4000123456789010'; // This should come from secure tokenization
      final expiryDate = '1225'; // MMYY format
      
      final success = await HceService.preparePayment(
        cardholderName: username,
        cardToken: cardToken,
        expiryDate: expiryDate,
      );

      if (success) {
        setState(() {
          _isPaymentReady = true;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Contactless payment activated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to activate payment');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deactivatePayment() async {
    await HceService.cancelPayment();
    setState(() => _isPaymentReady = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment deactivated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactless Payment'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isHceSupported
              ? _buildUnsupportedUI()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (!_isDefaultApp) ...[
                        _buildSetDefaultCard(),
                        const SizedBox(height: 24),
                      ],
                      
                      _buildPaymentCard(),
                      
                      const SizedBox(height: 16),
                      
                      // View Card Details Button
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showCardDetails = !_showCardDetails;
                          });
                        },
                        icon: Icon(
                          _showCardDetails ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFFDC143C),
                        ),
                        label: Text(
                          _showCardDetails ? 'Hide Card Details' : 'View Card Details',
                          style: const TextStyle(color: Color(0xFFDC143C)),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      if (_isDefaultApp) ...[
                        if (_isPaymentReady)
                          _buildActivePaymentUI()
                        else
                          _buildActivateButton(),
                      ],
                      
                      const SizedBox(height: 32),
                      _buildInfoSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildUnsupportedUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.nfc_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'NFC Not Available',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your device doesn\'t support NFC or it\'s currently disabled.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => HceService.openNfcSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open NFC Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetDefaultCard() {
    return Card(
      color: const Color(0xFFFF9800),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set as Default Payment App',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'To use contactless payments, BlackWallet must be set as your default payment app.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _setAsDefaultPaymentApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF9800),
                ),
                child: const Text('Set as Default'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC143C), Color(0xFFFF1744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC143C).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BlackWallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.contactless,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 36,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showCardDetails ? '4532 1234 5678 9010' : '•••• •••• •••• 9010',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARDHOLDER',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _username.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPIRES',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '12/25',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_showCardDetails) ...[
                          const SizedBox(width: 40),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CVV',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '123',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _activatePayment,
        icon: const Icon(Icons.contactless, size: 28),
        label: const Text(
          'Activate Contactless Payment',
          style: TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildActivePaymentUI() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFDC143C), Color(0xFFFF1744)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC143C).withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.contactless,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Ready to Pay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC143C),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hold your phone near the payment terminal',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _deactivatePayment,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFFDC143C)),
            ),
            child: const Text('Deactivate Payment'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Color(0xFFDC143C)),
                const SizedBox(width: 12),
                const Text(
                  'Security Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              icon: Icons.lock_outline,
              title: 'Secure Tokenization',
              description: 'Your card details are never transmitted. Only secure tokens are used.',
            ),
            const Divider(height: 24),
            _buildInfoItem(
              icon: Icons.fingerprint,
              title: 'Biometric Authentication',
              description: 'Payment activation requires biometric verification.',
            ),
            const Divider(height: 24),
            _buildInfoItem(
              icon: Icons.timer_outlined,
              title: 'Session Timeout',
              description: 'Payment session expires automatically for security.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
