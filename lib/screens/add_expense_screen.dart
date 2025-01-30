import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/expense.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense; // Nullable Expense parameter to support editing

  const AddExpenseScreen({super.key, this.expense});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class MoneyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final int selectionIndex = newValue.selection.end;
    final String formattedText = _formatter.format(int.parse(newValue.text.replaceAll(',', '')));
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: selectionIndex + formattedText.length - newValue.text.length),
    );
  }
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _spendDateController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(); // New category controller

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

  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text;
      final double amount = double.parse(_amountController.text.replaceAll(',', ''));
      final DateTime spendDate = DateTime.parse(_spendDateController.text);
      final String category = _categoryController.text;

      final Expense newExpense = Expense(
        name: name,
        amount: amount,
        spend_date: spendDate,
        category: category,
        created_at: DateTime.now(),
        updated_at: DateTime.now(),
      );

      if (widget.expense == null) {
        DBHelper().insertExpense(newExpense);
      } else {
        final Expense updatedExpense = newExpense.copyWith(id: widget.expense!.id);
        DBHelper().updateExpense(updatedExpense);
      }

      Navigator.pop(context);
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
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  MoneyInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter amount',
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _spendDateController,
                decoration: const InputDecoration(
                  labelText: 'Spend Date',
                  hintText: 'Enter spend date',
                ),
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  await _selectDate(context);
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a spend date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveExpense,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}