import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class RecurringTransaction {
  final int id;
  final String title;
  final double amount;
  final String type;
  final String category;
  final DateTime date;
  final String recurrenceFrequency;
  final DateTime nextRecurrenceDate;

  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.recurrenceFrequency,
    required this.nextRecurrenceDate,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'],
      title: json['title'],
      amount: json['amount'].toDouble(),
      type: json['type'],
      category: json['category'],
      date: DateTime.parse(json['date']),
      recurrenceFrequency: json['recurrence_frequency'],
      nextRecurrenceDate: DateTime.parse(json['next_recurrence_date']),
    );
  }
}

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final _storage = const FlutterSecureStorage();
  List<RecurringTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecurringTransactions();
  }

  Future<void> _loadRecurringTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/transactions/recurring'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _transactions =
              data.map((json) => RecurringTransaction.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load recurring transactions');
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
        setState(() {
          _transactions.removeWhere((t) => t.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to delete transaction');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          'Recurring Transactions',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Text(
                    'No recurring transactions found',
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
                    return Card(
                      color: Colors.grey[850],
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(
                          transaction.title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category: ${transaction.category}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              'Amount: \$${transaction.amount.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                color: transaction.type == 'expense'
                                    ? Colors.red[400]
                                    : Colors.green[400],
                              ),
                            ),
                            Text(
                              'Frequency: ${transaction.recurrenceFrequency[0].toUpperCase()}${transaction.recurrenceFrequency.substring(1)}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              'Next: ${DateFormat('MMM d, y').format(transaction.nextRecurrenceDate)}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon:
                              const Icon(Icons.more_vert, color: Colors.white),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[850],
                                  title: Text(
                                    'Delete Transaction',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete this recurring transaction?',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        'Delete',
                                        style: GoogleFonts.poppins(
                                          color: Colors.red[400],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await _deleteTransaction(transaction.id);
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
