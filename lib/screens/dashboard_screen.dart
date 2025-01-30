import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../helpers/db_helper.dart';
import 'package:logger/logger.dart';

class DashboardScreen extends StatefulWidget {
  final String userName = 'Mario Rangga';

  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Expense> _expenses = <Expense>[];
  String _selectedMonth = '';
  List<String> _availableMonths = <String>[];
  double _monthlyTotalExpense = 0.0;
  Expense? _biggestExpense;
  Map<String, double> _categoryTotals = <String, double>{};
  double _savingsTotal = 0.0;

  final Logger _logger = Logger();
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() {
    });
    try {
      final List<Expense> expenses = await DBHelper().getExpenses();
      setState(() {
        _expenses = expenses;
        _availableMonths = _getAvailableMonths();
        _selectedMonth = _availableMonths.isNotEmpty ? _availableMonths.first : '';
        _filterExpensesByMonth(_selectedMonth);
      });
    } catch (e, stackTrace) {
      _logger.e('Error fetching expenses', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch expenses. Please try again.')),
      );
    } finally {
      setState(() {
      });
    }
  }

  void _filterExpensesByMonth(String month) {
    final List<Expense> filteredExpenses = _expenses.where((Expense expense) => DateFormat('MMMM yyyy').format(expense.spend_date) == month).toList();
    _calculateCategoryTotalsForMonth(filteredExpenses);
    _calculateMonthlyTotalExpense(filteredExpenses);
    _calculateBiggestExpense(filteredExpenses);
    _calculateTotalSavings(filteredExpenses);
  }

  List<String> _getAvailableMonths() {
    return _expenses.map((Expense expense) => DateFormat('MMMM yyyy').format(expense.spend_date)).toSet().toList();
  }

  void _calculateCategoryTotalsForMonth(List<Expense> expenses) {
    _categoryTotals = <String, double>{};
    for (Expense expense in expenses) {
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
    _monthlyTotalExpense = expenses.fold(0.0, (double sum, Expense expense) => sum + expense.amount);
  }

  void _calculateBiggestExpense(List<Expense> expenses) {
    if (expenses.isNotEmpty) {
      _biggestExpense = expenses.reduce((Expense curr, Expense next) => curr.amount > next.amount ? curr : next);
    } else {
      _biggestExpense = null;
    }
  }

  void _calculateTotalSavings(List<Expense> expenses) {
    _savingsTotal = _expenses.where((Expense expense) => expense.category == 'savings').fold(0.0, (double sum, Expense expense) => sum + expense.amount);
  }

  void _calculateCategoryTotals() {
    _categoryTotals.clear();
    for (Expense expense in _expenses) {
      _categoryTotals.update(
        expense.category,
        (double value) => value + expense.amount,
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
          children: <Widget>[
            _buildSummaryCards(),
            const SizedBox(height: 16),
            _buildCategoryDistributionChart(),
            const SizedBox(height: 16),
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
        children: <Widget>[
          _buildSummaryCard('Total Expenses ($_selectedMonth)', currencyFormatter.format(_monthlyTotalExpense), Colors.white),
          _buildSummaryCard(
            'Biggest Expense',
            _biggestExpense != null
                ? '${_biggestExpense!.name}: ${currencyFormatter.format(_biggestExpense!.amount)}'
                : 'No expenses',
            Colors.white,
          ),
          _buildSummaryCard('Number of Expenses (All Month)', '${_expenses.length}', Colors.white),
          _buildSummaryCard('Total Savings', currencyFormatter.format(_savingsTotal), Colors.white),
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
        children: <Widget>[
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(amount, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionChart() {
    final List<PieChartSectionData> sections = _categoryTotals.entries.map((MapEntry<String, double> entry) {
      final double total = _categoryTotals.values.fold(0, (double sum, double value) => sum + value);
      final double percentage = (entry.value / total) * 100;
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: _getCategoryColor(entry.key),
        radius: 50,
        showTitle: true,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      );
    }).toList();

    return Column(
      children: <Widget>[
        DropdownButton<String>(
          value: _selectedMonth,
          icon: const Icon(Icons.filter_alt),
          dropdownColor: Colors.blueGrey[800],
          style: const TextStyle(color: Colors.white),
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
        const SizedBox(height: 16),
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
                touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                  if (event is FlTapUpEvent && pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                    final int index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    final String category = _categoryTotals.keys.toList()[index];
                    final double? amount = _categoryTotals[category];
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
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categoryTotals.keys.map((String category) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              color: _getCategoryColor(category),
            ),
            const SizedBox(width: 4),
            Text(category, style: const TextStyle(color: Colors.white)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyExpenseBarChart() {
    final Map<String, double> monthlyExpenses = <String, double>{};
    for (Expense expense in _expenses) {
      final String month = DateFormat('MMM yyyy').format(expense.spend_date);
      monthlyExpenses.update(
        month,
        (double value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final List<BarChartGroupData> barGroups = monthlyExpenses.entries.map((MapEntry<String, double> entry) {
      final int index = monthlyExpenses.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barsSpace: 50,
        barRods: <BarChartRodData>[
          BarChartRodData(
            toY: entry.value,
            gradient: const LinearGradient(
              colors: <Color>[Colors.greenAccent, Colors.green],
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
                  ? (monthlyExpenses.values.reduce((double a, double b) => a > b ? a : b) * 1.2)
                  : 0.0,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    reservedSize: 50,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        currencyFormatter.format(value),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    // reservedSize: 22,
                    showTitles: true,
                    // interval: 5,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= monthlyExpenses.keys.length) {
                        return Container(); // Avoid out-of-bounds errors
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          monthlyExpenses.keys.elementAt(index),
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                getDrawingHorizontalLine: (double value) {
                  return const FlLine(color: Colors.grey, strokeWidth: 0.5);
                },
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                    return BarTooltipItem(
                      '${monthlyExpenses.keys.elementAt(group.x)}\n${currencyFormatter.format(rod.toY)}',
                      const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.bold),
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