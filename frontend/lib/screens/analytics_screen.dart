import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../config/api_config.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  String _selectedPeriod = 'This Month';
  final List<String> _periods = [
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'Last 3 Months',
    'This Year',
    'Custom Range'
  ];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initializeDates();
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
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  void _initializeDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Week':
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _endDate = now;
        break;
      case 'Last Week':
        _startDate = now.subtract(Duration(days: now.weekday + 6));
        _endDate = now.subtract(Duration(days: now.weekday));
        break;
      case 'This Month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'Last Month':
        _startDate = DateTime(now.year, now.month - 1, 1);
        _endDate = DateTime(now.year, now.month, 0);
        break;
      case 'Last 3 Months':
        _startDate = DateTime(now.year, now.month - 2, 1);
        _endDate = now;
        break;
      case 'This Year':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = now;
        break;
      default:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
    }
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
              secondary: Colors.amberAccent,
              onSecondary: Colors.black,
              background: Colors.grey[900]!,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme.copyWith(
                    bodyLarge: TextStyle(color: Colors.white),
                    bodyMedium: TextStyle(color: Colors.white),
                    titleMedium: TextStyle(color: Colors.white),
                  ),
            ),
            dialogBackgroundColor: Colors.grey[900],
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber,
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.grey[900],
              headerBackgroundColor: Colors.amber,
              headerForegroundColor: Colors.black,
              weekdayStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
              dayStyle: GoogleFonts.poppins(
                color: Colors.white,
              ),
              todayBorder: BorderSide(color: Colors.amber, width: 1),
              dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.amber;
                }
                return null;
              }),
              dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
              rangePickerBackgroundColor: Colors.grey[850],
              rangePickerSurfaceTintColor: Colors.amber.withOpacity(0.1),
              rangeSelectionBackgroundColor: Colors.amber.withOpacity(0.2),
              rangeSelectionOverlayColor:
                  MaterialStateProperty.all(Colors.amber.withOpacity(0.2)),
              yearStyle: GoogleFonts.poppins(
                color: Colors.white,
              ),
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(28),
            ),
            child: child!,
          ),
        );
      },
      currentDate: DateTime.now(),
      saveText: 'Apply Range',
      errorFormatText: 'Invalid format',
      errorInvalidText: 'Invalid range',
      errorInvalidRangeText: 'Invalid range',
      fieldStartHintText: 'Start Date',
      fieldEndHintText: 'End Date',
      fieldStartLabelText: 'Start Date',
      fieldEndLabelText: 'End Date',
      confirmText: 'Apply',
      cancelText: 'Cancel',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'Custom Range';
        _loadTransactions();
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    if (_startDate == null || _endDate == null) return [];

    return _transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
          date.isBefore(_endDate!.add(const Duration(days: 1)));
    }).toList();
  }

  Widget _buildDateRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                dropdownColor: Colors.grey[850],
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.amber),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                items: _periods.map((period) {
                  return DropdownMenuItem<String>(
                    value: period,
                    child: Text(period),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == 'Custom Range') {
                    _showDateRangePicker();
                  } else if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                      _initializeDates();
                    });
                  }
                },
              ),
            ),
          ),
          if (_selectedPeriod == 'Custom Range' &&
              _startDate != null &&
              _endDate != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: _showDateRangePicker,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_startDate!),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_endDate!),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseChart() {
    final filteredTransactions = _getFilteredTransactions();
    final List<FlSpot> incomeSpots = [];
    final List<FlSpot> expenseSpots = [];

    // Group transactions by date
    final Map<DateTime, double> incomeByDate = {};
    final Map<DateTime, double> expenseByDate = {};

    for (var transaction in filteredTransactions) {
      final date = DateTime.parse(transaction['date']);
      final amount = (transaction['amount'] as num).toDouble();

      final key = DateTime(date.year, date.month, date.day);
      if (amount > 0) {
        incomeByDate[key] = (incomeByDate[key] ?? 0) + amount;
      } else {
        expenseByDate[key] = (expenseByDate[key] ?? 0) + amount.abs();
      }
    }

    // Fill in missing dates with zero values
    if (_startDate != null && _endDate != null) {
      for (var d = _startDate!;
          d.isBefore(_endDate!.add(const Duration(days: 1)));
          d = d.add(const Duration(days: 1))) {
        final key = DateTime(d.year, d.month, d.day);
        incomeByDate.putIfAbsent(key, () => 0);
        expenseByDate.putIfAbsent(key, () => 0);
      }
    }

    // Convert to spots
    final sortedDates = incomeByDate.keys.toList()..sort();
    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      if (incomeByDate.containsKey(date)) {
        incomeSpots.add(FlSpot(i.toDouble(), incomeByDate[date]!));
      }
      if (expenseByDate.containsKey(date)) {
        expenseSpots.add(FlSpot(i.toDouble(), expenseByDate[date]!));
      }
    }

    // Calculate totals for the summary
    final totalIncome = incomeByDate.values.fold(0.0, (a, b) => a + b);
    final totalExpense = expenseByDate.values.fold(0.0, (a, b) => a + b);
    final balance = totalIncome - totalExpense;

    // Find max value for y-axis with empty state handling
    final maxValue = [
      ...incomeByDate.values,
      ...expenseByDate.values,
    ].isEmpty
        ? 100.0 // Default max value when no data
        : [
            ...incomeByDate.values,
            ...expenseByDate.values,
          ].reduce((max, value) => value > max ? value : max);
    final yInterval = _calculateYAxisInterval(maxValue);

    // If there's no data, show empty state
    if (filteredTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Income vs Expenses',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found for this period',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some transactions to see your financial analysis',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Income vs Expenses',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: balance >= 0
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Balance: ${NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US').format(balance)}',
                  style: GoogleFonts.poppins(
                    color: balance >= 0 ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Income',
                  totalIncome,
                  Colors.green,
                  Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Expenses',
                  totalExpense,
                  Colors.red,
                  Icons.arrow_downward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[800],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact().format(value),
                          style: GoogleFonts.poppins(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _calculateXAxisInterval(sortedDates.length),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sortedDates.length) {
                          final date = sortedDates[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat(_getDateFormat()).format(date),
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.green,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.1),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.green.withOpacity(0.2),
                          Colors.green.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.red,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withOpacity(0.1),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.red.withOpacity(0.2),
                          Colors.red.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.grey[800]!,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final date = index >= 0 && index < sortedDates.length
                            ? sortedDates[index]
                            : null;
                        return LineTooltipItem(
                          '${date != null ? DateFormat('MMM d').format(date) : ''}\n${NumberFormat.currency(symbol: '\$').format(spot.y)}',
                          GoogleFonts.poppins(
                            color:
                                spot.barIndex == 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Income', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Expenses', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  String _getDateFormat() {
    if (_startDate == null || _endDate == null) return 'MM/dd';

    final difference = _endDate!.difference(_startDate!).inDays;
    if (difference <= 14) return 'MM/dd'; // For periods up to 2 weeks
    if (difference <= 90) return 'MMM d'; // For periods up to 3 months
    return 'MMM'; // For longer periods
  }

  double _calculateYAxisInterval(double maxValue) {
    if (maxValue <= 100) return 20;
    if (maxValue <= 500) return 100;
    if (maxValue <= 1000) return 200;
    if (maxValue <= 5000) return 1000;
    if (maxValue <= 10000) return 2000;
    return maxValue / 5;
  }

  double _calculateXAxisInterval(int totalPoints) {
    if (totalPoints <= 7) return 1;
    if (totalPoints <= 14) return 2;
    if (totalPoints <= 31) return 5;
    return totalPoints / 6;
  }

  Widget _buildSummaryCard(
      String title, double amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(symbol: '\$').format(amount),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final filteredTransactions = _getFilteredTransactions();
    final Map<String, double> expensesByCategory = {};

    for (var transaction in filteredTransactions) {
      final amount = (transaction['amount'] as num).toDouble();
      if (amount < 0) {
        // Only consider expenses
        final category = transaction['category'] as String;
        expensesByCategory[category] =
            (expensesByCategory[category] ?? 0) + amount.abs();
      }
    }

    // If there are no expenses, show empty state
    if (expensesByCategory.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Expenses by Category',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.pie_chart,
              size: 48,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses found for this period',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some expenses to see your spending breakdown',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final List<PieChartSectionData> sections = [];
    final colors = [
      Colors.amber,
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];

    var colorIndex = 0;
    final totalExpense = expensesByCategory.values.fold(0.0, (a, b) => a + b);

    expensesByCategory.forEach((category, amount) {
      final percentage = (amount / totalExpense) * 100;
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: amount,
          title: '',
          radius: 100,
          titleStyle: const TextStyle(fontSize: 0),
          badgeWidget: null,
          badgePositionPercentageOffset: 0,
          showTitle: false,
        ),
      );
      colorIndex++;
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expenses by Category',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US').format(totalExpense)}',
            style: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 45,
                  sectionsSpace: 4,
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: expensesByCategory.entries.map((entry) {
                final index =
                    expensesByCategory.keys.toList().indexOf(entry.key);
                final percentage = (entry.value / totalExpense) * 100;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors[index % colors.length].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors[index % colors.length].withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          color: colors[index % colors.length],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
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
          'Analytics',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateRangeSelector(),
                    const SizedBox(height: 20),
                    _buildIncomeExpenseChart(),
                    const SizedBox(height: 20),
                    _buildCategoryChart(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
