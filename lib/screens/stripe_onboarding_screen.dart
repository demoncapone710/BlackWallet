import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/stripe_connect_service.dart';

class StripeOnboardingScreen extends StatefulWidget {
  const StripeOnboardingScreen({super.key});

  @override
  State<StripeOnboardingScreen> createState() => _StripeOnboardingScreenState();
}

class _StripeOnboardingScreenState extends State<StripeOnboardingScreen> {
  bool _isLoading = true;
  bool _isConnected = false;
  bool _onboardingComplete = false;
  bool _chargesEnabled = false;
  bool _payoutsEnabled = false;
  String? _stripeAccountId;
  List<String> _requirementsDue = [];

  @override
  void initState() {
    super.initState();
    _checkAccountStatus();
  }

  Future<void> _checkAccountStatus() async {
    setState(() => _isLoading = true);

    try {
      final status = await StripeConnectService.getAccountStatus();
      
      if (status != null) {
        setState(() {
          _isConnected = status['connected'] ?? false;
          _onboardingComplete = status['onboarding_complete'] ?? false;
          _chargesEnabled = status['charges_enabled'] ?? false;
          _payoutsEnabled = status['payouts_enabled'] ?? false;
          _stripeAccountId = status['stripe_account_id'];
          _requirementsDue = List<String>.from(status['requirements_due'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking status: $e')),
        );
      }
    }
  }

  Future<void> _startOnboarding() async {
    try {
      // Get onboarding link
      final onboardingUrl = await StripeConnectService.getOnboardingLink(
        refreshUrl: 'myapp://stripe-refresh',
        returnUrl: 'myapp://stripe-return',
      );

      if (onboardingUrl != null) {
        // Launch Stripe onboarding in browser
        final uri = Uri.parse(onboardingUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          if (mounted) {
            // Show dialog explaining what to do
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Complete Onboarding'),
                content: const Text(
                  'You\'ll be redirected to Stripe to:\n\n'
                  '• Verify your identity\n'
                  '• Add your bank account\n'
                  '• Provide business details\n\n'
                  'Return to the app when complete.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _checkAccountStatus(); // Refresh status
                    },
                    child: const Text('I\'ve Completed Onboarding'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get onboarding link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createAccount() async {
    setState(() => _isLoading = true);

    try {
      final result = await StripeConnectService.createAccount();
      
      if (result != null && result['stripe_account_id'] != null) {
        setState(() {
          _isConnected = true;
          _stripeAccountId = result['stripe_account_id'];
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stripe account created!')),
          );
        }
        
        // Automatically start onboarding
        await _startOnboarding();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating account: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe Connect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAccountStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            _onboardingComplete
                                ? Icons.check_circle
                                : Icons.account_balance,
                            size: 64,
                            color: _onboardingComplete
                                ? Colors.green
                                : Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _onboardingComplete
                                ? 'Account Connected!'
                                : 'Connect Your Bank',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _onboardingComplete
                                ? 'You can now deposit and withdraw real money'
                                : 'Enable deposits and withdrawals to your bank account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Section
                  _buildStatusSection(),
                  const SizedBox(height: 24),

                  // Benefits Section
                  if (!_onboardingComplete) ...[
                    const Text(
                      'Why Connect?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitItem(
                      icon: Icons.add_circle,
                      title: 'Add Money',
                      description: 'Deposit funds from your bank to your wallet',
                    ),
                    _buildBenefitItem(
                      icon: Icons.arrow_circle_up,
                      title: 'Cash Out',
                      description: 'Withdraw wallet balance to your bank account',
                    ),
                    _buildBenefitItem(
                      icon: Icons.security,
                      title: 'Secure',
                      description: 'Bank-level security powered by Stripe',
                    ),
                    _buildBenefitItem(
                      icon: Icons.flash_on,
                      title: 'Fast',
                      description: 'Instant deposits, withdrawals in 2-3 days',
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Button
                  if (!_isConnected)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _createAccount,
                        child: const Text(
                          'Create Stripe Account',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    )
                  else if (!_onboardingComplete)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _startOnboarding,
                        child: const Text(
                          'Complete Onboarding',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, true); // Return success
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Continue to Wallet',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                  // Requirements Section
                  if (_requirementsDue.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Action Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._requirementsDue.map((req) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle, size: 8),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          req.replaceAll('_', ' ').toUpperCase(),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Connected', _isConnected),
            _buildStatusRow('Onboarding Complete', _onboardingComplete),
            _buildStatusRow('Can Accept Payments', _chargesEnabled),
            _buildStatusRow('Can Withdraw', _payoutsEnabled),
            if (_stripeAccountId != null) ...[
              const Divider(height: 24),
              Text(
                'Account ID',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stripeAccountId!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
