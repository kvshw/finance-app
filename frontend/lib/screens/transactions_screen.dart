import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'edit_transaction_screen.dart';

class Transaction {
  final int id;
  final String title;
  final double amount;
  final String type;
  final String category;
  final DateTime date;
  final bool isRecurring;
  final String? recurrenceFrequency;
  final DateTime? nextRecurrenceDate;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.isRecurring,
    this.recurrenceFrequency,
    this.nextRecurrenceDate,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      amount: json['amount'].toDouble(),
      type: json['type'],
      category: json['category'],
      date: DateTime.parse(json['date']),
      isRecurring: json['is_recurring'] ?? false,
      recurrenceFrequency: json['recurrence_frequency'],
      nextRecurrenceDate: json['next_recurrence_date'] != null
          ? DateTime.parse(json['next_recurrence_date'])
          : null,
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _storage = const FlutterSecureStorage();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _sortBy = 'date';
  String _sortOrder = 'desc';
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final queryParams = {
        if (_searchController.text.isNotEmpty) 'query': _searchController.text,
        if (_selectedCategory != 'All') 'category': _selectedCategory,
        if (_startDate != null) 'start_date': _startDate!.toIso8601String(),
        if (_endDate != null) 'end_date': _endDate!.toIso8601String(),
        if (_minAmount != null) 'min_amount': _minAmount.toString(),
        if (_maxAmount != null) 'max_amount': _maxAmount.toString(),
        'sort_by': _sortBy,
        'sort_order': _sortOrder,
      };

      final uri = Uri.parse('http://localhost:8000/api/transactions/search')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _transactions =
              data.map((json) => Transaction.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load transactions');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(
          'Filter Transactions',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Search',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue[400]!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  style: GoogleFonts.poppins(color: Colors.white),
                  dropdownColor: Colors.grey[800],
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue[400]!),
                    ),
                  ),
                  items: ['All', 'Food', 'Transport', 'Entertainment', 'Bills']
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                        child: Text(
                          _startDate != null
                              ? DateFormat('MMM d, y').format(_startDate!)
                              : 'Start Date',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                        child: Text(
                          _endDate != null
                              ? DateFormat('MMM d, y').format(_endDate!)
                              : 'End Date',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Min Amount',
                          labelStyle:
                              GoogleFonts.poppins(color: Colors.grey[400]),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[400]!),
                          ),
                        ),
                        onChanged: (value) {
                          _minAmount = double.tryParse(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Max Amount',
                          labelStyle:
                              GoogleFonts.poppins(color: Colors.grey[400]),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[400]!),
                          ),
                        ),
                        onChanged: (value) {
                          _maxAmount = double.tryParse(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadTransactions();
            },
            child: Text(
              'Apply',
              style: GoogleFonts.poppins(color: Colors.blue[400]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (value.startsWith('date')) {
                  _sortBy = 'date';
                  _sortOrder = value.endsWith('asc') ? 'asc' : 'desc';
                } else if (value.startsWith('amount')) {
                  _sortBy = 'amount';
                  _sortOrder = value.endsWith('asc') ? 'asc' : 'desc';
                } else if (value.startsWith('title')) {
                  _sortBy = 'title';
                  _sortOrder = value.endsWith('asc') ? 'asc' : 'desc';
                }
                _loadTransactions();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date_desc',
                child: Text(
                  'Date (Newest First)',
                  style: GoogleFonts.poppins(),
                ),
              ),
              PopupMenuItem(
                value: 'date_asc',
                child: Text(
                  'Date (Oldest First)',
                  style: GoogleFonts.poppins(),
                ),
              ),
              PopupMenuItem(
                value: 'amount_desc',
                child: Text(
                  'Amount (High to Low)',
                  style: GoogleFonts.poppins(),
                ),
              ),
              PopupMenuItem(
                value: 'amount_asc',
                child: Text(
                  'Amount (Low to High)',
                  style: GoogleFonts.poppins(),
                ),
              ),
              PopupMenuItem(
                value: 'title_asc',
                child: Text(
                  'Title (A to Z)',
                  style: GoogleFonts.poppins(),
                ),
              ),
              PopupMenuItem(
                value: 'title_desc',
                child: Text(
                  'Title (Z to A)',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Text(
                    'No transactions found',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return _buildTransactionItem(transaction);
                  },
                ),
    );
  }

  Widget _buildTransactionItem(dynamic transaction) {
    final amount =
        transaction is Map ? transaction['amount'] : transaction.amount;
    final date = transaction is Map ? transaction['date'] : transaction.date;
    final title = transaction is Map ? transaction['title'] : transaction.title;
    final category =
        transaction is Map ? transaction['category'] : transaction.category;
    final isRecurring = transaction is Map
        ? transaction['is_recurring']
        : transaction.isRecurring;
    final recurrenceFrequency = transaction is Map
        ? transaction['recurrence_frequency']
        : transaction.recurrenceFrequency;
    final id = transaction is Map ? transaction['id'] : transaction.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amount < 0 ? Colors.red : Colors.green,
          child: Icon(
            amount < 0 ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category),
            Text(
              DateFormat('MMM d, yyyy').format(DateTime.parse(date)),
              style: const TextStyle(fontSize: 12),
            ),
            if (isRecurring) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.repeat, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Recurring: ${recurrenceFrequency}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTransactionScreen(
                    transaction: transaction is Map
                        ? Map<String, dynamic>.from(transaction)
                        : {
                            'id': transaction.id,
                            'title': transaction.title,
                            'amount': transaction.amount,
                            'type': transaction.type,
                            'category': transaction.category,
                            'date': transaction.date,
                            'is_recurring': transaction.isRecurring,
                            'recurrence_frequency':
                                transaction.recurrenceFrequency,
                            'next_recurrence_date':
                                transaction.nextRecurrenceDate,
                          },
                  ),
                ),
              );
              if (result == true) {
                _loadTransactions();
              }
            } else if (value == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Transaction'),
                  content: const Text(
                      'Are you sure you want to delete this transaction?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                _deleteTransaction(id);
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(int id) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('http://localhost:8000/api/transactions/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadTransactions();
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Failed to delete transaction');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
