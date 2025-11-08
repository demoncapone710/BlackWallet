import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';

class SendMoneyScreen extends StatefulWidget {
  @override
  _SendMoneyScreenState createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final recipientController = TextEditingController();
  final routingNumberController = TextEditingController();
  final noteController = TextEditingController();
  
  String selectedMethod = 'username'; // username, phone, bank, email
  bool isLoading = false;
  bool instantTransfer = false; // For bank withdrawals
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await ApiService.getBalance();
      setState(() {
        walletBalance = balance ?? 0.0;
      });
    } catch (e) {
      print('Error loading balance: $e');
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    recipientController.dispose();
    routingNumberController.dispose();
    noteController.dispose();
    super.dispose();
  }

  String _getMethodLabel() {
    switch (selectedMethod) {
      case 'username':
        return 'Username';
      case 'phone':
        return 'Phone Number';
      case 'bank':
        return 'Bank Account';
      case 'email':
        return 'Email Address';
      default:
        return 'Recipient';
    }
  }

  String _getMethodHint() {
    switch (selectedMethod) {
      case 'username':
        return 'Enter username';
      case 'phone':
        return '+1 234 567 8900';
      case 'bank':
        return 'Account number';
      case 'email':
        return 'user@example.com';
      default:
        return '';
    }
  }

  IconData _getMethodIcon() {
    switch (selectedMethod) {
      case 'username':
        return Icons.person;
      case 'phone':
        return Icons.phone;
      case 'bank':
        return Icons.account_balance;
      case 'email':
        return Icons.email;
      default:
        return Icons.person;
    }
  }

  List<TextInputFormatter> _getInputFormatters() {
    if (selectedMethod == 'phone') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ];
    } else if (selectedMethod == 'bank') {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(20),
      ];
    }
    return [];
  }

  String? _validateRecipient(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter ${_getMethodLabel().toLowerCase()}';
    }

    switch (selectedMethod) {
      case 'username':
        if (value.length < 3) {
          return 'Username must be at least 3 characters';
        }
        break;
      case 'phone':
        if (value.replaceAll(RegExp(r'\D'), '').length < 10) {
          return 'Please enter a valid phone number';
        }
        break;
      case 'bank':
        if (value.replaceAll('-', '').length < 8) {
          return 'Please enter a valid account number';
        }
        break;
      case 'email':
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        break;
    }
    return null;
  }

  Future<void> _sendMoney() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount > walletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    // Require biometric authentication for transactions >= $500
    if (amount >= 500) {
      final biometricService = BiometricService();
      final isAuthenticated = await biometricService.authenticateTransaction(amount);
      
      if (!isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication required for large transactions'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      String recipient = recipientController.text.trim();
      // Note: transactionNote could be used for future API enhancements
      String transactionNote = noteController.text.trim();
      // Suppress unused warning by logging it
      if (transactionNote.isNotEmpty) {
        print('Transaction note: $transactionNote');
      }

      // Get current user's username
      final currentUsername = await ApiService.getCurrentUsername();
      if (currentUsername == null) {
        throw Exception('Could not get current user');
      }

      // Use appropriate API based on transfer method
      if (selectedMethod == 'username') {
        await ApiService.transfer(currentUsername, recipient, amount);
      } else if (selectedMethod == 'bank') {
        // Validate routing number for bank transfers
        String routingNumber = routingNumberController.text.trim();
        if (routingNumber.isEmpty || routingNumber.length != 9) {
          throw Exception('Valid routing number required for bank transfers');
        }
        // For bank transfers, use withdrawToBank with instant transfer option
        final result = await ApiService.withdrawToBank(
          recipient, 
          amount,
          instantTransfer: instantTransfer,
        );
        
        if (result == null) {
          throw Exception('Withdrawal failed');
        }
        
        // Show detailed success message with fee info
        final instantFee = result['instant_fee'] ?? 0.0;
        final totalDeducted = result['total_deducted'] ?? amount;
        final transferTime = instantTransfer ? 'within minutes' : '1-3 business days';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              instantTransfer
                ? 'Instant transfer of \$${amount.toStringAsFixed(2)} initiated!\n' +
                  'Fee: \$${instantFee.toStringAsFixed(2)} | Total: \$${totalDeducted.toStringAsFixed(2)}\n' +
                  'Funds will arrive $transferTime'
                : 'Transfer of \$${amount.toStringAsFixed(2)} initiated!\n' +
                  'Funds will arrive in $transferTime'
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Show notification
        final notificationService = NotificationService();
        await notificationService.showMoneySentNotification(amount, 'Bank Account');
        
        Navigator.pop(context, true);
        return;
      } else if (selectedMethod == 'phone') {
        // Send money via phone number
        await ApiService.sendMoneyByContact(recipient, amount, 'phone');
      } else if (selectedMethod == 'email') {
        // Send money via email
        await ApiService.sendMoneyByContact(recipient, amount, 'email');
      }

      // Show success notification
      final notificationService = NotificationService();
      await notificationService.showMoneySentNotification(amount, recipient);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully sent \$${amount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Send Money'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Available Balance',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '\$${walletBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Send Method Selection
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send To',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMethodButton(
                        'username',
                        Icons.person,
                        'Username',
                      ),
                      SizedBox(width: 8),
                      _buildMethodButton(
                        'phone',
                        Icons.phone,
                        'Phone',
                      ),
                      SizedBox(width: 8),
                      _buildMethodButton(
                        'bank',
                        Icons.account_balance,
                        'Bank',
                      ),
                      SizedBox(width: 8),
                      _buildMethodButton(
                        'email',
                        Icons.email,
                        'Email',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Form
            Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Recipient Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: recipientController,
                        inputFormatters: _getInputFormatters(),
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: _getMethodLabel(),
                          hintText: _getMethodHint(),
                          prefixIcon: Icon(
                            _getMethodIcon(),
                            color: Colors.black,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: _validateRecipient,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Routing Number Input (only for bank transfers)
                    if (selectedMethod == 'bank')
                      Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: routingNumberController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(9),
                              ],
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Routing Number',
                                hintText: '9 digits',
                                prefixIcon: Icon(
                                  Icons.route,
                                  color: Colors.black,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                helperText: 'Found on bottom left of check',
                              ),
                              validator: selectedMethod == 'bank'
                                  ? (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter routing number';
                                      }
                                      if (value.length != 9) {
                                        return 'Routing number must be 9 digits';
                                      }
                                      return null;
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Instant Transfer Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: instantTransfer ? Color(0xFFDC143C) : Colors.grey[300]!,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SwitchListTile(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.flash_on,
                                    color: instantTransfer ? Color(0xFFDC143C) : Colors.grey,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Instant Transfer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.only(top: 8, left: 28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      instantTransfer 
                                        ? '⚡ Arrives within minutes'
                                        : '🕐 Arrives in 1-3 business days',
                                      style: TextStyle(
                                        color: instantTransfer ? Color(0xFFDC143C) : Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (instantTransfer && amountController.text.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Builder(
                                          builder: (context) {
                                            final amount = double.tryParse(amountController.text) ?? 0;
                                            final fee = amount > 0 ? (amount * 0.015).clamp(0.25, double.infinity) : 0;
                                            return Text(
                                              'Fee: \$${fee.toStringAsFixed(2)} (1.5%, min \$0.25)',
                                              style: TextStyle(
                                                color: Colors.orange[700],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              value: instantTransfer,
                              activeColor: Color(0xFFDC143C),
                              onChanged: (value) {
                                setState(() {
                                  instantTransfer = value;
                                });
                              },
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),

                    // Amount Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Colors.black,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          if (amount > walletBalance) {
                            return 'Insufficient balance';
                          }
                          return null;
                        },
                      ),
                    ),

                    SizedBox(height: 16),

                    // Quick Amount Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickAmountButton(10),
                        _buildQuickAmountButton(25),
                        _buildQuickAmountButton(50),
                        _buildQuickAmountButton(100),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Note Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: noteController,
                        maxLines: 3,
                        maxLength: 100,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Note (Optional)',
                          hintText: 'Add a note...',
                          prefixIcon: Icon(
                            Icons.note,
                            color: Colors.black,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: 32),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _sendMoney,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Send Money',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodButton(String method, IconData icon, String label) {
    final isSelected = selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedMethod = method;
            recipientController.clear();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(double amount) {
    return OutlinedButton(
      onPressed: () {
        amountController.text = amount.toStringAsFixed(0);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text('\$$amount'),
    );
  }
}
