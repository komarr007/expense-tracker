import 'package:flutter/material.dart';
import 'add_expense_screen.dart';
import '../models/expense.dart';
import '../models/history_record.dart';
import '../helpers/db_helper.dart';
import 'package:intl/intl.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  _ExpenseListScreenState createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  List<Expense> _expenses = <Expense>[];
  List<Expense> _allExpenses = <Expense>[];
  final Map<String, List<Expense>> _expensesByMonth = <String, List<Expense>>{};
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  bool _showSearchBar = false;
  bool _filterActive = false;
  String _filterSummary = '';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() async {
    final List<Expense> expenses = await DBHelper().getExpenses();
    setState(() {
      _allExpenses = expenses;
      _expenses = List.from(_allExpenses);
      _groupExpensesByMonth();
    });
  }

  void _groupExpensesByMonth() {
    _expensesByMonth.clear();
    for (Expense expense in _expenses) {
      final String monthKey = DateFormat('MMMM yyyy').format(expense.spend_date);
      if (_expensesByMonth.containsKey(monthKey)) {
        _expensesByMonth[monthKey]!.add(expense);
      } else {
        _expensesByMonth[monthKey] = <Expense>[expense];
      }
    }
  }

  void _deleteExpense(Expense expense) async {
    if (expense.id != null) {
      // log deletion to history
      final HistoryRecord historyRecord = HistoryRecord(
        name: expense.name,
        amount: expense.amount,
        spend_date: expense.spend_date,
        created_at: expense.created_at,
        updated_at: expense.updated_at,
        category: expense.category,
        deleted_at: DateTime.now(),
      );
      await DBHelper().insertHistoryRecord(historyRecord);

      //delete expense from list
      await DBHelper().deleteExpense(expense.id!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record deleted and logged in history')),
      );
    }
    _loadExpenses();
  }

  void _editExpense(Expense expense) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => AddExpenseScreen(expense: expense),
      ),
    );
    _loadExpenses();
  }

  void _filterExpensesByDate(DateTime startDate, DateTime endDate) {
    setState(() {
      _expenses = _allExpenses.where((Expense expense) {
        return expense.spend_date.isAfter(startDate) &&
               expense.spend_date.isBefore(endDate);
      }).toList();
      _groupExpensesByMonth();
      _filterActive = true;
      _filterSummary = '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd').format(endDate)}';
    });
  }

  void _searchExpensesByName(String searchTerm) {
    setState(() {
      _expenses = _allExpenses.where((Expense expense) {
        return expense.name.toLowerCase().contains(searchTerm.toLowerCase());
      }).toList();
      _groupExpensesByMonth();
    });
  }

  void _resetFilters() {
    setState(() {
      _expenses = List.from(_allExpenses);
      _groupExpensesByMonth();
      _filterActive = false;
      _filterSummary = '';
    });
  }

  void _showFilterDialog() async {
    final DateTime? startDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (startDate == null) return;

    final DateTime? endDate = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: startDate,
      lastDate: DateTime.now(),
    );

    if (endDate == null) return;

    _filterExpensesByDate(startDate, endDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Records'),
        actions: <Widget>[
          if (!_showSearchBar)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _showSearchBar = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) => _buildBottomSheetMenu(),
              );
            },
          ),
        ],
        bottom: _showSearchBar
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    onChanged: (String value) => _searchExpensesByName(value),
                    decoration: const InputDecoration(
                      hintText: 'Search expenses...',
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                    onSubmitted: (_) {
                      setState(() {
                        _showSearchBar = false;
                      });
                    },
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: <Widget>[
          if (_filterActive)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  Chip(
                    label: Text('Filter Active: $_filterSummary'),
                    deleteIcon: const Icon(Icons.clear),
                    onDeleted: _resetFilters,
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              children: _expensesByMonth.keys.map((String month) {
                return ExpansionTile(
                  title: Text(
                    month,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  children: _expensesByMonth[month]!.map((Expense expense) {
                    return Dismissible(
                      key: Key(expense.id.toString()),
                      direction: DismissDirection.endToStart,
                      onDismissed: (DismissDirection direction) {
                        if (direction == DismissDirection.endToStart) {
                          _deleteExpense(expense);
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        title: Text(expense.name),
                        subtitle: Text(
                          'Rp ${_currencyFormat.format(expense.amount)}\n'
                          'Date: ${DateFormat('yyyy-MM-dd').format(expense.spend_date)}\n'
                          'Category: ${expense.category}', // Added category here
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showOptions(context, expense),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (BuildContext context) => const AddExpenseScreen()),
          ).then((_) => _loadExpenses());
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBottomSheetMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.filter_list),
          title: const Text('Filter'),
          onTap: () {
            Navigator.pop(context);
            _showFilterDialog();
          },
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Search'),
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _showSearchBar = true;
            });
          },
        ),
        ListTile(
          leading: const Icon(Icons.clear),
          title: const Text('Reset Filters'),
          onTap: () {
            Navigator.pop(context);
            _resetFilters();
          },
        ),
      ],
    );
  }

  void _showOptions(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editExpense(expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteExpense(expense);
              },
            ),
          ],
        );
      },
    );
  }
}