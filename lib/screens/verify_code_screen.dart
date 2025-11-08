import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'reset_password_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String identifier;
  final String method;

  VerifyCodeScreen({required this.identifier, required this.method});

  @override
  _VerifyCodeScreenState createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final codeController = TextEditingController();
  bool isLoading = false;

  void _verifyCode() async {
    final code = codeController.text.trim();

    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter the 6-digit code")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final success = await ApiService.verifyResetCode(widget.identifier, code);

    setState(() {
      isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Code verified!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to reset password screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            identifier: widget.identifier,
            code: code,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid or expired code. Please try again.")),
      );
    }
  }

  void _resendCode() async {
    setState(() {
      isLoading = true;
    });

    final result = await ApiService.forgotPassword(widget.identifier);

    setState(() {
      isLoading = false;
    });

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("New code sent!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to resend code. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodName = widget.method == 'sms' ? 'phone' : 'email';

    return Scaffold(
      appBar: AppBar(title: Text("Verify Code")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20),
                  Icon(
                    Icons.verified_user,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 40),
                  Text(
                    "Enter Verification Code",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "We sent a 6-digit code to your $methodName. The code expires in 15 minutes.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: codeController,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: "Verification Code",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      counterText: "",
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verifyCode,
                      child: Text(
                        "Verify Code",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: isLoading ? null : _resendCode,
                    child: Text("Didn't receive code? Resend"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Back"),
                  ),
                ],
              ),
            ),
    );
  }
}
