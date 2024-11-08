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
  List<FlSpot> _weeklyExpenseSpots = [];

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    // Fetch all expenses from the database
    List<Expense> expenses = await DBHelper().getExpenses();

    setState(() {
      _expenses = expenses;
      _calculateMonthlyTotalExpense();
      _calculateBiggestExpense();
      _calculateCategoryTotals();
      _calculateWeeklyExpenses();
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

  void _calculateWeeklyExpenses() {
    DateTime now = DateTime.now();
    List<FlSpot> spots = [];
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      double dailyTotal = _expenses
          .where((expense) =>
              expense.spend_date.year == day.year &&
              expense.spend_date.month == day.month &&
              expense.spend_date.day == day.day)
          .fold(0.0, (sum, expense) => sum + expense.amount);
      spots.add(FlSpot(6 - i.toDouble(), dailyTotal));
    }
    _weeklyExpenseSpots = spots;
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
            _buildWeeklyExpenseTrendChart(),
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
          _buildSummaryCard('Total Expenses', currencyFormatter.format(_monthlyTotalExpense), const Color.fromARGB(255, 255, 255, 255)),
          _buildSummaryCard(
            'Biggest Expense', 
            _biggestExpense != null 
              ? '${_biggestExpense!.name}: ${currencyFormatter.format(_biggestExpense!.amount)}' 
              : 'No expenses',
            const Color.fromARGB(255, 255, 255, 255),
          ),
          _buildSummaryCard('Number of Expenses', '${_expenses.length}', const Color.fromARGB(255, 255, 255, 255)),
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
    List<PieChartSectionData> sections = _categoryTotals.entries
        .map((entry) {
          double total = _categoryTotals.values.fold(0, (sum, value) => sum + value);
          double percentage = (entry.value / total) * 100;
          return PieChartSectionData(
            value: entry.value,
            title: '${percentage.toStringAsFixed(1)}%', // Only show the percentage on the chart
            color: _getCategoryColor(entry.key),
            radius: 50,
            badgeWidget: GestureDetector(
              onTap: () => _showCategoryInfo(entry.key, entry.value),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            badgePositionPercentageOffset: 0.98, // Position it near the edge
          );
        })
        .toList();

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

  void _showCategoryInfo(String category, double total) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey[900],
          title: Text(
            'Category Info',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '$category: ${currencyFormatter.format(total)}',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'jajan':
        return const Color.fromARGB(255, 27, 85, 50);
      case 'makan':
        return const Color.fromARGB(255, 33, 29, 138);
      case 'others':
        return const Color.fromARGB(255, 114, 60, 27);
      case 'investment':
        return const Color.fromARGB(255, 29, 65, 67);
      case 'health':
        return const Color.fromARGB(255, 28, 147, 90);
      case 'tarik tunai':
        return const Color.fromARGB(255, 64, 62, 61);
      case 'saving':
        return const Color.fromARGB(255, 126, 126, 125);
      case 'mandatory share income':
        return const Color.fromARGB(255, 74, 1, 84);
      default:
        return Colors.green;
    }
  }

  Widget _buildWeeklyExpenseTrendChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final day = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                  return Text('${day.day}/${day.month}');
                },
                interval: 1,
              ),
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: _weeklyExpenseSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 4,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}