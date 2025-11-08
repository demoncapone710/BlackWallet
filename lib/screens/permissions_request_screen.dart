import 'package:flutter/material.dart';
import '../services/permissions_service.dart';

class PermissionsRequestScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const PermissionsRequestScreen({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<PermissionsRequestScreen> createState() => _PermissionsRequestScreenState();
}

class _PermissionsRequestScreenState extends State<PermissionsRequestScreen> {
  final Map<String, bool> _permissions = {
    'camera': false,
    'contacts': false,
    'photos': false,
    'notifications': false,
  };
  
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    final allGranted = _permissions.values.every((granted) => granted);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Setup'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.security, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Grant Permissions',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'To provide you with the best experience, BlackWallet needs access to certain features on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          
          _buildPermissionCard(
            icon: Icons.camera_alt,
            title: 'Camera',
            description: 'Scan QR codes for payments and capture receipts',
            key: 'camera',
            isGranted: _permissions['camera']!,
            onRequest: () async {
              final granted = await PermissionsService.requestCameraPermission(context);
              setState(() => _permissions['camera'] = granted);
            },
          ),
          
          _buildPermissionCard(
            icon: Icons.contacts,
            title: 'Contacts',
            description: 'Easily send money to your contacts',
            key: 'contacts',
            isGranted: _permissions['contacts']!,
            onRequest: () async {
              final granted = await PermissionsService.requestContactsPermission(context);
              setState(() => _permissions['contacts'] = granted);
            },
          ),
          
          _buildPermissionCard(
            icon: Icons.photo_library,
            title: 'Photos',
            description: 'Upload images for checks and payment documents',
            key: 'photos',
            isGranted: _permissions['photos']!,
            onRequest: () async {
              final granted = await PermissionsService.requestPhotosPermission(context);
              setState(() => _permissions['photos'] = granted);
            },
          ),
          
          _buildPermissionCard(
            icon: Icons.notifications,
            title: 'Notifications',
            description: 'Get updates about transactions and security alerts',
            key: 'notifications',
            isGranted: _permissions['notifications']!,
            onRequest: () async {
              final granted = await PermissionsService.requestNotificationPermission(context);
              setState(() => _permissions['notifications'] = granted);
            },
          ),
          
          const SizedBox(height: 24),
          
          if (!allGranted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'You can grant these permissions now or later in settings. Some features may be limited without them.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isRequesting ? null : _handleRequestAll,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isRequesting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      allGranted ? 'Continue' : 'Grant All Permissions',
                      style: const TextStyle(fontSize: 18),
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          if (!allGranted)
            TextButton(
              onPressed: widget.onComplete,
              child: const Text('Skip for Now'),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required String key,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isGranted ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isGranted)
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              IconButton(
                onPressed: onRequest,
                icon: const Icon(Icons.arrow_forward),
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRequestAll() async {
    setState(() => _isRequesting = true);
    
    final results = await PermissionsService.requestAllPermissions(context);
    
    setState(() {
      _permissions.addAll(results);
      _isRequesting = false;
    });
    
    // If all granted or user wants to continue
    if (_permissions.values.every((granted) => granted)) {
      widget.onComplete();
    }
  }
}
