import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../helpers/db_helper.dart';
import 'package:logger/logger.dart';

class DashboardScreen extends StatefulWidget {
  final String userName = "Mario Rangga";

  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Expense> _expenses = [];
  String _selectedMonth = '';
  List<String> _availableMonths = [];
  double _monthlyTotalExpense = 0.0;
  Expense? _biggestExpense;
  Map<String, double> _categoryTotals = {};

  final Logger _logger = Logger();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() {
    });
    try {
      List<Expense> expenses = await DBHelper().getExpenses();
      setState(() {
        _expenses = expenses;
        _availableMonths = _getAvailableMonths();
        _selectedMonth = _availableMonths.isNotEmpty ? _availableMonths.first : '';
        _filterExpensesByMonth(_selectedMonth);
      });
    } catch (e, stackTrace) {
      _logger.e('Error fetching expenses', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch expenses. Please try again.')),
      );
    } finally {
      setState(() {
      });
    }
  }

  void _filterExpensesByMonth(String month) {
    List<Expense> filteredExpenses = _expenses.where((expense) => DateFormat('MMMM yyyy').format(expense.spend_date) == month).toList();
    _calculateCategoryTotalsForMonth(filteredExpenses);
    _calculateMonthlyTotalExpense(filteredExpenses);
    _calculateBiggestExpense(filteredExpenses);
  }

  List<String> _getAvailableMonths() {
    return _expenses.map((expense) => DateFormat('MMMM yyyy').format(expense.spend_date)).toSet().toList();
  }

  void _calculateCategoryTotalsForMonth(List<Expense> expenses) {
    _categoryTotals = {};
    for (var expense in expenses) {
      if (_categoryTotals.containsKey(expense.category)) {
        _categoryTotals[expense.category] = _categoryTotals[expense.category]! + expense.amount;
      } else {
        _categoryTotals[expense.category] = expense.amount;
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'jajan':
        return Colors.green;
      case 'makan':
        return Colors.purple;
      case 'others':
        return Colors.orange;
      case 'savings':
        return Colors.blue;
      case 'mandatory share income':
        return Colors.grey;
      case 'investment':
        return Colors.brown;
      case 'tarik tunai':
        return Colors.grey.shade800;
      case 'health':
        return Colors.orange.shade100;
      default:
        return Colors.black;
    }
  }

  void _calculateMonthlyTotalExpense(List<Expense> expenses) {
    _monthlyTotalExpense = expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  void _calculateBiggestExpense(List<Expense> expenses) {
    if (expenses.isNotEmpty) {
      _biggestExpense = expenses.reduce((curr, next) => curr.amount > next.amount ? curr : next);
    } else {
      _biggestExpense = null;
    }
  }


  void _calculateCategoryTotals() {
    _categoryTotals.clear();
    for (var expense in _expenses) {
      _categoryTotals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${widget.userName}'),
        backgroundColor: Colors.blueGrey[900],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCards(),
            SizedBox(height: 16),
            _buildCategoryDistributionChart(),
            SizedBox(height: 16),
            _buildMonthlyExpenseBarChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard('Total Expenses ($_selectedMonth)', currencyFormatter.format(_monthlyTotalExpense), Colors.white),
          _buildSummaryCard(
            'Biggest Expense',
            _biggestExpense != null
                ? '${_biggestExpense!.name}: ${currencyFormatter.format(_biggestExpense!.amount)}'
                : 'No expenses',
            Colors.white,
          ),
          _buildSummaryCard('Number of Expenses (All Month)', '${_expenses.length}', Colors.white),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 2),
          Text(amount, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionChart() {
    List<PieChartSectionData> sections = _categoryTotals.entries.map((entry) {
      double total = _categoryTotals.values.fold(0, (sum, value) => sum + value);
      double percentage = (entry.value / total) * 100;
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: _getCategoryColor(entry.key),
        radius: 50,
        showTitle: true,
        titleStyle: TextStyle(fontSize: 12, color: Colors.white),
      );
    }).toList();

    return Column(
      children: [
        DropdownButton<String>(
          value: _selectedMonth,
          icon: Icon(Icons.filter_alt),
          dropdownColor: Colors.blueGrey[800],
          style: TextStyle(color: Colors.white),
          items: _availableMonths.map((String month) {
            return DropdownMenuItem<String>(
              value: month,
              child: Text(month),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedMonth = newValue;
                _filterExpensesByMonth(_selectedMonth);
              });
            }
          },
        ),
        SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.blueGrey[800],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              borderData: FlBorderData(show: false),
              pieTouchData: PieTouchData(
                touchCallback: (event, pieTouchResponse) {
                  if (event is FlTapUpEvent && pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                    final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    final category = _categoryTotals.keys.toList()[index];
                    final amount = _categoryTotals[category];
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$category: ${currencyFormatter.format(amount)}'),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categoryTotals.keys.map((category) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              color: _getCategoryColor(category),
            ),
            SizedBox(width: 4),
            Text(category, style: TextStyle(color: Colors.white)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyExpenseBarChart() {
    Map<String, double> monthlyExpenses = {};
    for (var expense in _expenses) {
      String month = DateFormat('MMM yyyy').format(expense.spend_date);
      monthlyExpenses.update(
        month,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    List<BarChartGroupData> barGroups = monthlyExpenses.entries.map((entry) {
      int index = monthlyExpenses.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barsSpace: 50,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            gradient: LinearGradient(
              colors: [Colors.greenAccent, Colors.green],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 30,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: barGroups.length * 70.0,
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              maxY: monthlyExpenses.values.isNotEmpty
                  ? (monthlyExpenses.values.reduce((a, b) => a > b ? a : b) * 1.2)
                  : 0.0,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: false,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        currencyFormatter.format(value),
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    // reservedSize: 22,
                    showTitles: true,
                    // interval: 5,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= monthlyExpenses.keys.length) {
                        return Container(); // Avoid out-of-bounds errors
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          monthlyExpenses.keys.elementAt(index),
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey, strokeWidth: 0.5);
                },
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${monthlyExpenses.keys.elementAt(group.x)}\n${currencyFormatter.format(rod.toY)}',
                      TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      )
    );
  }
}