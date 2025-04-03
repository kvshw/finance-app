import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'package:flutter/services.dart';

class EditTransactionScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const EditTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  String? _selectedCategory;
  late DateTime _selectedDate;
  bool _isRecurring = false;
  String _recurrenceFrequency = 'monthly';
  DateTime? _nextRecurrenceDate;
  bool _isLoading = false;
  List<String> _categories = [];
  bool _isExpense = false;

  final List<String> _frequencies = ['daily', 'weekly', 'monthly', 'yearly'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction['title']);
    _amountController = TextEditingController(
        text: widget.transaction['amount'].abs().toStringAsFixed(2));
    _selectedDate = DateTime.parse(widget.transaction['date']);
    _isExpense = widget.transaction['amount'] < 0;
    _isRecurring = widget.transaction['is_recurring'] ?? false;
    _recurrenceFrequency =
        widget.transaction['recurrence_frequency'] ?? 'monthly';
    _nextRecurrenceDate = widget.transaction['next_recurrence_date'] != null
        ? DateTime.parse(widget.transaction['next_recurrence_date'])
        : null;
    _selectedCategory = widget.transaction['category'];
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/categories'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _categories =
                data.map((category) => category['name'] as String).toList();
            if (_selectedCategory != null &&
                !_categories.contains(_selectedCategory)) {
              _categories.add(_selectedCategory!);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) throw Exception('No token found');

      final amount = double.parse(_amountController.text.replaceAll(',', ''));

      // Print the request body for debugging
      final requestBody = {
        'title': _titleController.text,
        'amount': _isExpense ? -amount : amount,
        'type': _isExpense ? 'expense' : 'income',
        'category': _selectedCategory,
        'date': _selectedDate.toIso8601String(),
        'is_recurring': _isRecurring,
        'recurrence_frequency': _isRecurring ? _recurrenceFrequency : null,
        'next_recurrence_date': _isRecurring && _nextRecurrenceDate != null
            ? _nextRecurrenceDate!.toIso8601String()
            : null,
      };
      print('Request body: $requestBody');

      final response = await http.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/transactions/${widget.transaction['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to update transaction: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectNextRecurrenceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextRecurrenceDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _nextRecurrenceDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpenseScreen = widget.transaction['amount'] < 0;
    final primaryColor = isExpenseScreen ? Colors.red : Colors.green;
    final secondaryColor = isExpenseScreen
        ? Colors.red.withOpacity(0.1)
        : Colors.green.withOpacity(0.1);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isExpenseScreen ? 'Edit Expense' : 'Edit Income',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card with Amount
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isExpenseScreen
                                  ? 'Expense Amount'
                                  : 'Income Amount',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: GoogleFonts.poppins(
                                color: primaryColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle: GoogleFonts.poppins(
                                  color: primaryColor.withOpacity(0.5),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                                prefixIcon: Icon(
                                  Icons.attach_money,
                                  color: primaryColor,
                                  size: 24,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                filled: true,
                                fillColor: Colors.grey[900],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an amount';
                                }
                                final amount =
                                    double.tryParse(value.replaceAll(',', ''));
                                if (amount == null) {
                                  return 'Please enter a valid number';
                                }
                                if (amount <= 0) {
                                  return 'Amount must be greater than 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title Field
                      Text(
                        'Title',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _titleController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: isExpenseScreen
                                ? 'Enter expense title'
                                : 'Enter income title',
                            hintStyle:
                                GoogleFonts.poppins(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category Dropdown
                      Text(
                        'Category',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[800]!,
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            dropdownColor: Colors.grey[900],
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 16),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedCategory = value);
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a category';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date Picker
                      Text(
                        'Date',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[800]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM d, y').format(_selectedDate),
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Recurring Transaction Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[800]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recurring Transaction',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Switch(
                                  value: _isRecurring,
                                  onChanged: (value) {
                                    setState(() => _isRecurring = value);
                                  },
                                  activeColor: primaryColor,
                                ),
                              ],
                            ),
                            if (_isRecurring) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Frequency',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[850],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[800]!,
                                    width: 1,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _recurrenceFrequency,
                                    isExpanded: true,
                                    dropdownColor: Colors.grey[850],
                                    style: GoogleFonts.poppins(
                                        color: Colors.white),
                                    items: _frequencies.map((frequency) {
                                      return DropdownMenuItem(
                                        value: frequency,
                                        child: Text(
                                          frequency
                                                  .substring(0, 1)
                                                  .toUpperCase() +
                                              frequency.substring(1),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(
                                            () => _recurrenceFrequency = value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Next Recurrence Date',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _selectNextRecurrenceDate,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[850],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[800]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          color: Colors.grey[600]),
                                      const SizedBox(width: 12),
                                      Text(
                                        _nextRecurrenceDate != null
                                            ? DateFormat('MMM d, y')
                                                .format(_nextRecurrenceDate!)
                                            : 'Select Date',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Save Changes',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
