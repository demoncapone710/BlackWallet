import 'package:flutter/material.dart';
import '../services/bluetooth_advertising_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothAdvertisingScreen extends StatefulWidget {
  const BluetoothAdvertisingScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothAdvertisingScreen> createState() => _BluetoothAdvertisingScreenState();
}

class _BluetoothAdvertisingScreenState extends State<BluetoothAdvertisingScreen> {
  final BluetoothAdvertisingService _bluetoothService = BluetoothAdvertisingService();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isAdvertising = false;
  bool _isLoading = false;
  String _statusMessage = '';
  List<ScanResult> _nearbyDevices = [];
  
  @override
  void initState() {
    super.initState();
    _messageController.text = _bluetoothService.advertisementMessage;
    _isAdvertising = _bluetoothService.isAdvertising;
    
    // Listen to scan results
    _bluetoothService.scanForDevices().listen((results) {
      if (mounted) {
        setState(() {
          _nearbyDevices = results;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  
  Future<void> _toggleAdvertising() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });
    
    try {
      if (_isAdvertising) {
        await _bluetoothService.stopAdvertising();
        setState(() {
          _isAdvertising = false;
          _statusMessage = 'Advertising stopped';
        });
      } else {
        final success = await _bluetoothService.startAdvertising(
          customMessage: _messageController.text,
        );
        
        if (success) {
          setState(() {
            _isAdvertising = true;
            _statusMessage = 'Advertising started successfully';
          });
        } else {
          setState(() {
            _statusMessage = 'Failed to start advertising. Check Bluetooth permissions and settings.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _scanForDevices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Scanning for nearby devices...';
      _nearbyDevices.clear();
    });
    
    try {
      await _bluetoothService.startScan(timeout: Duration(seconds: 10));
      
      // Wait for scan to complete
      await Future.delayed(Duration(seconds: 10));
      
      setState(() {
        _statusMessage = 'Scan complete. Found ${_nearbyDevices.length} devices.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error scanning: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Advertising'),
        backgroundColor: Color(0xFF0A0A0A),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_searching,
                      size: 64,
                      color: _isAdvertising ? Color(0xFFDC143C) : Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _isAdvertising ? 'Broadcasting Active' : 'Broadcasting Inactive',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Share your ads with nearby devices',
                      style: TextStyle(color: Color(0xFF888888)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Advertisement Message Input
            Text(
              'Advertisement Message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 200,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Enter your advertisement message...',
                helperText: 'This message will be broadcast to nearby devices',
                helperStyle: TextStyle(color: Color(0xFF888888)),
              ),
              enabled: !_isAdvertising,
            ),
            
            SizedBox(height: 16),
            
            // Start/Stop Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _toggleAdvertising,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(_isAdvertising ? Icons.stop : Icons.play_arrow),
              label: Text(_isAdvertising ? 'Stop Broadcasting' : 'Start Broadcasting'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isAdvertising ? Colors.red[900] : Color(0xFFDC143C),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Status Message
            if (_statusMessage.isNotEmpty)
              Card(
                color: Color(0xFF2A2A2A),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                            ? Icons.error_outline
                            : Icons.info_outline,
                        color: _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                            ? Colors.red
                            : Color(0xFFDC143C),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 24),
            
            // Scan for Devices Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nearby Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _scanForDevices,
                  icon: Icon(Icons.refresh),
                  label: Text('Scan'),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Nearby Devices List
            if (_nearbyDevices.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        size: 48,
                        color: Color(0xFF888888),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No devices found',
                        style: TextStyle(color: Color(0xFF888888)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap "Scan" to search for nearby Bluetooth devices',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._nearbyDevices.map((result) => Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.bluetooth,
                    color: Color(0xFFDC143C),
                  ),
                  title: Text(
                    result.device.platformName.isNotEmpty
                        ? result.device.platformName
                        : 'Unknown Device',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    result.device.remoteId.toString(),
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                  trailing: Text(
                    '${result.rssi} dBm',
                    style: TextStyle(color: Color(0xFF888888)),
                  ),
                ),
              )).toList(),
            
            SizedBox(height: 24),
            
            // Info Card
            Card(
              color: Color(0xFF1A1A2E),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFFDC143C),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• Your advertisement will be broadcast to nearby Bluetooth-enabled devices\n'
                      '• Devices within range can discover your message\n'
                      '• Broadcasting requires Bluetooth and location permissions\n'
                      '• Keep the app running to maintain broadcasting',
                      style: TextStyle(
                        color: Color(0xFFCCCCCC),
                        fontSize: 13,
                        height: 1.5,
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
}
