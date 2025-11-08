import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'transactions_screen.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';
import 'payment_methods_screen.dart';
import 'receive_money_screen.dart';
import 'scan_qr_screen.dart';
import 'profile_screen.dart';
import 'analytics_screen.dart';
import 'send_money_screen.dart';
import 'request_money_screen.dart';
import 'dev_testing_screen.dart';
import 'hce_payment_screen.dart';
import 'send_via_contact_screen.dart';
import 'notification_settings_screen.dart';
import 'quick_wins_screen.dart';
import 'transaction_search_screen.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double balance = 0.0;
  String? username;
  bool isLoading = true;
  List<Map<String, dynamic>> recentTransactions = [];
  int totalTransactions = 0;
  double totalSpent = 0.0;
  double totalReceived = 0.0;

  void fetchBalance() async {
    setState(() {
      isLoading = true;
    });

    final b = await ApiService.getBalance();
    final u = await ApiService.getCurrentUsername();
    final transactions = await ApiService.getTransactions();

    // Calculate stats
    double spent = 0.0;
    double received = 0.0;
    
    for (var tx in transactions) {
      if (tx['sender'] == u) {
        spent += (tx['amount'] as num).toDouble();
      } else {
        received += (tx['amount'] as num).toDouble();
      }
    }

    setState(() {
      balance = b ?? 0.0;
      username = u;
      recentTransactions = transactions.take(5).toList();
      totalTransactions = transactions.length;
      totalSpent = spent;
      totalReceived = received;
      isLoading = false;
    });

    // Check for low balance and notify
    if (b != null && b < 50.0 && b > 0) {
      final notificationService = NotificationService();
      await notificationService.showLowBalanceNotification(b);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchBalance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A0A0A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC143C), Color(0xFFFF1744)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC143C).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                "BW",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "BlackWallet",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            offset: const Offset(0, 50),
            color: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: const Color(0xFFDC143C).withValues(alpha: 0.3)),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'deposit':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DepositScreen()),
                  );
                  if (result == true) fetchBalance();
                  break;
                case 'withdraw':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WithdrawScreen(currentBalance: balance)),
                  );
                  if (result == true) fetchBalance();
                  break;
                case 'send':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SendMoneyScreen()),
                  );
                  if (result == true) fetchBalance();
                  break;
                case 'send_contact':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SendViaContactScreen()),
                  );
                  if (result == true) fetchBalance();
                  break;
                case 'request':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RequestMoneyScreen()),
                  );
                  if (result == true) fetchBalance();
                  break;
                case 'receive':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReceiveMoneyScreen()),
                  );
                  break;
                case 'scan':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                  );
                  if (result == true) fetchBalance();
                  break;
                case 'hce_payment':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HcePaymentScreen()),
                  );
                  break;
                case 'dev_test':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DevTestingScreen()),
                  );
                  break;
                case 'payment_methods':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PaymentMethodsScreen()),
                  );
                  break;
                case 'analytics':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                  break;
                case 'notifications':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                  );
                  break;
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  break;
                case 'transactions':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TransactionsScreen()),
                  );
                  break;
                case 'search_transactions':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionSearchScreen()),
                  );
                  break;
                case 'quick_wins':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuickWinsScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              _buildMenuItem(Icons.add_circle, 'Deposit Money', 'deposit', const Color(0xFF00E676)),
              _buildMenuItem(Icons.remove_circle, 'Withdraw Money', 'withdraw', const Color(0xFFFF9100)),
              const PopupMenuDivider(),
              _buildMenuItem(Icons.send, 'Send Money', 'send', const Color(0xFFDC143C)),
              _buildMenuItem(Icons.phone_android, 'Send via Phone/Email', 'send_contact', const Color(0xFFFF4081)),
              _buildMenuItem(Icons.request_page, 'Request Money', 'request', const Color(0xFFE91E63)),
              _buildMenuItem(Icons.qr_code, 'Receive Money', 'receive', const Color(0xFF7C4DFF)),
              _buildMenuItem(Icons.qr_code_scanner, 'Scan QR', 'scan', const Color(0xFF448AFF)),
              const PopupMenuDivider(),
              _buildMenuItem(Icons.contactless, 'Contactless Payment (HCE)', 'hce_payment', const Color(0xFF00E676)),
              const PopupMenuDivider(),
              if (kDebugMode)
                _buildMenuItem(Icons.bug_report, 'Dev Testing', 'dev_test', const Color(0xFFFF9800)),
              if (kDebugMode)
                const PopupMenuDivider(),
              _buildMenuItem(Icons.payment, 'Payment Methods', 'payment_methods', const Color(0xFF00BCD4)),
              _buildMenuItem(Icons.history, 'Transaction History', 'transactions', const Color(0xFF888888)),
              _buildMenuItem(Icons.search, 'Search Transactions', 'search_transactions', const Color(0xFF29B6F6)),
              _buildMenuItem(Icons.star, 'Quick Features', 'quick_wins', const Color(0xFFFFC107)),
              _buildMenuItem(Icons.analytics, 'Analytics', 'analytics', const Color(0xFFFF6E40)),
              _buildMenuItem(Icons.notifications, 'Notifications', 'notifications', const Color(0xFF9C27B0)),
              _buildMenuItem(Icons.person, 'Profile & Settings', 'profile', Colors.white),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchBalance,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFDC143C),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFDC143C),
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: () async {
                fetchBalance();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section with Balance Card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC143C), Color(0xFFFF1744)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC143C).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (username != null)
                            Text(
                              "Welcome back, $username",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                          const SizedBox(height: 16),
                          const Text(
                            "Total Balance",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "\$${balance.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickAction(
                            context,
                            Icons.add_circle,
                            'Deposit',
                            const Color(0xFF00E676),
                            () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DepositScreen()),
                              );
                              if (result == true) fetchBalance();
                            },
                          ),
                          _buildQuickAction(
                            context,
                            Icons.send,
                            'Send',
                            const Color(0xFFDC143C),
                            () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SendMoneyScreen()),
                              );
                              if (result == true) fetchBalance();
                            },
                          ),
                          _buildQuickAction(
                            context,
                            Icons.qr_code_scanner,
                            'Scan',
                            const Color(0xFF7C4DFF),
                            () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                              );
                              if (result == true) fetchBalance();
                            },
                          ),
                          _buildQuickAction(
                            context,
                            Icons.analytics,
                            'Analytics',
                            const Color(0xFFFF6E40),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Account Overview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Account Overview",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total Spent',
                                  '\$${totalSpent.toStringAsFixed(2)}',
                                  Icons.arrow_upward,
                                  const Color(0xFFFF1744),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Total Received',
                                  '\$${totalReceived.toStringAsFixed(2)}',
                                  Icons.arrow_downward,
                                  const Color(0xFF00E676),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            'Total Transactions',
                            totalTransactions.toString(),
                            Icons.receipt_long,
                            const Color(0xFF448AFF),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Recent Transactions
                    if (recentTransactions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Recent Transactions",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TransactionsScreen()),
                                );
                              },
                              child: const Text(
                                'See All',
                                style: TextStyle(color: Color(0xFFDC143C)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...recentTransactions.map((tx) => _buildTransactionItem(tx)).toList(),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(IconData icon, String title, String value, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final isSent = tx['sender'] == username;
    final amount = (tx['amount'] as num).toDouble();
    final otherParty = isSent ? tx['receiver'] : tx['sender'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isSent ? const Color(0xFFFF1744) : const Color(0xFF00E676)).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSent ? const Color(0xFFFF1744) : const Color(0xFF00E676)).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSent 
                    ? [const Color(0xFFFF1744), const Color(0xFFDC143C)]
                    : [const Color(0xFF00E676), const Color(0xFF00C853)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isSent ? const Color(0xFFFF1744) : const Color(0xFF00E676)).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isSent ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSent ? 'Sent to $otherParty' : 'Received from $otherParty',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx['timestamp'] ?? 'Just now',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isSent ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSent ? const Color(0xFFFF1744) : const Color(0xFF00E676),
            ),
          ),
        ],
      ),
    );
  }
}
