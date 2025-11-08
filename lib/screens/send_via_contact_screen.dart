import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:email_validator/email_validator.dart';
import '../services/api_service.dart';

class SendViaContactScreen extends StatefulWidget {
  @override
  _SendViaContactScreenState createState() => _SendViaContactScreenState();
}

class _SendViaContactScreenState extends State<SendViaContactScreen> {
  final contactController = TextEditingController();
  final amountController = TextEditingController();
  bool isLoading = false;
  String contactType = 'phone'; // 'phone' or 'email'
  Map<String, dynamic>? foundUser;

  bool _isEmail(String input) {
    return EmailValidator.validate(input);
  }

  bool _isPhone(String input) {
    final phone = input.replaceAll(RegExp(r'\D'), '');
    return phone.length >= 10 && phone.length <= 15;
  }

  void _lookupUser() async {
    final contact = contactController.text.trim();

    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a phone number or email")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      foundUser = null;
    });

    final result = await ApiService.getUserByContact(contact);

    setState(() {
      isLoading = false;
      foundUser = result;
      
      // Auto-detect contact type
      if (_isEmail(contact)) {
        contactType = 'email';
      } else if (_isPhone(contact)) {
        contactType = 'phone';
      }
    });

    if (result != null && result['found'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("User found: ${result['full_name']}"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _sendMoney() async {
    final contact = contactController.text.trim();
    final amount = double.tryParse(amountController.text);

    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a phone number or email")),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid amount")),
      );
      return;
    }

    // Confirm before sending
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Transfer"),
        content: foundUser != null && foundUser!['found'] == true
            ? Text(
                "Send \$${amount.toStringAsFixed(2)} to ${foundUser!['full_name']}?")
            : Text(
                "Send \$${amount.toStringAsFixed(2)} to $contact?\n\nThey'll receive an invitation to claim this money."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Send"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
    });

    final result = await ApiService.sendMoneyByContact(
      contact,
      amount,
      contactType,
    );

    setState(() {
      isLoading = false;
    });

    if (result != null) {
      final recipientExists = result['recipient_exists'] ?? false;
      final invitationSent = result['invitation_sent'] ?? false;

      String message;
      if (recipientExists) {
        message = "Money sent successfully!";
      } else if (invitationSent) {
        message =
            "Invitation sent! They'll receive your money when they sign up.";
      } else {
        message = "Transfer completed!";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return to previous screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transfer failed. Please check your balance and try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Send via Phone/Email")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20),
                  Icon(
                    Icons.send,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 40),
                  Text(
                    "Send Money",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Send money to anyone using their phone number or email address.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: contactController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: "Phone Number or Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search),
                      hintText: "1234567890 or email@example.com",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search),
                        onPressed: isLoading ? null : _lookupUser,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        foundUser = null;
                      });
                    },
                  ),
                  if (foundUser != null && foundUser!['found'] == true) ...[
                    SizedBox(height: 16),
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foundUser!['full_name'] ?? 'User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '@${foundUser!['username']}',
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
                      ),
                    ),
                  ],
                  if (foundUser != null && foundUser!['found'] == false) ...[
                    SizedBox(height: 16),
                    Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "User not found. We'll send them an invitation to join BlackWallet!",
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    style: TextStyle(color: Colors.black),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: "Amount",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      hintText: "0.00",
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _sendMoney,
                      child: Text(
                        "Send Money",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "💡 Tip: If they don't have BlackWallet yet, they'll get an SMS or email with instructions to claim their money!",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
