import 'package:flutter/material.dart';
import '../services/pin_service.dart';

class PinSetupScreen extends StatefulWidget {
  @override
  _PinSetupScreenState createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PIN must be at least 4 digits')));
      return;
    }
    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PINs do not match')));
      return;
    }

    setState(() => _isSaving = true);
    await PinService.setPin(pin);
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PIN set successfully')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set PIN')),
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
            SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(labelText: 'Confirm PIN', prefixIcon: Icon(Icons.lock_outline)),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePin,
                child: _isSaving ? CircularProgressIndicator(color: Colors.white) : Text('Save PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
