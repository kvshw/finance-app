import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../components/transaction_form.dart';
import '../components/transaction_filter.dart';
import 'categories_screen.dart';
import 'category_stats_screen.dart';
import 'recurring_transactions_screen.dart';
import 'edit_transaction_screen.dart';
import '../models/transaction.dart' as models;
import 'analytics_screen.dart';

enum TransactionType { expense, income }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _transactions = [];
  List<dynamic> _filteredTransactions = [];
  bool _isLoading = false;
  double _totalBalance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  String? _userEmail;
  String _searchQuery = '';
  final currencyFormatter =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');

  // Dummy data for initial UI (we'll replace with real data later)
  final List<Map<String, dynamic>> _recentTransactions = [
    {
      'title': 'Grocery Shopping',
      'amount': -125.50,
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'category': 'Food'
    },
    {
      'title': 'Salary Deposit',
      'amount': 3250.00,
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'category': 'Income'
    },
    {
      'title': 'Netflix Subscription',
      'amount': -15.99,
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'category': 'Entertainment'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/transactions'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _transactions = data;
            _filteredTransactions = data;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleFilteredTransactions(List<dynamic> filtered) {
    setState(() {
      _filteredTransactions = filtered;
    });
  }

  Future<void> _handleLogout() async {
    try {
      await _storage.delete(key: 'token');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error logging out: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToAddTransaction(
      BuildContext context, TransactionType type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => type == TransactionType.expense
            ? const AddExpenseScreen()
            : const AddIncomeScreen(),
      ),
    );

    if (result == true) {
      _loadTransactions();
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TransactionFilter(
                  transactions: _transactions,
                  onFiltered: (filtered) {
                    setState(() {
                      _filteredTransactions = filtered;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'Dashboard',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildTotalsCard() {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var transaction in _filteredTransactions) {
      final amount = (transaction['amount'] as num).toDouble();
      if (amount > 0) {
        totalIncome += amount;
      } else {
        totalExpense += amount.abs();
      }
    }

    double balance = totalIncome - totalExpense;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Balance',
            style: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${balance.abs().toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              color: balance >= 0 ? Colors.green : Colors.red,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Income',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${totalIncome.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Expense',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${totalExpense.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              _buildActionButton(
                icon: Icons.remove_circle_outline,
                label: 'Add Expense',
                color: Colors.red[400]!,
                onTap: () =>
                    _navigateToAddTransaction(context, TransactionType.expense),
              ),
              _buildActionButton(
                icon: Icons.add_circle_outline,
                label: 'Add Income',
                color: Colors.green[400]!,
                onTap: () =>
                    _navigateToAddTransaction(context, TransactionType.income),
              ),
              _buildActionButton(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                color: Colors.amber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen()),
                ),
              ),
              _buildActionButton(
                icon: Icons.category_outlined,
                label: 'Categories',
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CategoriesScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Transactions',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _showFilterDialog,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Search transactions...',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (_filteredTransactions.isEmpty)
          Center(
            child: Text(
              'No transactions found',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredTransactions.length,
            itemBuilder: (context, index) {
              final transaction = _filteredTransactions[index];
              return _buildTransactionItem({
                'id': transaction['id'],
                'title': transaction['title'],
                'amount': transaction['amount'],
                'type': transaction['amount'] < 0 ? 'expense' : 'income',
                'category': transaction['category'],
                'date': transaction['date'],
                'is_recurring': false,
                'recurrence_frequency': null,
                'next_recurrence_date': null,
              });
            },
          ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = transaction['amount'] as double;
    final isExpense = amount < 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[850],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpense ? Colors.red : Colors.green,
          child: Icon(
            isExpense ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white,
          ),
        ),
        title: Text(
          transaction['title'] as String,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction['category'] as String,
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy')
                  .format(DateTime.parse(transaction['date'] as String)),
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            if (transaction['is_recurring'] == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.repeat, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Recurring: ${transaction['recurrence_frequency']}',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currencyFormatter.format(amount.abs()),
              style: GoogleFonts.poppins(
                color: isExpense ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              onSelected: (value) async {
                if (value == 'edit') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditTransactionScreen(
                        transaction: Map<String, dynamic>.from(transaction),
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
                      backgroundColor: Colors.grey[900],
                      title: Text(
                        'Delete Transaction',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      content: Text(
                        'Are you sure you want to delete this transaction?',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(color: Colors.grey[400]),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    _deleteTransaction(transaction['id'] as int);
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Edit',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: GoogleFonts.poppins(color: Colors.red[400]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildHeader(),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotalsCard(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildFilterSection(),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildTransactionsList(),
                      ),
                      const SizedBox(height: 20), // Add bottom padding
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
