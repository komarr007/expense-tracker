import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../helpers/db_helper.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense; // Nullable Expense parameter to support editing

  AddExpenseScreen({this.expense});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _spendDateController = TextEditingController();
  final _categoryController = TextEditingController(); // New category controller

  @override
  void initState() {
    super.initState();
    // If editing an expense, populate the form fields with existing values
    if (widget.expense != null) {
      _nameController.text = widget.expense!.name;
      _amountController.text = widget.expense!.amount.toString();
      _spendDateController.text = widget.expense!.spend_date.toIso8601String();
      _categoryController.text = widget.expense!.category; // Set existing category
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.expense?.spend_date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        _spendDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Expense Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _spendDateController,
                decoration: InputDecoration(labelText: 'Spend Date'),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(labelText: 'Category'), // New category field
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final expense = Expense(
                      id: widget.expense?.id, // Use existing id if editing
                      name: _nameController.text,
                      amount: double.parse(_amountController.text),
                      spend_date: DateTime.parse(_spendDateController.text),
                      category: _categoryController.text, // Add category here
                    );

                    if (widget.expense == null) {
                      // Add new expense
                      await DBHelper().insertExpense(expense);
                    } else {
                      // Update existing expense
                      await DBHelper().updateExpense(expense);
                    }

                    Navigator.pop(context); // Go back to the previous screen
                  }
                },
                child: Text(widget.expense == null ? 'Add Expense' : 'Update Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}