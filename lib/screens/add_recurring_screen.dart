import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/recurring_expense.dart';
import '../theme/app_theme.dart';

class AddRecurringScreen extends StatefulWidget {
  final RecurringExpense? recurring;
  const AddRecurringScreen({super.key, this.recurring});

  @override
  State<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _MoneyFormatter extends TextInputFormatter {
  final NumberFormat _nf = NumberFormat('#,##0', 'en_US');
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) {
    if (val.text.isEmpty) return val.copyWith(text: '');
    final int? n = int.tryParse(val.text.replaceAll(',', ''));
    if (n == null) return old;
    final String f = _nf.format(n);
    return val.copyWith(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}


class _AddRecurringScreenState extends State<AddRecurringScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _nameCtrl   = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _dateCtrl   = TextEditingController();
  final TextEditingController _notesCtrl  = TextEditingController();
  String? _category;
  String _frequency = 'monthly';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.recurring != null) {
      final RecurringExpense r = widget.recurring!;
      _nameCtrl.text   = r.name;
      _amountCtrl.text = NumberFormat('#,##0', 'en_US').format(r.amount);
      _dateCtrl.text   = DateFormat('yyyy-MM-dd').format(r.next_due);
      _notesCtrl.text  = r.notes ?? '';
      final String cat = r.category.toLowerCase();
      _category  = AppCategories.expense.contains(cat) ? cat : AppCategories.expense.last;
      _frequency = r.frequency;
    } else {
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _category      = AppCategories.expense.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context:     context,
      initialDate: widget.recurring?.next_due ?? DateTime.now(),
      firstDate:   DateTime.now(),
      lastDate:    DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent, onPrimary: Colors.white,
            surface: AppColors.card, onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _dateCtrl.text = DateFormat('yyyy-MM-dd').format(d));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final double amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
    final RecurringExpense r = RecurringExpense(
      name:      _nameCtrl.text.trim(),
      amount:    amount,
      category:  _category!,
      notes:     _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      frequency: _frequency,
      next_due:  DateTime.parse(_dateCtrl.text),
    );
    if (widget.recurring == null) {
      await DBHelper().insertRecurring(r);
    } else {
      await DBHelper().updateRecurring(r.copyWith(id: widget.recurring!.id));
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.recurring != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Recurring' : 'Add Recurring')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _label('Expense Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Netflix subscription',
                    prefixIcon: Icon(Icons.repeat_rounded, size: 20, color: AppColors.textMuted),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                _label('Amount'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    _MoneyFormatter(),
                  ],
                  decoration: const InputDecoration(
                    hintText: '0',
                    prefixIcon: Icon(Icons.payments_outlined, size: 20, color: AppColors.textMuted),
                    prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Amount is required' : null,
                ),
                const SizedBox(height: 16),
                _label('Category'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined, size: 20, color: AppColors.textMuted),
                  ),
                  items: AppCategories.expense.map((cat) {
                    final Color c = AppColors.category(cat);
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Row(children: <Widget>[
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text(cat),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Category is required' : null,
                ),
                const SizedBox(height: 16),
                _label('Frequency'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.card,
                    selectedBackgroundColor: AppColors.accent.withOpacity(0.2),
                    selectedForegroundColor: AppColors.accent,
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment(value: 'daily',   label: Text('Daily')),
                    ButtonSegment(value: 'weekly',  label: Text('Weekly')),
                    ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ],
                  selected: <String>{_frequency},
                  onSelectionChanged: (Set<String> sel) =>
                      setState(() => _frequency = sel.first),
                ),
                const SizedBox(height: 16),
                _label(isEdit ? 'Next Due Date' : 'First Due Date'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Select date',
                    prefixIcon: Icon(Icons.event_repeat_rounded, size: 20, color: AppColors.textMuted),
                    suffixIcon: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Date is required' : null,
                ),
                const SizedBox(height: 16),
                _label('Notes (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Any details…'),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isEdit ? Icons.check_rounded : Icons.add_circle_outline_rounded),
                  label: Text(isEdit ? 'Save Changes' : 'Add Recurring'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500));
}
