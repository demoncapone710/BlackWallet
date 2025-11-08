import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class RequestMoneyScreen extends StatefulWidget {
  @override
  _RequestMoneyScreenState createState() => _RequestMoneyScreenState();
}

class _RequestMoneyScreenState extends State<RequestMoneyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final usernameController = TextEditingController();
  final reasonController = TextEditingController();
  
  bool isLoading = false;
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> receivedRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    amountController.dispose();
    usernameController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      isLoading = true;
    });

    try {
      // In a real app, fetch from backend API
      // For now, using mock data
      await Future.delayed(Duration(milliseconds: 500));
      
      setState(() {
        // Mock pending requests (requests you sent)
        pendingRequests = [
          {
            'id': '1',
            'to_user': 'john_doe',
            'amount': 50.00,
            'reason': 'Lunch split',
            'status': 'pending',
            'created_at': DateTime.now().subtract(Duration(hours: 2)).toString(),
          },
          {
            'id': '2',
            'to_user': 'jane_smith',
            'amount': 120.00,
            'reason': 'Rent contribution',
            'status': 'pending',
            'created_at': DateTime.now().subtract(Duration(days: 1)).toString(),
          },
        ];

        // Mock received requests (requests from others)
        receivedRequests = [
          {
            'id': '3',
            'from_user': 'mike_wilson',
            'amount': 35.50,
            'reason': 'Movie tickets',
            'status': 'pending',
            'created_at': DateTime.now().subtract(Duration(hours: 5)).toString(),
          },
        ];

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading requests: $e');
    }
  }

  Future<void> _requestMoney() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // In a real app, call backend API to create request
      await Future.delayed(Duration(seconds: 1));
      
      // Show notification to the recipient (in real app, would be server-side)
      final notificationService = NotificationService();
      final recipient = usernameController.text;
      final reason = reasonController.text.trim();
      
      // This would normally be sent from backend to recipient's device
      // For demo, we're showing it locally
      await notificationService.showPaymentRequestNotification(amount, 'You', reason);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to $recipient'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      amountController.clear();
      usernameController.clear();
      reasonController.clear();

      // Reload requests
      await _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _respondToRequest(String requestId, bool accept) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Find the request details
      final request = receivedRequests.firstWhere((r) => r['id'] == requestId);
      final amount = request['amount'] as double;
      final sender = request['from_user'] as String;
      
      // In a real app, call backend API to accept/decline
      await Future.delayed(Duration(seconds: 1));
      
      // Show notification based on action
      final notificationService = NotificationService();
      if (accept) {
        // Notify sender that request was accepted
        await notificationService.showPaymentRequestAcceptedNotification(amount, sender);
      } else {
        // Notify sender that request was declined
        await notificationService.showPaymentRequestDeclinedNotification(amount, sender);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Request accepted' : 'Request declined'),
          backgroundColor: accept ? Colors.green : Colors.orange,
        ),
      );

      // Reload requests
      await _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    setState(() {
      isLoading = true;
    });

    try {
      // In a real app, call backend API to cancel
      await Future.delayed(Duration(seconds: 1));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request cancelled'),
          backgroundColor: Colors.orange,
        ),
      );

      // Reload requests
      await _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Request Money'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFDC143C),
          labelColor: const Color(0xFFDC143C),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'New Request'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRequestTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildNewRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDC143C).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFFDC143C),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send a payment request to another user',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Username Field
            Text(
              'Request From',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter username',
                prefixIcon: Icon(Icons.person, color: Color(0xFFDC143C)),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFDC143C), width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Amount Field
            Text(
              'Amount',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money, color: Color(0xFFDC143C)),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFDC143C), width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Quick Amount Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [10, 25, 50, 100].map((amount) {
                return InkWell(
                  onTap: () {
                    amountController.text = amount.toString();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade800,
                      ),
                    ),
                    child: Text(
                      '\$$amount',
                      style: TextStyle(
                        color: Color(0xFFDC143C),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Reason Field
            Text(
              'Reason (Optional)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What\'s this request for?',
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFDC143C), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Send Request Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _requestMoney,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Send Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (isLoading && pendingRequests.isEmpty && receivedRequests.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFFDC143C),
        ),
      );
    }

    return RefreshIndicator(
      color: Color(0xFFDC143C),
      onRefresh: _loadRequests,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Received Requests Section
            if (receivedRequests.isNotEmpty) ...[
              Text(
                'Requests from Others',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              ...receivedRequests.map((request) => _buildReceivedRequestCard(request)).toList(),
              SizedBox(height: 24),
            ],

            // Pending Requests Section
            Text(
              'Your Pending Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            
            if (pendingRequests.isEmpty)
              Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.request_page_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No pending requests',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...pendingRequests.map((request) => _buildPendingRequestCard(request)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF00E676).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF00E676).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_downward,
                  color: Color(0xFF00E676),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['from_user'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'wants to receive',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${request['amount'].toStringAsFixed(2)}',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (request['reason'] != null && request['reason'].isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request['reason'],
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
            ),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _respondToRequest(request['id'], false),
                  icon: Icon(Icons.close, size: 18),
                  label: Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _respondToRequest(request['id'], true),
                  icon: Icon(Icons.check, size: 18),
                  label: Text('Pay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFDC143C).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_upward,
                  color: Color(0xFFDC143C),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['to_user'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${request['amount'].toStringAsFixed(2)}',
                style: TextStyle(
                  color: Color(0xFFDC143C),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (request['reason'] != null && request['reason'].isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request['reason'],
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
            ),
          ],
          SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _cancelRequest(request['id']),
            icon: Icon(Icons.cancel, size: 18),
            label: Text('Cancel Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
