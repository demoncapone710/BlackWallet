import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../services/api_service.dart';
import 'verify_code_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final identifierController = TextEditingController();
  bool isLoading = false;

  bool _isEmail(String input) {
    return EmailValidator.validate(input);
  }

  bool _isPhone(String input) {
    final phone = input.replaceAll(RegExp(r'\D'), '');
    return phone.length >= 10 && phone.length <= 15;
  }

  void _requestResetCode() async {
    final identifier = identifierController.text.trim();

    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your email or phone number")),
      );
      return;
    }

    if (!_isEmail(identifier) && !_isPhone(identifier)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid email or phone number")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final result = await ApiService.forgotPassword(identifier);

    setState(() {
      isLoading = false;
    });

    if (result != null) {
      final method = result['method'] ?? 'email';
      final methodName = method == 'sms' ? 'phone' : 'email';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Reset code sent to your $methodName!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to verification screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyCodeScreen(
            identifier: identifier,
            method: method,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send reset code. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Forgot Password")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20),
                  Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 40),
                  Text(
                    "Reset Your Password",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Enter your email address or phone number. We'll send you a code to reset your password.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: identifierController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: "Email or Phone Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      hintText: "email@example.com or 1234567890",
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _requestResetCode,
                      child: Text(
                        "Send Reset Code",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Back to Login"),
                  ),
                ],
              ),
            ),
    );
  }
}
