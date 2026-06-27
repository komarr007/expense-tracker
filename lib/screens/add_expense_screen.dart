import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../helpers/finance_math.dart';
import '../models/expense.dart';
import '../services/category_registry.dart';
import '../services/notification_service.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;
  const AddExpenseScreen({super.key, this.expense});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

// ── Formats digits as comma-separated thousands (no decimals) ─────────────────
class _MoneyFormatter extends TextInputFormatter {
  final NumberFormat _nf = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue val) {
    if (val.text.isEmpty) return val.copyWith(text: '');
    final String raw = val.text.replaceAll(',', '');
    final int? num = int.tryParse(raw);
    if (num == null) return old;
    final String formatted = _nf.format(num);
    return val.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  List<String> get _categories => CategoryRegistry().names;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl   = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _dateCtrl   = TextEditingController();
  final TextEditingController _notesCtrl  = TextEditingController();
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  String? _selectedCategory;
  bool _saving = false;

  double get _opportunityCostFV {
    final double? amt =
        double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amt == null || amt <= 0) return 0;
    return FinanceMath.futureValueLump(amt, 0.07, 10);
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    if (widget.expense != null) {
      final Expense e = widget.expense!;
      _nameCtrl.text   = e.name;
      _amountCtrl.text = NumberFormat('#,##0', 'en_US').format(e.amount);
      _dateCtrl.text   = DateFormat('yyyy-MM-dd').format(e.spend_date);
      _notesCtrl.text  = e.notes ?? '';
      final String cat = e.category.toLowerCase();
      _selectedCategory = _categories.contains(cat)
          ? cat
          : (_categories.isNotEmpty ? _categories.last : null);
    } else {
      _dateCtrl.text    = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
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
    final DateTime? picked = await showDatePicker(
      context:     context,
      initialDate: widget.expense?.spend_date ?? DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.accent,
            onPrimary: Colors.white,
            surface:   AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final double amount =
        double.parse(_amountCtrl.text.replaceAll(',', ''));

    final Expense expense = Expense(
      name:       _nameCtrl.text.trim(),
      amount:     amount,
      spend_date: DateTime.parse(_dateCtrl.text),
      category:   _selectedCategory!,
      notes:      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      created_at: widget.expense?.created_at ?? DateTime.now(),
      updated_at: DateTime.now(),
    );

    if (widget.expense == null) {
      await DBHelper().insertExpense(expense);
      NotificationService().checkBudgets(expense);
    } else {
      await DBHelper().updateExpense(expense.copyWith(id: widget.expense!.id));
    }
    ReloadNotifier.instance.notify();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Expense' : 'Add Expense'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[

                // ── Name ─────────────────────────────────────────
                _label('Expense Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Lunch at warung',
                    prefixIcon: Icon(Icons.label_outline_rounded,
                        size: 20, color: AppColors.textMuted),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),

                const SizedBox(height: 16),

                // ── Amount ────────────────────────────────────────
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
                    prefixIcon: Icon(Icons.payments_outlined,
                        size: 20, color: AppColors.textMuted),
                    prefix: Text(
                      'Rp  ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Amount is required' : null,
                ),
                // Opportunity cost nudge — live as user types
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _opportunityCostFV > 0
                      ? Padding(
                          key: const ValueKey<String>('oc'),
                          padding: const EdgeInsets.only(top: 5, left: 4),
                          child: Text(
                            '≈ ${_fmt.format(_opportunityCostFV)} in 10 yrs at 7%/yr if invested',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey<String>('empty')),
                ),

                const SizedBox(height: 16),

                // ── Date ──────────────────────────────────────────
                _label('Date'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Select date',
                    prefixIcon: Icon(Icons.calendar_month_outlined,
                        size: 20, color: AppColors.textMuted),
                    suffixIcon:
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Date is required' : null,
                ),

                const SizedBox(height: 16),

                // ── Category ──────────────────────────────────────
                _label('Category'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  icon: const Icon(Icons.expand_more_rounded,
                      color: AppColors.textMuted),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined,
                        size: 20, color: AppColors.textMuted),
                  ),
                  items: _categories.map((String cat) {
                    final Color c = AppColors.category(cat);
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration:
                                BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Text(cat),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Category is required' : null,
                ),

                const SizedBox(height: 16),

                // ── Notes ─────────────────────────────────────────
                _label('Notes (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Any extra details…',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Save button ───────────────────────────────────
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(isEdit
                          ? Icons.check_rounded
                          : Icons.add_circle_outline_rounded),
                  label: Text(isEdit ? 'Save Changes' : 'Add Expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
}
