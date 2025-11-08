import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../services/api_service.dart';
import '../services/qr_code_service.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({Key? key}) : super(key: key);

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null) {
        _isProcessing = true;
        _processQRCode(scanData.code!);
      }
    });
  }

  void _processQRCode(String qrData) async {
    controller?.pauseCamera();
    
    try {
      // Parse QR code using the service
      final parsed = QRCodeService.parseQRCode(qrData);
      
      if (parsed == null) {
        throw Exception('Unsupported QR code format');
      }
      
      final type = parsed['type'] as String;
      final recipient = parsed['recipient'] as String;
      final amount = parsed['amount'] as double;
      final displayName = parsed['displayName'] as String;
      final note = parsed['note'] as String?;
      
      // Check if we can send money directly
      if (!QRCodeService.canSendMoney(type)) {
        _showExternalAppDialog(type, displayName, recipient);
        return;
      }
      
      // Show payment confirmation for BlackWallet QR codes
      final confirmed = await _showPaymentDialog(
        recipient: recipient,
        displayName: displayName,
        requestedAmount: amount,
        note: note,
      );
      
      if (confirmed != null && confirmed['confirmed'] == true) {
        final sender = await ApiService.getCurrentUsername();
        if (sender == null) {
          throw Exception('Not logged in');
        }
        
        final finalAmount = confirmed['amount'] as double;
        final success = await ApiService.transfer(sender, recipient, finalAmount);
        
        if (success && mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sent \$${finalAmount.toStringAsFixed(2)} to $displayName'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Transfer failed');
        }
      } else {
        controller?.resumeCamera();
        _isProcessing = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      controller?.resumeCamera();
      _isProcessing = false;
    }
  }

  void _showExternalAppDialog(String type, String displayName, String recipient) {
    final typeName = QRCodeService.getTypeName(type);
    final icon = QRCodeService.getIconForType(type);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Text('$typeName Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This is a $typeName payment code:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'BlackWallet cannot send money directly to $typeName. '
              'You can copy this information and use the $typeName app.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller?.resumeCamera();
              _isProcessing = false;
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Could implement clipboard copy here
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Open $typeName app to complete payment')),
              );
              controller?.resumeCamera();
              _isProcessing = false;
            },
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showPaymentDialog({
    required String recipient,
    required String displayName,
    required double requestedAmount,
    String? note,
  }) async {
    final amountController = TextEditingController(
      text: requestedAmount > 0 ? requestedAmount.toStringAsFixed(2) : '',
    );
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send money to:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: requestedAmount == 0,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (requestedAmount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Requested: \$${requestedAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              Navigator.pop(ctx, {
                'confirmed': true,
                'amount': amount,
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Send Money'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Point camera at QR code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supports: BlackWallet, CashApp, Venmo, PayPal',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
