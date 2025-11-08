import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:email_validator/email_validator.dart';
import '../services/api_service.dart';
import '../services/permissions_service.dart';

class SendMoneyInviteScreen extends StatefulWidget {
  const SendMoneyInviteScreen({Key? key}) : super(key: key);

  @override
  State<SendMoneyInviteScreen> createState() => _SendMoneyInviteScreenState();
}

class _SendMoneyInviteScreenState extends State<SendMoneyInviteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedMethod = 'username';
  Contact? _selectedContact;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        if (_tabController.index == 0) _selectedMethod = 'username';
        if (_tabController.index == 1) _selectedMethod = 'email';
        if (_tabController.index == 2) _selectedMethod = 'phone';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    // Request contacts permission
    final hasPermission = await PermissionsService.requestContactsPermission(context);
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission is required')),
      );
      return;
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        setState(() {
          _selectedContact = contact;
          
          // Auto-fill based on available information
          if (_tabController.index == 1 && contact.emails.isNotEmpty) {
            _emailController.text = contact.emails.first.address;
          } else if (_tabController.index == 2 && contact.phones.isNotEmpty) {
            _phoneController.text = contact.phones.first.number;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking contact: $e')),
      );
    }
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    String contact = '';
    if (_selectedMethod == 'username') {
      contact = _usernameController.text.trim();
    } else if (_selectedMethod == 'email') {
      contact = _emailController.text.trim();
    } else if (_selectedMethod == 'phone') {
      contact = _phoneController.text.trim().replaceAll(RegExp(r'[^\d+]'), '');
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.sendMoneyInvite(
        method: _selectedMethod,
        contact: contact,
        amount: amount,
        message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      );

      if (!mounted) return;

      // Show success dialog with tracking info
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Money Sent!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: \$${amount.toStringAsFixed(2)}'),
              Text('To: $contact'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⏰ Expires in 24 hours',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Recipient has 24 hours to accept. If not accepted, funds will be automatically refunded.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can track this invite in the "Sent Invites" tab.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to previous screen
              },
              child: const Text('Done'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Navigate to invite tracking screen
                Navigator.pushNamed(context, '/invite-tracking');
              },
              child: const Text('Track Invite'),
            ),
          ],
        ),
      );

      // Clear form
      _usernameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _amountController.clear();
      _messageController.clear();
      setState(() => _selectedContact = null);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Username'),
            Tab(icon: Icon(Icons.email), text: 'Email'),
            Tab(icon: Icon(Icons.phone), text: 'Phone'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tab content
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUsernameTab(),
                  _buildEmailTab(),
                  _buildPhoneTab(),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Amount field
            TextFormField(
              controller: _amountController,
              style: const TextStyle(color: Colors.black),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixText: '\$',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                if (amount > 10000) {
                  return 'Maximum amount is \$10,000';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Message field
            TextFormField(
              controller: _messageController,
              style: const TextStyle(color: Colors.black),
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Message (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Add a personal message...',
                helperText: 'Let them know what this money is for',
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Funds are deducted from your account immediately\n'
                    '• Recipient has 24 hours to accept\n'
                    '• If not accepted, you\'ll be refunded automatically\n'
                    '• You\'ll get notifications when they open/accept',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Send button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendInvite,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send),
                          SizedBox(width: 8),
                          Text('Send Money Invite', style: TextStyle(fontSize: 18)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Send to BlackWallet User',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            labelText: 'Username *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
            hintText: 'Enter username',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a username';
            }
            if (value.length < 3) {
              return 'Username must be at least 3 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Send via Email',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _pickContact,
              icon: const Icon(Icons.contacts, size: 20),
              label: const Text('Pick Contact'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: Colors.black),
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
            hintText: 'recipient@example.com',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an email';
            }
            if (!EmailValidator.validate(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        if (_selectedContact != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Selected: ${_selectedContact!.displayName}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Send via SMS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _pickContact,
              icon: const Icon(Icons.contacts, size: 20),
              label: const Text('Pick Contact'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          style: const TextStyle(color: Colors.black),
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
            hintText: '+1 (555) 123-4567',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a phone number';
            }
            final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');
            if (cleaned.length < 10) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
        if (_selectedContact != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Selected: ${_selectedContact!.displayName}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ),
      ],
    );
  }
}
