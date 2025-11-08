import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import 'pin_unlock_screen.dart';

class BiometricAuthScreen extends StatefulWidget {
  final Widget destinationScreen;

  const BiometricAuthScreen({
    Key? key,
    required this.destinationScreen,
  }) : super(key: key);

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      final bool authenticated = await _biometricService.authenticateForAppAccess();

      if (authenticated && mounted) {
        // Navigate to destination screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.destinationScreen),
        );
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0A0A),
              const Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC143C), Color(0xFFFF1744)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC143C).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'BW',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // App Name
                  const Text(
                    'BlackWallet',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure Digital Banking',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Biometric Icon
                  if (_isAuthenticating)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFDC143C),
                          width: 3,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fingerprint,
                          size: 48,
                          color: Color(0xFFDC143C),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Status Text
                  Text(
                    _isAuthenticating
                        ? 'Authenticating...'
                        : _errorMessage.isEmpty
                            ? 'Tap to authenticate'
                            : _errorMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: _errorMessage.isEmpty
                          ? Colors.grey[400]
                          : Colors.red[400],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Retry Button (shown on error)
                  if (_errorMessage.isNotEmpty && !_isAuthenticating)
                    ElevatedButton.icon(
                      onPressed: _authenticate,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: const Color(0xFFDC143C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Use PIN fallback
                  if (_errorMessage.isNotEmpty && !_isAuthenticating)
                    TextButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => PinUnlockScreen()),
                        );
                        if (result == true && mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => widget.destinationScreen),
                          );
                        }
                      },
                      icon: const Icon(Icons.pin, color: Colors.white),
                      label: const Text(
                        'Use PIN instead',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                  const SizedBox(height: 60),

                  // Security Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFDC143C).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.security,
                          color: const Color(0xFFDC143C),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Your data is protected',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
