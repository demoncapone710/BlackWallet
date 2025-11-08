import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/qr_code_service.dart';

class ReceiveMoneyScreen extends StatefulWidget {
  const ReceiveMoneyScreen({Key? key}) : super(key: key);

  @override
  State<ReceiveMoneyScreen> createState() => _ReceiveMoneyScreenState();
}

class _ReceiveMoneyScreenState extends State<ReceiveMoneyScreen> {
  String? _username;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  double _amount = 0.0;
  String? _note;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final username = await ApiService.getCurrentUsername();
    setState(() => _username = username);
  }

  String _generateQRData() {
    if (_username == null) return '';
    return QRCodeService.generateBlackWalletQR(
      username: _username!,
      amount: _amount > 0 ? _amount : null,
      note: _note,
    );
  }

  void _copyToClipboard() {
    if (_username != null) {
      Clipboard.setData(ClipboardData(text: '@$_username'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareQRCode() {
    if (_username != null) {
      final message = _amount > 0
          ? 'Send me \$${_amount.toStringAsFixed(2)} on BlackWallet: @$_username'
          : 'Send me money on BlackWallet: @$_username';
      Share.share(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Money'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Show QR Code to Receive',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Others can scan this to send you money',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Optional Amount
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Details (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$ ',
                        hintText: '0.00',
                        suffixIcon: _amount > 0
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _amountController.clear();
                                  setState(() => _amount = 0.0);
                                },
                              )
                            : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _amount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Note',
                        hintText: 'What\'s this for?',
                        suffixIcon: _note != null && _note!.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _noteController.clear();
                                  setState(() => _note = null);
                                },
                              )
                            : null,
                      ),
                      maxLength: 100,
                      onChanged: (value) {
                        setState(() {
                          _note = value.isEmpty ? null : value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // QR Code
            if (_username != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: _generateQRData(),
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '@$_username',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (_amount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '\$${_amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                    if (_note != null && _note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _note!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code, color: Colors.blue[700], size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your Personal Payment QR Code',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Scan this code to receive payments instantly\n'
                    '• Set an amount or let others choose\n'
                    '• Share via screenshot or username\n'
                    '• Works only with BlackWallet users',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[900],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
