import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/income_record.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';

class AddIncomeScreen extends StatefulWidget {
  final IncomeRecord? income;
  const AddIncomeScreen({super.key, this.income});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
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

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _nameCtrl   = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _dateCtrl   = TextEditingController();
  final TextEditingController _notesCtrl  = TextEditingController();
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.income != null) {
      final IncomeRecord r = widget.income!;
      _nameCtrl.text   = r.name;
      _amountCtrl.text = NumberFormat('#,##0', 'en_US').format(r.amount);
      _dateCtrl.text   = DateFormat('yyyy-MM-dd').format(r.income_date);
      _notesCtrl.text  = r.notes ?? '';
      final String cat = r.category.toLowerCase();
      _category = IncomeRecord.categories.contains(cat) ? cat : IncomeRecord.categories.last;
    } else {
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _category      = IncomeRecord.categories.first;
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
      initialDate: widget.income?.income_date ?? DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.positive, onPrimary: Colors.black,
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
    final IncomeRecord record = IncomeRecord(
      name:        _nameCtrl.text.trim(),
      amount:      amount,
      income_date: DateTime.parse(_dateCtrl.text),
      category:    _category!,
      notes:       _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    if (widget.income == null) {
      await DBHelper().insertIncome(record);
    } else {
      await DBHelper().updateIncome(record.copyWith(id: widget.income!.id));
    }
    ReloadNotifier.instance.notify();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.income != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Income' : 'Add Income')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _label('Income Source'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Monthly salary',
                    prefixIcon: Icon(Icons.label_outline_rounded, size: 20, color: AppColors.textMuted),
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
                _label('Date'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Select date',
                    prefixIcon: Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.textMuted),
                    suffixIcon: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Date is required' : null,
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
                  items: IncomeRecord.categories.map((cat) {
                    final Color c = AppColors.income(cat);
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
                _label('Notes (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Any additional details…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isEdit ? Icons.check_rounded : Icons.add_circle_outline_rounded),
                  label: Text(isEdit ? 'Save Changes' : 'Add Income'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, foregroundColor: Colors.black),
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
