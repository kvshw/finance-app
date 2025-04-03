import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../config/api_config.dart';

class CategoryStats {
  final String name;
  final String type;
  final double totalAmount;
  final int transactionCount;
  final double? budget;
  final List<Transaction> recentTransactions;

  CategoryStats({
    required this.name,
    required this.type,
    required this.totalAmount,
    required this.transactionCount,
    this.budget,
    required this.recentTransactions,
  });

  factory CategoryStats.fromJson(Map<String, dynamic> json) {
    return CategoryStats(
      name: json['name'],
      type: json['type'],
      totalAmount: json['total_amount'].toDouble(),
      transactionCount: json['transaction_count'],
      budget: json['budget']?.toDouble(),
      recentTransactions: (json['recent_transactions'] as List)
          .map((t) => Transaction.fromJson(t))
          .toList(),
    );
  }
}

class Transaction {
  final int id;
  final double amount;
  final String description;
  final DateTime date;

  Transaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amount: json['amount'].toDouble(),
      description: json['description'],
      date: DateTime.parse(json['date']),
    );
  }
}

class CategoryStatsScreen extends StatefulWidget {
  const CategoryStatsScreen({super.key});

  @override
  State<CategoryStatsScreen> createState() => _CategoryStatsScreenState();
}

class _CategoryStatsScreenState extends State<CategoryStatsScreen> {
  final _storage = const FlutterSecureStorage();
  List<CategoryStats> _stats = [];
  bool _isLoading = true;
  String _selectedType = 'expense';
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.categoriesUrl}/stats'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats = (data as List)
              .map((item) => CategoryStats.fromJson(item))
              .toList();
        });
      } else {
        throw Exception('Failed to load stats');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setBudget(CategoryStats category) async {
    final budget = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Set Budget for ${category.name}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Monthly Budget',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final budget = double.tryParse(_budgetController.text);
              if (budget != null && budget > 0) {
                Navigator.pop(context, budget);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid budget amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Set',
              style: GoogleFonts.poppins(
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );

    if (budget != null) {
      try {
        final token = await _storage.read(key: 'token');
        if (token == null) {
          throw Exception('Not authenticated');
        }

        final response = await http.post(
          Uri.parse('${ApiConfig.categoriesUrl}/${category.name}/budget'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'budget': budget}),
        );

        if (response.statusCode == 200) {
          _loadStats();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Budget set successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to set budget');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStats = _stats.where((s) => s.type == _selectedType).toList();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Category Statistics',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          DropdownButton<String>(
            value: _selectedType,
            dropdownColor: Colors.grey[850],
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(
                value: 'expense',
                child: Text('Expenses'),
              ),
              DropdownMenuItem(
                value: 'income',
                child: Text('Income'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedType = value);
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredStats.length,
              itemBuilder: (context, index) {
                final stat = filteredStats[index];
                final isExpense = stat.type == 'expense';
                final progress = stat.budget != null
                    ? (stat.totalAmount / stat.budget!).clamp(0.0, 1.0)
                    : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isExpense ? Colors.red : Colors.green)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isExpense
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline,
                              color: isExpense ? Colors.red : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat.name,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${stat.transactionCount} transactions',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_money,
                                color: Colors.amber),
                            onPressed: () => _setBudget(stat),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '\$${stat.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (stat.budget != null) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress! > 0.8
                                ? Colors.red
                                : progress > 0.5
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Budget: \$${stat.budget!.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (stat.recentTransactions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Recent Transactions',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...stat.recentTransactions
                            .map((transaction) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              transaction.description,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey[400],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${transaction.amount.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          color: isExpense
                                              ? Colors.red
                                              : Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
