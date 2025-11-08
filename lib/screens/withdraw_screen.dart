import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WithdrawScreen extends StatefulWidget {
  final double currentBalance;
  
  const WithdrawScreen({Key? key, required this.currentBalance}) : super(key: key);

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amountController = TextEditingController();
  List<Map<String, dynamic>> _paymentMethods = [];
  int? _selectedPaymentMethodId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final methods = await ApiService.getPaymentMethods();
    setState(() {
      _paymentMethods = methods.where((m) => m['type'] == 'bank_account').toList();
      if (_paymentMethods.isNotEmpty) {
        _selectedPaymentMethodId = _paymentMethods[0]['id'];
      }
    });
  }

  Future<void> _withdraw() async {
    if (_selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a bank account first')),
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

    if (amount > widget.currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    setState(() => _loading = true);

    final result = await ApiService.withdrawToBank(
      _selectedPaymentMethodId!.toString(),
      amount,
    );

    setState(() => _loading = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal of \$${amount.toStringAsFixed(2)} initiated\nTypically arrives in 1-3 business days'),
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.pop(context, true); // Return true to indicate balance changed
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Money'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Withdraw to Bank Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available: \$${widget.currentBalance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            if (_paymentMethods.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No bank accounts linked.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please go to Payment Methods to add a bank account for withdrawals.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                'Select Bank Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _selectedPaymentMethodId,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem<int>(
                    value: method['id'],
                    child: Text('Bank Account •••• ${method['last4']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethodId = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '0.00',
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [10, 25, 50, 100].map((amount) {
                  return ActionChip(
                    label: Text(
                      '\$$amount',
                      style: const TextStyle(color: Colors.black),
                    ),
                    onPressed: () {
                      if (amount <= widget.currentBalance) {
                        _amountController.text = amount.toString();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _amountController.text = widget.currentBalance.toStringAsFixed(2);
                },
                child: const Text('Withdraw All'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading || _paymentMethods.isEmpty ? null : _withdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Withdraw Now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ACH transfers typically take 1-3 business days to arrive in your bank account. '
                      'No fees for standard transfers.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
