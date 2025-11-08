import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({Key? key}) : super(key: key);

  @override
  State<TransactionSearchScreen> createState() => _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  
  // Filters
  double? _minAmount;
  double? _maxAmount;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _transactionType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _isSearching = true);

    final results = await ApiService.searchTransactions(
      query: _searchController.text.isEmpty ? null : _searchController.text,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
      startDate: _startDate,
      endDate: _endDate,
      transactionType: _transactionType,
    );

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      _search();
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Amount Range
              const Text('Amount Range', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _minAmount = double.tryParse(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _maxAmount = double.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Transaction Type
              const Text('Transaction Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _transactionType == null,
                    onSelected: (selected) {
                      setModalState(() => _transactionType = null);
                      setState(() => _transactionType = null);
                    },
                  ),
                  FilterChip(
                    label: const Text('Sent'),
                    selected: _transactionType == 'internal',
                    onSelected: (selected) {
                      final type = selected ? 'internal' : null;
                      setModalState(() => _transactionType = type);
                      setState(() => _transactionType = type);
                    },
                  ),
                  FilterChip(
                    label: const Text('Deposit'),
                    selected: _transactionType == 'deposit',
                    onSelected: (selected) {
                      final type = selected ? 'deposit' : null;
                      setModalState(() => _transactionType = type);
                      setState(() => _transactionType = type);
                    },
                  ),
                  FilterChip(
                    label: const Text('Withdrawal'),
                    selected: _transactionType == 'withdrawal',
                    onSelected: (selected) {
                      final type = selected ? 'withdrawal' : null;
                      setModalState(() => _transactionType = type);
                      setState(() => _transactionType = type);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Date Range
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _startDate != null && _endDate != null
                      ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}'
                      : 'Select Date Range',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickDateRange();
                },
              ),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _minAmount = null;
                          _maxAmount = null;
                          _startDate = null;
                          _endDate = null;
                          _transactionType = null;
                        });
                        Navigator.pop(context);
                        _search();
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _search();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC143C),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Transactions'),
        backgroundColor: const Color(0xFFDC143C),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by recipient name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          
          // Active Filters
          if (_minAmount != null || _maxAmount != null || _startDate != null || _transactionType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_minAmount != null)
                    Chip(
                      label: Text('Min: \$${_minAmount!.toStringAsFixed(2)}'),
                      onDeleted: () {
                        setState(() => _minAmount = null);
                        _search();
                      },
                    ),
                  if (_maxAmount != null)
                    Chip(
                      label: Text('Max: \$${_maxAmount!.toStringAsFixed(2)}'),
                      onDeleted: () {
                        setState(() => _maxAmount = null);
                        _search();
                      },
                    ),
                  if (_startDate != null && _endDate != null)
                    Chip(
                      label: Text(
                        '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _search();
                      },
                    ),
                  if (_transactionType != null)
                    Chip(
                      label: Text(_transactionType!),
                      onDeleted: () {
                        setState(() => _transactionType = null);
                        _search();
                      },
                    ),
                ],
              ),
            ),
          
          const Divider(height: 1),
          
          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final txn = _results[index];
                          final date = DateTime.parse(txn['created_at']);
                          final amount = (txn['amount'] as num).toDouble();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFDC143C).withOpacity(0.1),
                                child: const Icon(
                                  Icons.swap_horiz,
                                  color: Color(0xFFDC143C),
                                ),
                              ),
                              title: Text(
                                '\$${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From: ${txn['sender']}'),
                                  Text('To: ${txn['receiver']}'),
                                  Text(
                                    DateFormat('MMM d, y h:mm a').format(date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: txn['status'] == 'completed'
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  txn['status'],
                                  style: TextStyle(
                                    color: txn['status'] == 'completed'
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
