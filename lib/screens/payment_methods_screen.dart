import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'manual_card_entry_screen.dart';
import 'add_bank_account_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _loading = true);
    final methods = await ApiService.getPaymentMethods();
    setState(() {
      _paymentMethods = methods;
      _loading = false;
    });
  }

  Future<void> _removePaymentMethod(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Payment Method'),
        content: const Text('Are you sure you want to remove this payment method?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.removePaymentMethod(id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment method removed')),
        );
        _loadPaymentMethods();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove payment method')),
        );
      }
    }
  }

  IconData _getIcon(String type, String? brand) {
    if (type == 'card') {
      if (brand?.toLowerCase() == 'visa') return Icons.credit_card;
      if (brand?.toLowerCase() == 'mastercard') return Icons.credit_card;
      return Icons.payment;
    }
    return Icons.account_balance;
  }

  void _showAddPaymentMethodDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: const Text('What would you like to add?'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManualCardEntryScreen(),
                ),
              );
              _loadPaymentMethods();
            },
            icon: const Icon(Icons.credit_card),
            label: const Text('Credit/Debit Card'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddBankAccountScreen(),
                ),
              );
              _loadPaymentMethods();
            },
            icon: const Icon(Icons.account_balance),
            label: const Text('Bank Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No payment methods added',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showAddPaymentMethodDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Payment Method'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _paymentMethods.length,
                  itemBuilder: (context, index) {
                    final method = _paymentMethods[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          _getIcon(method['type'], method['brand']),
                          size: 32,
                        ),
                        title: Text(
                          method['type'] == 'card'
                              ? '${method['brand']?.toUpperCase() ?? 'Card'} •••• ${method['last4']}'
                              : 'Bank Account •••• ${method['last4']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          method['is_default'] == true ? 'Default' : '',
                          style: TextStyle(color: Colors.green[700]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removePaymentMethod(method['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentMethodDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: Colors.black,
      ),
    );
  }
}
