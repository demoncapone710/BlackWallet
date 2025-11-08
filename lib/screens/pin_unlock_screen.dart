import 'package:flutter/material.dart';
import '../services/pin_service.dart';

class PinUnlockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  const PinUnlockScreen({Key? key, this.onUnlocked}) : super(key: key);

  @override
  _PinUnlockScreenState createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _pinController = TextEditingController();
  bool _isChecking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkPin() async {
    final pin = _pinController.text.trim();
    setState(() => _isChecking = true);
    final ok = await PinService.verifyPin(pin);
    setState(() => _isChecking = false);
    if (ok) {
      if (widget.onUnlocked != null) widget.onUnlocked!();
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incorrect PIN')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Unlock with PIN')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextFormField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(labelText: 'Enter PIN', prefixIcon: Icon(Icons.lock)),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChecking ? null : _checkPin,
                child: _isChecking ? CircularProgressIndicator(color: Colors.white) : Text('Unlock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
