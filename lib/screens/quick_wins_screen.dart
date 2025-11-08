import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class QuickWinsScreen extends StatefulWidget {
  const QuickWinsScreen({Key? key}) : super(key: key);

  @override
  State<QuickWinsScreen> createState() => _QuickWinsScreenState();
}

class _QuickWinsScreenState extends State<QuickWinsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Favorites
  List<Map<String, dynamic>> _favorites = [];
  bool _loadingFavorites = false;
  
  // Scheduled Payments
  List<Map<String, dynamic>> _scheduledPayments = [];
  bool _loadingScheduled = false;
  
  // Payment Links
  List<Map<String, dynamic>> _paymentLinks = [];
  bool _loadingLinks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadFavorites();
    _loadScheduledPayments();
    _loadPaymentLinks();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loadingFavorites = true);
    final favorites = await ApiService.getFavorites();
    setState(() {
      _favorites = favorites;
      _loadingFavorites = false;
    });
  }

  Future<void> _loadScheduledPayments() async {
    setState(() => _loadingScheduled = true);
    final payments = await ApiService.getScheduledPayments();
    setState(() {
      _scheduledPayments = payments;
      _loadingScheduled = false;
    });
  }

  Future<void> _loadPaymentLinks() async {
    setState(() => _loadingLinks = true);
    final links = await ApiService.getMyPaymentLinks();
    setState(() {
      _paymentLinks = links;
      _loadingLinks = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Features'),
        backgroundColor: const Color(0xFFDC143C),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.star), text: 'Favorites'),
            Tab(icon: Icon(Icons.schedule), text: 'Scheduled'),
            Tab(icon: Icon(Icons.link), text: 'Links'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFavoritesTab(),
          _buildScheduledTab(),
          _buildLinksTab(),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    if (_loadingFavorites) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Star a recipient when sending money',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final fav = _favorites[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFDC143C).withOpacity(0.1),
                child: const Icon(Icons.person, color: Color(0xFFDC143C)),
              ),
              title: Text(
                fav['nickname'] ?? fav['recipient'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fav['recipient']),
                  Text(
                    'Used ${fav['use_count']} times',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeFavorite(fav['id']),
              ),
              onTap: () => _sendToFavorite(fav),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduledTab() {
    if (_loadingScheduled) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_scheduledPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No scheduled payments',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showSchedulePaymentDialog,
              icon: const Icon(Icons.add),
              label: const Text('Schedule Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC143C),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadScheduledPayments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _scheduledPayments.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: _showSchedulePaymentDialog,
                icon: const Icon(Icons.add),
                label: const Text('Schedule New Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC143C),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            );
          }

          final payment = _scheduledPayments[index - 1];
          final nextExecution = DateTime.parse(payment['next_execution']);
          final isRecurring = payment['is_recurring'] ?? false;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFDC143C).withOpacity(0.1),
                child: Icon(
                  isRecurring ? Icons.repeat : Icons.schedule_send,
                  color: const Color(0xFFDC143C),
                ),
              ),
              title: Text(
                '\$${payment['amount']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To: ${payment['recipient']}'),
                  Text(
                    'Next: ${DateFormat('MMM d, y h:mm a').format(nextExecution)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (isRecurring)
                    Text(
                      payment['schedule_type'].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC143C),
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                onPressed: () => _cancelScheduledPayment(payment['id']),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinksTab() {
    if (_loadingLinks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentLinks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No payment links',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateLinkDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Payment Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC143C),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentLinks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _paymentLinks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: _showCreateLinkDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create New Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC143C),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            );
          }

          final link = _paymentLinks[index - 1];
          final isActive = link['is_active'] ?? false;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                child: Icon(
                  Icons.link,
                  color: isActive ? const Color(0xFF4CAF50) : Colors.grey,
                ),
              ),
              title: Text(
                link['amount'] != null
                    ? '\$${link['amount']}'
                    : 'Variable Amount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (link['description'] != null)
                    Text(link['description']),
                  Text(
                    'Code: ${link['code']}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  Text(
                    'Uses: ${link['uses']} • Collected: \$${link['total_collected']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: isActive ? Colors.green : Colors.grey,
              ),
              onTap: () => _showLinkDetails(link),
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeFavorite(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Favorite'),
        content: const Text('Remove this recipient from favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.removeFavorite(id);
      if (success) {
        _loadFavorites();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from favorites')),
          );
        }
      }
    }
  }

  void _sendToFavorite(Map<String, dynamic> fav) {
    // Navigate to send money screen with pre-filled recipient
    Navigator.pop(context, fav);
  }

  void _showSchedulePaymentDialog() {
    // Show dialog to schedule payment
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Payment'),
        content: const Text(
          'Navigate to Send Money screen and look for the "Schedule" option to create scheduled payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelScheduledPayment(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment'),
        content: const Text('Cancel this scheduled payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.cancelScheduledPayment(id);
      if (success) {
        _loadScheduledPayments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment cancelled')),
          );
        }
      }
    }
  }

  void _showCreateLinkDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Payment Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (optional)',
                hintText: 'Leave blank for variable amount',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final amount = amountController.text.isEmpty
                  ? null
                  : double.tryParse(amountController.text);
              final desc = descController.text.isEmpty ? null : descController.text;

              final result = await ApiService.createPaymentLink(
                amount: amount,
                description: desc,
              );

              if (result != null && mounted) {
                _loadPaymentLinks();
                _showLinkCreatedDialog(result);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showLinkCreatedDialog(Map<String, dynamic> result) {
    final link = result['link'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this code with anyone:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                link['code'],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showLinkDetails(Map<String, dynamic> link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Link Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Code', link['code']),
            _detailRow('Amount', link['amount'] != null ? '\$${link['amount']}' : 'Variable'),
            if (link['description'] != null)
              _detailRow('Description', link['description']),
            _detailRow('Uses', link['uses']),
            _detailRow('Collected', '\$${link['total_collected']}'),
            _detailRow('Status', link['is_active'] ? 'Active' : 'Inactive'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}
