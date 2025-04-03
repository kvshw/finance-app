import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TransactionFilter extends StatefulWidget {
  final List<dynamic> transactions;
  final Function(List<dynamic>) onFiltered;

  const TransactionFilter({
    super.key,
    required this.transactions,
    required this.onFiltered,
  });

  @override
  State<TransactionFilter> createState() => _TransactionFilterState();
}

class _TransactionFilterState extends State<TransactionFilter> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedType = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  List<String> get _categories {
    final categories = widget.transactions
        .map((t) {
          if (t is Map<String, dynamic>) {
            return t['category'] as String;
          }
          return '';
        })
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  void _applyFilters() {
    var filtered = widget.transactions;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((t) {
        if (t is Map<String, dynamic>) {
          return (t['title'] as String).toLowerCase().contains(searchTerm) ||
              (t['category'] as String).toLowerCase().contains(searchTerm);
        }
        return false;
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((t) {
        if (t is Map<String, dynamic>) {
          return t['category'] == _selectedCategory;
        }
        return false;
      }).toList();
    }

    // Apply type filter
    if (_selectedType != 'All') {
      final isExpense = _selectedType == 'Expense';
      filtered = filtered.where((t) {
        if (t is Map<String, dynamic>) {
          final amount = (t['amount'] as num).toDouble();
          return (amount < 0) == isExpense;
        }
        return false;
      }).toList();
    }

    // Apply date range filter
    if (_startDate != null) {
      filtered = filtered.where((t) {
        if (t is Map<String, dynamic>) {
          final date = DateTime.parse(t['date'] as String);
          return date.isAfter(_startDate!.subtract(const Duration(days: 1)));
        }
        return false;
      }).toList();
    }
    if (_endDate != null) {
      filtered = filtered.where((t) {
        if (t is Map<String, dynamic>) {
          final date = DateTime.parse(t['date'] as String);
          return date.isBefore(_endDate!.add(const Duration(days: 1)));
        }
        return false;
      }).toList();
    }

    // Apply amount range filter
    if (_minAmountController.text.isNotEmpty) {
      final minAmount = double.tryParse(_minAmountController.text);
      if (minAmount != null) {
        filtered = filtered.where((t) {
          if (t is Map<String, dynamic>) {
            final amount = (t['amount'] as num).toDouble();
            return amount.abs() >= minAmount;
          }
          return false;
        }).toList();
      }
    }
    if (_maxAmountController.text.isNotEmpty) {
      final maxAmount = double.tryParse(_maxAmountController.text);
      if (maxAmount != null) {
        filtered = filtered.where((t) {
          if (t is Map<String, dynamic>) {
            final amount = (t['amount'] as num).toDouble();
            return amount.abs() <= maxAmount;
          }
          return false;
        }).toList();
      }
    }

    widget.onFiltered(filtered);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
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
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 24),
        // Search Field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Category Section
        Text(
          'Category',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: Colors.grey[850],
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                  _applyFilters();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Type Section
        Text(
          'Type',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              dropdownColor: Colors.grey[850],
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
              items: ['All', 'Income', 'Expense'].map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                  _applyFilters();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Date Range Section
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Date',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            _startDate == null
                                ? 'Select'
                                : DateFormat('MMM d, y').format(_startDate!),
                            style: GoogleFonts.poppins(
                              color: _startDate == null
                                  ? Colors.grey[600]
                                  : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'End Date',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            _endDate == null
                                ? 'Select'
                                : DateFormat('MMM d, y').format(_endDate!),
                            style: GoogleFonts.poppins(
                              color: _endDate == null
                                  ? Colors.grey[600]
                                  : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Amount Range Section
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Min Amount',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _minAmountController,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Max Amount',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _maxAmountController,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _applyFilters();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Apply Filters',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }
}
