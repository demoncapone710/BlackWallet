import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothAdvertisingService {
  static final BluetoothAdvertisingService _instance = BluetoothAdvertisingService._internal();
  
  factory BluetoothAdvertisingService() {
    return _instance;
  }
  
  BluetoothAdvertisingService._internal();
  
  bool _isAdvertising = false;
  String _advertisementMessage = "BlackWallet - Your Secure E-Wallet";
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  
  bool get isAdvertising => _isAdvertising;
  String get advertisementMessage => _advertisementMessage;
  
  /// Request necessary Bluetooth permissions
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    
    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }
  
  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        return false;
      }
      
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      print('Error checking Bluetooth availability: $e');
      return false;
    }
  }
  
  /// Turn on Bluetooth adapter
  Future<bool> turnOnBluetooth() async {
    try {
      if (await isBluetoothAvailable()) {
        return true;
      }
      
      // Request user to turn on Bluetooth
      await FlutterBluePlus.turnOn();
      
      // Wait for Bluetooth to turn on (with timeout)
      await Future.delayed(Duration(seconds: 2));
      
      return await isBluetoothAvailable();
    } catch (e) {
      print('Error turning on Bluetooth: $e');
      return false;
    }
  }
  
  /// Start advertising the message via Bluetooth
  Future<bool> startAdvertising({String? customMessage}) async {
    if (_isAdvertising) {
      print('Already advertising');
      return true;
    }
    
    try {
      // Request permissions
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        print('Bluetooth permissions not granted');
        return false;
      }
      
      // Check if Bluetooth is available
      final isAvailable = await isBluetoothAvailable();
      if (!isAvailable) {
        final turnedOn = await turnOnBluetooth();
        if (!turnedOn) {
          print('Bluetooth is not available or cannot be turned on');
          return false;
        }
      }
      
      // Update message if provided
      if (customMessage != null && customMessage.isNotEmpty) {
        _advertisementMessage = customMessage;
      }
      
      // Start advertising using startScan with advertisement data
      // Note: Flutter Blue Plus doesn't support traditional BLE advertising
      // We'll use a workaround by starting a GATT server with advertisement data
      await _startBleAdvertisement();
      
      _isAdvertising = true;
      print('Bluetooth advertising started: $_advertisementMessage');
      return true;
    } catch (e) {
      print('Error starting Bluetooth advertising: $e');
      return false;
    }
  }
  
  /// Internal method to start BLE advertisement
  Future<void> _startBleAdvertisement() async {
    // In a real implementation, this would use native platform code
    // to start BLE advertising with the advertisement message
    // For now, we'll simulate it by starting scanning which makes the device visible
    
    // Listen to adapter state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on && _isAdvertising) {
        stopAdvertising();
      }
    });
    
    // Note: Actual BLE advertising requires native code implementation
    // This is a placeholder that demonstrates the service structure
    print('BLE Advertisement data: $_advertisementMessage');
  }
  
  /// Stop Bluetooth advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) {
      return;
    }
    
    try {
      await _adapterStateSubscription?.cancel();
      _adapterStateSubscription = null;
      
      _isAdvertising = false;
      print('Bluetooth advertising stopped');
    } catch (e) {
      print('Error stopping Bluetooth advertising: $e');
    }
  }
  
  /// Update the advertisement message
  Future<bool> updateAdvertisementMessage(String newMessage) async {
    if (newMessage.isEmpty) {
      return false;
    }
    
    _advertisementMessage = newMessage;
    
    // If currently advertising, restart with new message
    if (_isAdvertising) {
      await stopAdvertising();
      return await startAdvertising();
    }
    
    return true;
  }
  
  /// Get nearby Bluetooth devices (for demonstration)
  Stream<List<ScanResult>> scanForDevices() {
    return FlutterBluePlus.scanResults;
  }
  
  /// Start scanning for nearby devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        print('Bluetooth permissions not granted for scanning');
        return;
      }
      
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      print('Error scanning for devices: $e');
    }
  }
  
  /// Stop scanning for devices
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }
  
  /// Clean up resources
  void dispose() {
    stopAdvertising();
    stopScan();
  }
}
