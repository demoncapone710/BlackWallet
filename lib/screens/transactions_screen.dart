import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';

class TransactionsScreen extends StatefulWidget {
  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  void fetchTransactions() async {
    setState(() {
      isLoading = true;
    });

    final data = await ApiService.getTransactions();
    setState(() {
      transactions = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transaction History"),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: () async {
              final service = ReceiptService();
              final file = await service.exportTransactionsCsv(transactions);
              await service.shareFile(file, subject: 'Transactions CSV');
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchTransactions,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "No transactions yet",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isSent = transaction['type'] == 'sent';
                    final amount = transaction['amount'] as num;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSent ? Colors.red[100] : Colors.green[100],
                          child: Icon(
                            isSent ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isSent ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(
                          isSent
                              ? "Sent to ${transaction['receiver']}"
                              : "Received from ${transaction['sender']}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Transaction #${transaction['id']}"),
                        trailing: Text(
                          "${isSent ? '-' : '+'}\$${amount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSent ? Colors.red : Colors.green,
                          ),
                        ),
                        onTap: () async {
                          // Show transaction details and allow PDF receipt generation
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Color(0xFF0A0A0A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (ctx) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Transaction #${transaction['id']}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    SizedBox(height: 8),
                                    Text('From: ${transaction['sender'] ?? '-'}', style: TextStyle(color: Colors.grey[300])),
                                    Text('To: ${transaction['receiver'] ?? '-'}', style: TextStyle(color: Colors.grey[300])),
                                    Text('Amount: \$${amount.toStringAsFixed(2)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    if (transaction['note'] != null && (transaction['note'] as String).isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      Text('Note: ${transaction['note']}', style: TextStyle(color: Colors.grey[300])),
                                    ],
                                    SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              final service = ReceiptService();
                                              final file = await service.generateTransactionPdf(transaction);
                                              await service.shareFile(file, subject: 'Transaction Receipt');
                                            },
                                            child: Text('Save & Share Receipt'),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              final service = ReceiptService();
                                              final file = await service.generateTransactionPdf(transaction);
                                              // Optionally open the file or save; for now share
                                              await service.shareFile(file, subject: 'Transaction Receipt');
                                            },
                                            child: Text('Download PDF'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
