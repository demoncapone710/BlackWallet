import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';

class SystemConfigScreen extends StatefulWidget {
  const SystemConfigScreen({Key? key}) : super(key: key);

  @override
  State<SystemConfigScreen> createState() => _SystemConfigScreenState();
}

class _SystemConfigScreenState extends State<SystemConfigScreen> {
  bool _isLoading = true;
  String _currentMode = 'test';
  String? _error;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMode();
  }

  Future<void> _loadCurrentMode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/admin/config/stripe-mode'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentMode = data['mode'];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load configuration');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _switchStripeMode(String newMode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${newMode.toUpperCase()} Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (newMode == 'live') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '⚠️ WARNING: LIVE MODE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This will process REAL money transactions!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('• Real charges to credit cards'),
                    Text('• Real bank transfers'),
                    Text('• Real fees will apply'),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '🧪 TEST MODE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Safe for development and testing'),
                    Text('• No real charges'),
                    Text('• Test cards only'),
                    Text('• No real money involved'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Note: Server restart required for changes to take effect.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newMode == 'live' ? Colors.red : Colors.blue,
            ),
            child: Text('Switch to ${newMode.toUpperCase()}'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSwitching = true;
      });

      try {
        final token = await ApiService.getToken();
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/admin/config/stripe-mode'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'mode': newMode}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Restart Server',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please restart the server manually'),
                    ),
                  );
                },
              ),
            ),
          );
          
          await _loadCurrentMode();
        } else {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Failed to switch mode');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSwitching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentMode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _loadCurrentMode,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCurrentMode,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentModeCard(),
                        const SizedBox(height: 24),
                        _buildModeSwitcher(),
                        const SizedBox(height: 24),
                        _buildSystemInfo(),
                        const SizedBox(height: 24),
                        _buildDangerZone(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCurrentModeCard() {
    final isLive = _currentMode == 'live';
    
    return Card(
      elevation: 4,
      color: isLive ? Colors.red.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLive ? Icons.warning_rounded : Icons.science_rounded,
                  size: 32,
                  color: isLive ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Stripe Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _currentMode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isLive ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLive ? Colors.red : Colors.blue,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLive ? '⚠️ LIVE MODE ACTIVE' : '🧪 TEST MODE ACTIVE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLive ? Colors.red : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLive
                        ? 'All transactions are processing real money. Real charges, transfers, and fees apply.'
                        : 'All transactions are simulated. Safe for development and testing. No real money involved.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Switch Stripe Mode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    'Test Mode',
                    Icons.science_rounded,
                    Colors.blue,
                    _currentMode == 'test',
                    () => _switchStripeMode('test'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModeButton(
                    'Live Mode',
                    Icons.warning_rounded,
                    Colors.red,
                    _currentMode == 'live',
                    () => _switchStripeMode('live'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    String label,
    IconData icon,
    Color color,
    bool isActive,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: isActive || _isSwitching ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color : Colors.grey.shade300,
        foregroundColor: isActive ? Colors.white : Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(vertical: 20),
        elevation: isActive ? 8 : 2,
      ),
      child: Column(
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 4),
            const Text(
              'ACTIVE',
              style: TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemInfo() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Environment', _currentMode.toUpperCase()),
            _buildInfoRow('API Base URL', ApiService.baseUrl),
            _buildInfoRow('Last Updated', DateTime.now().toString().substring(0, 19)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Server restart required after changing Stripe mode for changes to take effect.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      elevation: 4,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Switching to LIVE mode will process real money transactions. Only do this when:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text('✓ You have tested thoroughly in TEST mode', style: TextStyle(fontSize: 12)),
            const Text('✓ Your Stripe account is fully verified', style: TextStyle(fontSize: 12)),
            const Text('✓ You have proper bank accounts connected', style: TextStyle(fontSize: 12)),
            const Text('✓ You understand the fees and regulations', style: TextStyle(fontSize: 12)),
            const Text('✓ You have legal compliance in place', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
