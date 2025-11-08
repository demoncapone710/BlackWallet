import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class InviteTrackingScreen extends StatefulWidget {
  const InviteTrackingScreen({Key? key}) : super(key: key);

  @override
  State<InviteTrackingScreen> createState() => _InviteTrackingScreenState();
}

class _InviteTrackingScreenState extends State<InviteTrackingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _sentInvites = [];
  List<dynamic> _receivedInvites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInvites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    
    try {
      final sent = await ApiService.getSentInvites();
      final received = await ApiService.getReceivedInvites();
      
      if (mounted) {
        setState(() {
          _sentInvites = sent;
          _receivedInvites = received;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invites: $e')),
        );
      }
    }
  }

  Future<void> _acceptInvite(dynamic invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Money Invite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${invite['sender_username']}'),
            Text('Amount: \$${invite['amount'].toStringAsFixed(2)}'),
            if (invite['message'] != null) ...[
              const SizedBox(height: 8),
              Text('Message: "${invite['message']}"'),
            ],
            const SizedBox(height: 16),
            const Text(
              'This will add the money to your account.',
              style: TextStyle(fontWeight: FontWeight.bold),
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
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.acceptInvite(invite['invite_token']);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Money Received!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Amount: \$${result['amount'].toStringAsFixed(2)}'),
              Text('New Balance: \$${result['new_balance'].toStringAsFixed(2)}'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadInvites(); // Refresh list
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _declineInvite(dynamic invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Money Invite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${invite['sender_username']}'),
            Text('Amount: \$${invite['amount'].toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'This will return the money to the sender.',
              style: TextStyle(fontWeight: FontWeight.bold),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.declineInvite(invite['id']);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite declined, sender refunded')),
      );
      
      _loadInvites(); // Refresh list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Invites'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Sent (${_sentInvites.length})',
              icon: const Icon(Icons.arrow_upward),
            ),
            Tab(
              text: 'Received (${_receivedInvites.length})',
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInvites,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSentInvitesTab(),
                  _buildReceivedInvitesTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildSentInvitesTab() {
    if (_sentInvites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.outbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No sent invites', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Send money to friends via email or phone', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sentInvites.length,
      itemBuilder: (context, index) {
        final invite = _sentInvites[index];
        return _buildSentInviteCard(invite);
      },
    );
  }

  Widget _buildReceivedInvitesTab() {
    if (_receivedInvites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No pending invites', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('You\'ll see money invites here when someone sends you money', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _receivedInvites.length,
      itemBuilder: (context, index) {
        final invite = _receivedInvites[index];
        return _buildReceivedInviteCard(invite);
      },
    );
  }

  Widget _buildSentInviteCard(dynamic invite) {
    final status = invite['status'] as String;
    final amount = (invite['amount'] as num).toDouble();
    final createdAt = DateTime.parse(invite['created_at']);
    final expiresAt = DateTime.parse(invite['expires_at']);
    final now = DateTime.now();
    final timeLeft = expiresAt.difference(now);
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending';
        break;
      case 'delivered':
        statusColor = Colors.blue;
        statusIcon = Icons.check;
        statusText = 'Delivered';
        break;
      case 'opened':
        statusColor = Colors.purple;
        statusIcon = Icons.visibility;
        statusText = 'Opened';
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Accepted';
        break;
      case 'declined':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Declined (Refunded)';
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusIcon = Icons.access_time;
        statusText = 'Expired (Refunded)';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To: ${invite['recipient_contact']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'via ${invite['recipient_method']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (invite['message'] != null) ...[
              Text(
                'Message: "${invite['message']}"',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sent: ${DateFormat('MMM d, h:mm a').format(createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (status == 'pending' || status == 'delivered' || status == 'opened')
                  Text(
                    timeLeft.isNegative 
                        ? 'Expired' 
                        : 'Expires in ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m',
                    style: TextStyle(
                      fontSize: 12,
                      color: timeLeft.inHours < 2 ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (invite['delivered_at'] != null && status != 'pending') ...[
              const SizedBox(height: 4),
              Text(
                'Delivered: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(invite['delivered_at']))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (invite['opened_at'] != null) ...[
              const SizedBox(height: 4),
              Text(
                '👀 Opened: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(invite['opened_at']))}',
                style: const TextStyle(fontSize: 12, color: Colors.purple),
              ),
            ],
            if (invite['responded_at'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Response: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(invite['responded_at']))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedInviteCard(dynamic invite) {
    final amount = (invite['amount'] as num).toDouble();
    final createdAt = DateTime.parse(invite['created_at']);
    final expiresAt = DateTime.parse(invite['expires_at']);
    final now = DateTime.now();
    final timeLeft = expiresAt.difference(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From: ${invite['sender_username']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text(
                      timeLeft.isNegative 
                          ? 'Expired' 
                          : '${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m left',
                      style: TextStyle(
                        fontSize: 12,
                        color: timeLeft.inHours < 2 ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (invite['message'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.message, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${invite['message']}"',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptInvite(invite),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _declineInvite(invite),
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
