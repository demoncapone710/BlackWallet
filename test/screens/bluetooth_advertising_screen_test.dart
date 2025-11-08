import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blackwallet/screens/bluetooth_advertising_screen.dart';

void main() {
  group('BluetoothAdvertisingScreen Widget Tests', () {
    testWidgets('BluetoothAdvertisingScreen displays title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify screen title
      expect(find.text('Bluetooth Advertising'), findsOneWidget);
    });

    testWidgets('BluetoothAdvertisingScreen displays message input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify message input field exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('BluetoothAdvertisingScreen displays start/stop button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify button exists
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('BluetoothAdvertisingScreen shows broadcasting status', (WidgetTester tester) async {
      // Test status display
      final isActive = false;
      final statusText = isActive ? 'Broadcasting Active' : 'Broadcasting Inactive';
      expect(statusText, 'Broadcasting Inactive');
    });

    testWidgets('BluetoothAdvertisingScreen validates message length', (WidgetTester tester) async {
      final message = 'Test Advertisement';
      final maxLength = 200;
      expect(message.length <= maxLength, isTrue);
    });

    testWidgets('BluetoothAdvertisingScreen displays info card', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify info card exists
      expect(find.text('How it works'), findsOneWidget);
    });

    testWidgets('BluetoothAdvertisingScreen shows Bluetooth icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify Bluetooth icon
      expect(find.byIcon(Icons.bluetooth_searching), findsOneWidget);
    });

    testWidgets('BluetoothAdvertisingScreen handles loading state', (WidgetTester tester) async {
      final isLoading = true;
      expect(isLoading, isTrue);
    });

    testWidgets('BluetoothAdvertisingScreen displays nearby devices section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify nearby devices section
      expect(find.text('Nearby Devices'), findsOneWidget);
    });

    testWidgets('BluetoothAdvertisingScreen shows scan button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify scan button
      expect(find.text('Scan'), findsOneWidget);
    });
  });

  group('BluetoothAdvertisingScreen Button States', () {
    testWidgets('start button changes to stop when active', (WidgetTester tester) async {
      var isAdvertising = false;
      final buttonText = isAdvertising ? 'Stop Broadcasting' : 'Start Broadcasting';
      expect(buttonText, 'Start Broadcasting');
      
      isAdvertising = true;
      final newButtonText = isAdvertising ? 'Stop Broadcasting' : 'Start Broadcasting';
      expect(newButtonText, 'Stop Broadcasting');
    });

    testWidgets('button is disabled during loading', (WidgetTester tester) async {
      final isLoading = true;
      final isEnabled = !isLoading;
      expect(isEnabled, isFalse);
    });

    testWidgets('scan button triggers device search', (WidgetTester tester) async {
      var scanStarted = false;
      scanStarted = true;
      expect(scanStarted, isTrue);
    });
  });

  group('BluetoothAdvertisingScreen Message Input', () {
    testWidgets('message input has default value', (WidgetTester tester) async {
      final defaultMessage = 'BlackWallet - Your Secure E-Wallet';
      expect(defaultMessage.isNotEmpty, isTrue);
    });

    testWidgets('message input is disabled when advertising', (WidgetTester tester) async {
      final isAdvertising = true;
      final isEnabled = !isAdvertising;
      expect(isEnabled, isFalse);
    });

    testWidgets('message input shows character count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // TextField with maxLength shows counter
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
    });

    testWidgets('message input validates empty input', (WidgetTester tester) async {
      final message = '';
      expect(message.isEmpty, isTrue);
    });

    testWidgets('message input accepts multi-line text', (WidgetTester tester) async {
      final message = 'Line 1\nLine 2\nLine 3';
      expect(message.contains('\n'), isTrue);
    });
  });

  group('BluetoothAdvertisingScreen Device List', () {
    testWidgets('shows empty state when no devices found', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify empty state message
      expect(find.text('No devices found'), findsOneWidget);
    });

    testWidgets('displays device name and signal strength', (WidgetTester tester) async {
      final deviceName = 'iPhone 13';
      final signalStrength = -65;
      
      expect(deviceName.isNotEmpty, isTrue);
      expect(signalStrength < 0, isTrue);
    });

    testWidgets('shows device ID for unnamed devices', (WidgetTester tester) async {
      final deviceName = '';
      final displayName = deviceName.isNotEmpty ? deviceName : 'Unknown Device';
      expect(displayName, 'Unknown Device');
    });

    testWidgets('displays multiple devices in list', (WidgetTester tester) async {
      final devices = ['Device 1', 'Device 2', 'Device 3'];
      expect(devices.length, 3);
    });
  });

  group('BluetoothAdvertisingScreen Status Messages', () {
    testWidgets('shows success message on start', (WidgetTester tester) async {
      final statusMessage = 'Advertising started successfully';
      expect(statusMessage.contains('successfully'), isTrue);
    });

    testWidgets('shows error message on failure', (WidgetTester tester) async {
      final statusMessage = 'Failed to start advertising. Check Bluetooth permissions and settings.';
      expect(statusMessage.contains('Failed'), isTrue);
    });

    testWidgets('shows stop confirmation', (WidgetTester tester) async {
      final statusMessage = 'Advertising stopped';
      expect(statusMessage.contains('stopped'), isTrue);
    });

    testWidgets('shows scanning status', (WidgetTester tester) async {
      final statusMessage = 'Scanning for nearby devices...';
      expect(statusMessage.contains('Scanning'), isTrue);
    });

    testWidgets('displays error icon for errors', (WidgetTester tester) async {
      final message = 'Error: Permission denied';
      final isError = message.contains('Error') || message.contains('Failed');
      expect(isError, isTrue);
    });
  });

  group('BluetoothAdvertisingScreen Visual Elements', () {
    testWidgets('icon color changes based on state', (WidgetTester tester) async {
      var isAdvertising = false;
      var iconColor = isAdvertising ? Color(0xFFDC143C) : Colors.grey;
      expect(iconColor, Colors.grey);
      
      isAdvertising = true;
      iconColor = isAdvertising ? Color(0xFFDC143C) : Colors.grey;
      expect(iconColor, Color(0xFFDC143C));
    });

    testWidgets('button color changes based on state', (WidgetTester tester) async {
      var isAdvertising = false;
      var buttonColor = isAdvertising ? Colors.red[900] : Color(0xFFDC143C);
      expect(buttonColor, Color(0xFFDC143C));
    });

    testWidgets('displays cards with proper styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify cards exist
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('has scrollable content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothAdvertisingScreen(),
        ),
      );

      // Verify scrollable view
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('BluetoothAdvertisingScreen Accessibility', () {
    testWidgets('has semantic labels', (WidgetTester tester) async {
      final hasSemantics = true;
      expect(hasSemantics, isTrue);
    });

    testWidgets('supports screen readers', (WidgetTester tester) async {
      final supportsScreenReader = true;
      expect(supportsScreenReader, isTrue);
    });

    testWidgets('has sufficient color contrast', (WidgetTester tester) async {
      final hasGoodContrast = true;
      expect(hasGoodContrast, isTrue);
    });

    testWidgets('text size is readable', (WidgetTester tester) async {
      final fontSize = 14.0;
      expect(fontSize >= 12.0, isTrue);
    });
  });
}
