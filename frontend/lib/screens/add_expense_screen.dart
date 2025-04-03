import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'categories_screen.dart';
import 'package:intl/intl.dart';

class Category {
  final int id;
  final String name;
  final String type;
  final List<Map<String, dynamic>> subcategories;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      subcategories:
          List<Map<String, dynamic>>.from(json['subcategories'] ?? []),
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isRecurring = false;
  String _recurrenceFrequency = 'monthly';
  DateTime _nextRecurrenceDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.get(
        Uri.parse(ApiConfig.categoriesUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriesData = json.decode(response.body);
        setState(() {
          _categories = categoriesData
              .map((data) => Category.fromJson(data))
              .where((category) => category.type == 'expense')
              .toList();
        });
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading categories: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Colors.grey,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildRecurringOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value ?? false;
                });
              },
            ),
            Text(
              'Make this a recurring transaction',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _recurrenceFrequency,
            style: GoogleFonts.poppins(color: Colors.white),
            dropdownColor: Colors.grey[800],
            decoration: InputDecoration(
              labelText: 'Frequency',
              labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue[400]!),
              ),
            ),
            items: ['daily', 'weekly', 'monthly', 'yearly', 'custom']
                .map((frequency) => DropdownMenuItem(
                      value: frequency,
                      child: Text(
                        frequency[0].toUpperCase() + frequency.substring(1),
                        style: GoogleFonts.poppins(),
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _recurrenceFrequency = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _nextRecurrenceDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _nextRecurrenceDate = date;
                });
              }
            },
            child: Text(
              'Next Occurrence: ${DateFormat('MMM d, y').format(_nextRecurrenceDate)}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF6C63FF),
                      onPrimary: Colors.white,
                      surface: Color(0xFF1E1E1E),
                      onSurface: Colors.white,
                    ),
                    dialogBackgroundColor: const Color(0xFF1E1E1E),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3D3D3D)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addExpense() async {
    if (_titleController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Parse amount and ensure it's a valid number
      final amount = double.tryParse(_amountController.text);
      if (amount == null) {
        throw Exception('Please enter a valid amount');
      }

      // Prepare the request body
      final requestBody = {
        'title': _titleController.text,
        'amount': amount * -1, // Make amount negative for expenses
        'type': 'expense',
        'category': _categoryController.text,
        'date': _selectedDate
            .toIso8601String(), // Use selected date instead of current date
        'is_recurring': _isRecurring,
        'recurrence_frequency': _isRecurring ? _recurrenceFrequency : null,
        'next_recurrence_date':
            _isRecurring ? _nextRecurrenceDate.toIso8601String() : null,
      };

      print('Sending request body: $requestBody'); // Debug log

      final response = await http.post(
        Uri.parse('http://localhost:8000/api/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      print('Response status code: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Failed to add expense');
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Create New Category',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Category Name',
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
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a category name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final token = await _storage.read(key: 'token');
                if (token == null) {
                  throw Exception('Not authenticated');
                }

                final response = await http.post(
                  Uri.parse(ApiConfig.categoriesUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'name': nameController.text,
                    'type': 'expense',
                  }),
                );

                if (response.statusCode == 200 || response.statusCode == 201) {
                  // Reload categories
                  await _loadCategories();

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {
                      _categoryController.text = nameController.text;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Category created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  final error = jsonDecode(response.body);
                  throw Exception(
                      error['detail'] ?? 'Failed to create category');
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
            },
            child: Text(
              'Create',
              style: GoogleFonts.poppins(
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Add Expense',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue[400]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue[400]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 20),
                  _buildDatePicker(),
                  const SizedBox(height: 20),
                  _buildRecurringOptions(),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _addExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Add Expense',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _categoryController.text.isEmpty ? null : _categoryController.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: Colors.grey[850],
      items: [
        ..._categories.expand((category) => [
              DropdownMenuItem(
                value: category.name,
                child: Text(category.name),
              ),
              ...category.subcategories.map((subcategory) => DropdownMenuItem(
                    value: '${category.name} > ${subcategory['name']}',
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(subcategory['name'] ?? ''),
                    ),
                  )),
            ]),
        const DropdownMenuItem(
          value: 'new',
          child: Text('+ Create New Category'),
        ),
      ],
      onChanged: (value) {
        if (value == 'new') {
          _showCreateCategoryDialog();
        } else if (value != null) {
          setState(() {
            _categoryController.text = value;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category';
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
}
