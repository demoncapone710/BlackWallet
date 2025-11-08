import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import 'user_management_screen.dart';
import 'notifications_screen.dart';
import 'advertisements_screen.dart';
import 'promotions_screen.dart';
import 'customer_support_screen.dart';
import 'analytics_screen.dart';
import 'system_config_screen.dart';
import 'transaction_monitor_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/admin/analytics/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _dashboardData = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load dashboard data');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout logic
              Navigator.of(context).pop();
            },
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
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsOverview(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildSystemInfo(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatsOverview() {
    final users = _dashboardData?['users'] ?? {};
    final transactions = _dashboardData?['transactions'] ?? {};
    final financial = _dashboardData?['financial'] ?? {};
    final notifications = _dashboardData?['notifications'] ?? {};
    final marketing = _dashboardData?['marketing'] ?? {};
    final support = _dashboardData?['support'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid: 2 columns for narrow screens, 3-4 for wider
            int crossAxisCount = 2;
            double childAspectRatio = 1.5;
            
            if (constraints.maxWidth > 600) {
              crossAxisCount = 3;
              childAspectRatio = 1.3;
            }
            if (constraints.maxWidth > 900) {
              crossAxisCount = 4;
              childAspectRatio = 1.2;
            }
            
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                _buildStatCard(
                  'Total Users',
                  '${users['total'] ?? 0}',
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Active (30d)',
                  '${users['active_30d'] ?? 0}',
                  Icons.people_outline,
                  Colors.green,
                ),
                _buildStatCard(
                  'Transactions',
                  '${transactions['count_30d'] ?? 0}',
                  Icons.receipt_long,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Volume',
                  '\$${(transactions['volume_30d'] ?? 0).toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.purple,
                ),
                _buildStatCard(
                  'System Balance',
                  '\$${(financial['total_balance_in_system'] ?? 0).toStringAsFixed(0)}',
                  Icons.account_balance_wallet,
                  Colors.teal,
                ),
                _buildStatCard(
                  'Notifications',
                  '${notifications['total_sent'] ?? 0}',
                  Icons.notifications,
                  Colors.indigo,
                ),
                _buildStatCard(
                  'Active Promos',
                  '${marketing['active_promotions'] ?? 0}',
                  Icons.local_offer,
                  Colors.pink,
                ),
                _buildStatCard(
                  'Unread Msgs',
                  '${support['unread_messages'] ?? 0}',
                  Icons.message,
                  Colors.red,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid for actions
            int crossAxisCount = 2;
            double childAspectRatio = 1.6;
            
            if (constraints.maxWidth > 600) {
              crossAxisCount = 3;
              childAspectRatio = 1.5;
            }
            
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                _buildActionCard(
                  'Manage Users',
                  Icons.people_alt,
                  Colors.blue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  ),
                ),
                _buildActionCard(
                  'Transactions',
                  Icons.receipt_long,
                  Colors.purple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionMonitorScreen(),
                    ),
                  ),
                ),
                _buildActionCard(
                  'System Config',
                  Icons.settings_applications,
                  Colors.red,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SystemConfigScreen(),
                    ),
                  ),
                ),
                _buildActionCard(
                  'Send Notifications',
                  Icons.notifications_active,
                  Colors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  ),
                ),
                _buildActionCard(
                  'Manage Ads',
                  Icons.ad_units,
                  Colors.orange,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdvertisementsScreen(),
                    ),
                  ),
                ),
                _buildActionCard(
                  'Manage Promos',
                  Icons.discount,
                  Colors.pink,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PromotionsScreen(),
                    ),
                  ),
                ),
                _buildActionCard(
                  'Customer Support',
                  Icons.support_agent,
                  Colors.teal,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerSupportScreen(),
                    ),
                  ),
                ),
                _buildActionCard(
                  'Analytics',
                  Icons.analytics,
                  Colors.indigo,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemInfo() {
    final stripeMode = _dashboardData?['stripe_mode'] ?? 'unknown';
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stripe Mode:'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stripeMode == 'live' ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stripeMode.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Last Updated:'),
                Text(
                  DateTime.now().toString().substring(0, 19),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
