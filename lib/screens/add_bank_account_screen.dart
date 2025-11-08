import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class AddBankAccountScreen extends StatefulWidget {
  const AddBankAccountScreen({Key? key}) : super(key: key);

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountHolderController = TextEditingController();
  final _routingNumberController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  
  String _accountType = 'checking';
  bool _loading = false;

  Future<void> _addBankAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountNumberController.text != _confirmAccountController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account numbers do not match')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final success = await ApiService.addBankAccount(
        _accountNumberController.text,
        _routingNumberController.text,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank account added! Verification may be required.'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add bank account')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Bank Account'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Link Your Bank Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For ACH transfers and withdrawals',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              
              // Account Holder Name
              TextFormField(
                controller: _accountHolderController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Account Holder Name',
                  hintText: 'John Doe',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Account Type
              DropdownButtonFormField<String>(
                initialValue: _accountType,
                decoration: InputDecoration(
                  labelText: 'Account Type',
                  prefixIcon: const Icon(Icons.account_balance),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'checking', child: Text('Checking')),
                  DropdownMenuItem(value: 'savings', child: Text('Savings')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _accountType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Routing Number
              TextFormField(
                controller: _routingNumberController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Routing Number',
                  hintText: '9 digits',
                  prefixIcon: const Icon(Icons.route),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Found on the bottom left of your check',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter routing number';
                  }
                  if (value.length != 9) {
                    return 'Routing number must be 9 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Account Number
              TextFormField(
                controller: _accountNumberController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  hintText: 'Enter account number',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(17),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account number';
                  }
                  if (value.length < 4 || value.length > 17) {
                    return 'Invalid account number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Confirm Account Number
              TextFormField(
                controller: _confirmAccountController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Confirm Account Number',
                  hintText: 'Re-enter account number',
                  prefixIcon: const Icon(Icons.check_circle),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(17),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm account number';
                  }
                  if (value != _accountNumberController.text) {
                    return 'Account numbers do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Info Box - How to find
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Where to find these numbers:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Routing Number: Bottom left of your check (9 digits)\n'
                      '• Account Number: Bottom middle of your check\n'
                      '• Or find them in your bank\'s mobile app',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Security Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.green[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your banking information is encrypted and secure. '
                        'We use bank-level security to protect your data.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Test Mode Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Test Mode: Use routing 110000000, any account number',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _loading ? null : _addBankAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
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
                        'Link Bank Account',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'By linking your bank account, you agree to our Terms of Service and authorize ACH transactions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _routingNumberController.dispose();
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    super.dispose();
  }
}
