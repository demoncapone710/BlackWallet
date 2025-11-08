import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({Key? key}) : super(key: key);

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController();
  final _checkNumberController = TextEditingController();
  final _routingNumberController = TextEditingController();
  final _accountNumberController = TextEditingController();
  
  String _selectedMethod = 'card'; // card, bank, check, direct
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _banks = [];
  int? _selectedCardId;
  String? _selectedCardStripeId;
  int? _selectedBankId;
  String? _selectedBankStripeId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final methods = await ApiService.getPaymentMethods();
    setState(() {
      _cards = methods.where((m) => m['type'] == 'card').toList();
      _banks = methods.where((m) => m['type'] == 'bank_account').toList();
      
      if (_cards.isNotEmpty) {
        _selectedCardId = _cards[0]['id'];
        _selectedCardStripeId = _cards[0]['stripe_payment_method_id'];
      }
      
      if (_banks.isNotEmpty) {
        _selectedBankId = _banks[0]['id'];
        _selectedBankStripeId = _banks[0]['stripe_payment_method_id'];
      }
    });
  }

  Future<void> _deposit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _loading = true);

    bool success = false;
    String method = '';

    try {
      switch (_selectedMethod) {
        case 'card':
          if (_selectedCardStripeId == null) {
            throw Exception('Please add a card first');
          }
          success = await ApiService.depositFromCard(_selectedCardStripeId!, amount);
          method = 'card';
          break;
          
        case 'bank':
          if (_selectedBankStripeId == null) {
            throw Exception('Please add a bank account first');
          }
          success = await ApiService.depositFromCard(_selectedBankStripeId!, amount);
          method = 'bank account';
          break;
          
        case 'check':
          final checkNumber = _checkNumberController.text.trim();
          if (checkNumber.isEmpty) {
            throw Exception('Please enter check number');
          }
          // Simulate check deposit - in real app, would process through imaging API
          await Future.delayed(const Duration(seconds: 2));
          success = true;
          method = 'check';
          break;
          
        case 'direct':
          final routing = _routingNumberController.text.trim();
          final account = _accountNumberController.text.trim();
          if (routing.isEmpty || account.isEmpty) {
            throw Exception('Please enter routing and account numbers');
          }
          // Simulate direct deposit setup - in real app, would generate account details
          await Future.delayed(const Duration(seconds: 2));
          success = true;
          method = 'direct deposit';
          break;
      }

      setState(() => _loading = false);

      if (success) {
        // Show success notification
        final notificationService = NotificationService();
        await notificationService.showDepositNotification(amount, method);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deposited \$${amount.toStringAsFixed(2)} via $method'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Deposit failed');
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposit Money'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Money to BlackWallet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Deposit Method Selection
            const Text(
              'Select Deposit Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMethodButton('card', Icons.credit_card, 'Card')),
                const SizedBox(width: 8),
                Expanded(child: _buildMethodButton('bank', Icons.account_balance, 'Bank')),
                const SizedBox(width: 8),
                Expanded(child: _buildMethodButton('check', Icons.check_circle, 'Check')),
                const SizedBox(width: 8),
                Expanded(child: _buildMethodButton('direct', Icons.account_balance_wallet, 'Direct')),
              ],
            ),
            const SizedBox(height: 24),
            
            // Method-specific content
            _buildMethodContent(),
            
            const SizedBox(height: 24),
            
            // Amount input
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
            
            // Quick amount buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [10, 25, 50, 100, 250, 500].map((amount) {
                return ActionChip(
                  label: Text(
                    '\$$amount',
                    style: const TextStyle(color: Colors.black),
                  ),
                  backgroundColor: Colors.grey[200],
                  onPressed: () {
                    _amountController.text = amount.toString();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            
            // Deposit button
            ElevatedButton(
              onPressed: _loading ? null : _deposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
                      'Deposit Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 24),
            
            // Info box
            _buildInfoBox(),
          ],
        ),
      ),
    );
  }

  
  Widget _buildMethodButton(String method, IconData icon, String label) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMethodContent() {
    switch (_selectedMethod) {
      case 'card':
        return _buildCardContent();
      case 'bank':
        return _buildBankContent();
      case 'check':
        return _buildCheckContent();
      case 'direct':
        return _buildDirectDepositContent();
      default:
        return const SizedBox();
    }
  }
  
  Widget _buildCardContent() {
    if (_cards.isEmpty) {
      return _buildEmptyState(
        'No cards added',
        'Please add a card in Payment Methods to deposit via card.',
        Icons.credit_card_off,
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select Card',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _selectedCardId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _cards.map((card) {
            return DropdownMenuItem<int>(
              value: card['id'],
              child: Text(
                '${card['brand']?.toUpperCase() ?? 'Card'} •••• ${card['last4']}',
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCardId = value;
              final card = _cards.firstWhere((c) => c['id'] == value);
              _selectedCardStripeId = card['stripe_payment_method_id'];
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildBankContent() {
    if (_banks.isEmpty) {
      return _buildEmptyState(
        'No bank accounts added',
        'Please add a bank account in Payment Methods to deposit via bank.',
        Icons.account_balance,
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select Bank Account',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _selectedBankId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _banks.map((bank) {
            return DropdownMenuItem<int>(
              value: bank['id'],
              child: Text('Bank •••• ${bank['last4']}'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBankId = value;
              final bank = _banks.firstWhere((b) => b['id'] == value);
              _selectedBankStripeId = bank['stripe_payment_method_id'];
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildCheckContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Check Number',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _checkNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            hintText: 'Enter check number',
            prefixIcon: const Icon(Icons.check_circle),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mobile check deposit. Take photos of front and back of your check.',
                  style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDirectDepositContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.grey[800]!],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your BlackWallet Account Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildAccountDetailRow('Routing Number', '123456789'),
              const Divider(color: Colors.grey),
              _buildAccountDetailRow('Account Number', '9876543210'),
              const Divider(color: Colors.grey),
              _buildAccountDetailRow('Account Type', 'Checking'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use these details to set up direct deposit with your employer.',
                  style: TextStyle(fontSize: 12, color: Colors.green[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAccountDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied to clipboard')),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoBox() {
    String info = '';
    switch (_selectedMethod) {
      case 'card':
        info = 'Funds are instantly available. Standard processing fees may apply.';
        break;
      case 'bank':
        info = 'Bank transfers may take 1-3 business days to process.';
        break;
      case 'check':
        info = 'Check deposits are reviewed and typically available within 1-2 business days.';
        break;
      case 'direct':
        info = 'Share these account details with your employer to set up direct deposit.';
        break;
    }
    
    return Container(
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
              info,
              style: TextStyle(fontSize: 12, color: Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _checkNumberController.dispose();
    _routingNumberController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }
}
