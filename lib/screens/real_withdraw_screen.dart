import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/stripe_connect_service.dart';

class RealWithdrawScreen extends StatefulWidget {
  final double currentBalance;

  const RealWithdrawScreen({super.key, required this.currentBalance});

  @override
  State<RealWithdrawScreen> createState() => _RealWithdrawScreenState();
}

class _RealWithdrawScreenState extends State<RealWithdrawScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _accountConnected = false;
  bool _canWithdraw = false;
  List<dynamic> _bankAccounts = [];
  String? _selectedBankAccount;
  
  // Quick amounts (limited by current balance)
  List<double> get _quickAmounts {
    final amounts = [10.0, 25.0, 50.0, 100.0, 250.0, 500.0];
    return amounts.where((amount) => amount <= widget.currentBalance).toList();
  }

  @override
  void initState() {
    super.initState();
    _checkAccountStatus();
    _loadBankAccounts();
  }

  Future<void> _checkAccountStatus() async {
    final status = await StripeConnectService.getAccountStatus();
    if (status != null && mounted) {
      setState(() {
        _accountConnected = status['connected'] ?? false;
        _canWithdraw = status['payouts_enabled'] ?? false;
      });
    }
  }

  Future<void> _loadBankAccounts() async {
    final accounts = await StripeConnectService.getBankAccounts();
    if (accounts != null && mounted) {
      setState(() {
        _bankAccounts = accounts;
        if (accounts.isNotEmpty) {
          // Select default or first account
          _selectedBankAccount = accounts.firstWhere(
            (acc) => acc['default'] == true,
            orElse: () => accounts.first,
          )['id'];
        }
      });
    }
  }

  Future<void> _processWithdrawal() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum withdrawal is \$1.00')),
      );
      return;
    }

    if (amount > widget.currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Available: \$${widget.currentBalance.toStringAsFixed(2)}',
          ),
        ),
      );
      return;
    }

    if (_bankAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bank account connected')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: \$${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Current Balance: \$${widget.currentBalance.toStringAsFixed(2)}'),
            Text('Remaining Balance: \$${(widget.currentBalance - amount).toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Text(
              'Bank: ${_getSelectedBankName()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Funds will arrive in your bank account within 2-3 business days.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await StripeConnectService.withdraw(amount: amount);

      if (result != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 32),
                const SizedBox(width: 12),
                const Text('Withdrawal Initiated'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: \$${amount.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Transaction ID: ${result['transaction_id']}'),
                const SizedBox(height: 8),
                Text('Status: ${result['status']}'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Estimated Arrival',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result['estimated_arrival'] ?? '2-3 business days',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Return to previous screen
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getSelectedBankName() {
    if (_selectedBankAccount == null || _bankAccounts.isEmpty) {
      return 'No bank selected';
    }
    final bank = _bankAccounts.firstWhere(
      (acc) => acc['id'] == _selectedBankAccount,
      orElse: () => null,
    );
    if (bank == null) return 'Unknown bank';
    return '${bank['bank_name'] ?? 'Bank'} ****${bank['last4']}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Money'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_accountConnected || !_canWithdraw
              ? _buildConnectPrompt()
              : _buildWithdrawalForm(),
    );
  }

  Widget _buildConnectPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Connect Your Bank Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Complete Stripe onboarding to withdraw money to your bank account.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/stripe-onboarding').then((_) {
                    _checkAccountStatus();
                    _loadBankAccounts();
                  });
                },
                child: const Text(
                  'Connect Bank Account',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Balance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available to Withdraw',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${widget.currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_circle_up,
                    size: 48,
                    color: Colors.orange[600],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bank Account Selection
          if (_bankAccounts.isNotEmpty) ...[
            const Text(
              'Withdraw To',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  value: _selectedBankAccount,
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: _bankAccounts.map((bank) {
                    return DropdownMenuItem<String>(
                      value: bank['id'],
                      child: Row(
                        children: [
                          Icon(Icons.account_balance, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bank['bank_name'] ?? 'Bank Account',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '****${bank['last4']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBankAccount = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Amount Input
          const Text(
            'Amount to Withdraw',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              hintText: '0.00',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _amountController.clear(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Amount Buttons
          if (_quickAmounts.isNotEmpty) ...[
            const Text(
              'Quick Select',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._quickAmounts.map((amount) {
                  return ActionChip(
                    label: Text(
                      '\$$amount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _amountController.text = amount.toStringAsFixed(2);
                    },
                    backgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }),
                ActionChip(
                  label: const Text(
                    'All',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    _amountController.text = widget.currentBalance.toStringAsFixed(2);
                  },
                  backgroundColor: Colors.orange[100],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Information Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdrawal Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Arrives in 2-3 business days\n'
                        '• Minimum: \$1.00\n'
                        '• No withdrawal fees\n'
                        '• Secure processing via Stripe',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Withdraw Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading || widget.currentBalance == 0 ? null : _processWithdrawal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_circle_up, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Withdraw Money',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Security Note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Secured by Stripe',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
