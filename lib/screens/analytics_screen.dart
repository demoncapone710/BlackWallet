import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  double _totalSpent = 0;
  double _totalReceived = 0;
  String? _username;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    final transactions = await ApiService.getTransactions();
    final username = await ApiService.getCurrentUsername();
    
    double spent = 0;
    double received = 0;
    
    for (var tx in transactions) {
      final amount = (tx['amount'] as num).toDouble();
      if (tx['sender'] == username) {
        spent += amount;
      } else if (tx['receiver'] == username) {
        received += amount;
      }
    }
    
    setState(() {
      _transactions = transactions;
      _username = username;
      _totalSpent = spent;
      _totalReceived = received;
      _loading = false;
    });
  }

  List<PieChartSectionData> _getPieChartSections() {
    return [
      PieChartSectionData(
        color: Colors.red,
        value: _totalSpent,
        title: '\$${_totalSpent.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.green,
        value: _totalReceived,
        title: '\$${_totalReceived.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        backgroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spending Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Sent',
                          _totalSpent,
                          Colors.red,
                          Icons.arrow_upward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Received',
                          _totalReceived,
                          Colors.green,
                          Icons.arrow_downward,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Net Flow',
                          _totalReceived - _totalSpent,
                          _totalReceived >= _totalSpent ? Colors.green : Colors.red,
                          Icons.account_balance_wallet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Transactions',
                          _transactions.length.toDouble(),
                          Colors.blue,
                          Icons.receipt_long,
                          isCount: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Pie Chart
                  if (_totalSpent > 0 || _totalReceived > 0) ...[
                    const Text(
                      'Spending vs Income',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sections: _getPieChartSections(),
                                centerSpaceRadius: 40,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem('Sent', Colors.red),
                              const SizedBox(height: 8),
                              _buildLegendItem('Received', Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  
                  // Recent Activity
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_transactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No transactions yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ...(_transactions.take(10).map((tx) {
                      final isSent = tx['sender'] == _username;
                      final amount = (tx['amount'] as num).toDouble();
                      final otherParty = isSent ? tx['receiver'] : tx['sender'];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSent ? Colors.red[50] : Colors.green[50],
                            child: Icon(
                              isSent ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isSent ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(
                            isSent ? 'Sent to @$otherParty' : 'Received from @$otherParty',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(tx['transaction_type'] ?? 'transfer'),
                          trailing: Text(
                            '${isSent ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSent ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      );
                    })),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color, IconData icon, {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isCount ? value.toInt().toString() : '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
