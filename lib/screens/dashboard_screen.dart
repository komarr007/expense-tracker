import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../helpers/db_helper.dart';

class DashboardScreen extends StatefulWidget {
  final String userName = "Mario Rangga";

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Expense> _expenses = [];
  double _monthlyTotalExpense = 0.0;
  Expense? _biggestExpense;
  Map<String, double> _categoryTotals = {};

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    List<Expense> expenses = await DBHelper().getExpenses();
    setState(() {
      _expenses = expenses;
      _calculateMonthlyTotalExpense();
      _calculateBiggestExpense();
      _calculateCategoryTotals();
    });
  }

  void _calculateMonthlyTotalExpense() {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    _monthlyTotalExpense = _expenses
        .where((expense) => expense.spend_date.isAfter(startOfMonth))
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  void _calculateBiggestExpense() {
    if (_expenses.isNotEmpty) {
      _biggestExpense = _expenses.reduce((a, b) => a.amount > b.amount ? a : b);
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
          _buildSummaryCard('Total Expenses', currencyFormatter.format(_monthlyTotalExpense), Colors.white),
          _buildSummaryCard(
            'Biggest Expense',
            _biggestExpense != null
                ? '${_biggestExpense!.name}: ${currencyFormatter.format(_biggestExpense!.amount)}'
                : 'No expenses',
            Colors.white,
          ),
          _buildSummaryCard('Number of Expenses', '${_expenses.length}', Colors.white),
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
      );
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'jajan':
        return Colors.green;
      case 'makan':
        return Colors.blue;
      case 'others':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
        child: Container(
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