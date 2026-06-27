import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../helpers/finance_math.dart';
import '../models/debt.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  List<Debt> _debts = <Debt>[];

  // Optimizer state (pure UI — no DB changes needed)
  String _strategy     = 'avalanche'; // 'avalanche' | 'snowball'
  double _extraPayment = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Debt> debts = await DBHelper().getDebts();
    if (mounted) setState(() => _debts = debts);
  }

  double get _totalBalance  => _debts.fold(0, (s, d) => s + d.currentBalance);
  double get _totalOriginal => _debts.fold(0, (s, d) => s + d.originalAmount);
  double get _totalMinPay   => _debts.fold(0, (s, d) => s + (d.minimumPayment ?? 0));

  // Returns active debts sorted by strategy, paid debts at the end
  List<Debt> get _sortedDebts {
    final List<Debt> active = _debts.where((d) => d.currentBalance > 0).toList();
    final List<Debt> paid   = _debts.where((d) => d.currentBalance <= 0).toList();
    if (_strategy == 'avalanche') {
      active.sort((a, b) => b.interestRate.compareTo(a.interestRate));
    } else {
      active.sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
    }
    return <Debt>[...active, ...paid];
  }

  // Whether optimizer section should be shown (at least one interest-bearing active debt)
  bool get _hasInterestDebts =>
      _debts.any((d) => d.currentBalance > 0 && d.interestRate > 0);

  DebtPayoffResult _resultFor(Debt d) {
    final double payment = (d.minimumPayment ?? 0) + _extraPayment;
    if (payment <= 0 || d.currentBalance <= 0) {
      return const DebtPayoffResult(months: 0, totalInterest: 0);
    }
    return FinanceMath.simulateDebtPayoff(
      balance: d.currentBalance,
      annualInterestRate: d.interestRate,
      monthlyPayment: payment,
    );
  }

  double get _totalInterestMinimums => _debts.fold(0.0, (s, d) {
    if (d.currentBalance <= 0 || (d.minimumPayment ?? 0) == 0) return s;
    return s + FinanceMath.simulateDebtPayoff(
      balance: d.currentBalance,
      annualInterestRate: d.interestRate,
      monthlyPayment: d.minimumPayment!,
    ).totalInterest;
  });

  double get _totalInterestWithExtra => _debts.fold(0.0, (s, d) {
    final double pay = (d.minimumPayment ?? 0) + _extraPayment;
    if (d.currentBalance <= 0 || pay == 0) return s;
    return s + FinanceMath.simulateDebtPayoff(
      balance: d.currentBalance,
      annualInterestRate: d.interestRate,
      monthlyPayment: pay,
    ).totalInterest;
  });

  Future<void> _showSheet({Debt? debt}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DebtSheet(debt: debt),
    );
    if (result == true) {
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  Future<void> _logPayment(Debt debt) async {
    final TextEditingController ctrl = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Current balance: ${_fmt.format(debt.currentBalance)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Payment amount',
                prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirm == true && ctrl.text.isNotEmpty) {
      final double payment = double.parse(ctrl.text);
      final double newBalance = (debt.currentBalance - payment).clamp(0.0, debt.originalAmount);
      await DBHelper().updateDebt(debt.copyWith(currentBalance: newBalance, updatedAt: DateTime.now()));
      ReloadNotifier.instance.notify();
      _load();
    }
    ctrl.dispose();
  }

  Future<void> _delete(Debt debt) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete debt?'),
        content: Text('Remove "${debt.name}" from your tracker?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper().deleteDebt(debt.id!);
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debt Tracker')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _debts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(Icons.credit_card_off_outlined, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No debts tracked', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Tap + to add a debt to track', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // ── Totals ───────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Text('Total Remaining Debt',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      Text(_fmt.format(_totalBalance),
                          style: const TextStyle(color: AppColors.negative, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text('of ${_fmt.format(_totalOriginal)} original',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      if (_totalMinPay > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Text('Min monthly payments: ${_fmt.format(_totalMinPay)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _totalOriginal > 0
                              ? ((_totalOriginal - _totalBalance) / _totalOriginal).clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: AppColors.divider,
                          color: AppColors.positive,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Strategy optimizer (only for interest-bearing debts) ─────
                if (_hasInterestDebts) _strategySection(),
                // ── Debt cards (sorted by strategy) ─────────────────────────
                ..._sortedDebts.map((debt) => _debtCard(debt, payoffResult: _resultFor(debt))),
              ],
            ),
    );
  }

  // ── Strategy section ─────────────────────────────────────────────────────

  Widget _strategySection() {
    final double saved = _totalInterestMinimums - _totalInterestWithExtra;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('PAYOFF STRATEGY',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            _strategyToggle('Avalanche', 'avalanche', Icons.local_fire_department_rounded),
            const SizedBox(width: 8),
            _strategyToggle('Snowball', 'snowball', Icons.ac_unit_rounded),
          ]),
          const SizedBox(height: 6),
          Text(
            _strategy == 'avalanche'
                ? 'Highest interest first — minimizes total interest paid'
                : 'Smallest balance first — faster early wins',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Extra monthly payment',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: _editExtraPayment,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+ ${_fmt.format(_extraPayment)}',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (saved > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.positive.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: <Widget>[
                const Icon(Icons.savings_rounded,
                    size: 14, color: AppColors.positive),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Save ${_fmt.format(saved)} in total interest vs. minimums only',
                    style: const TextStyle(
                        color: AppColors.positive, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _strategyToggle(String label, String value, IconData icon) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _strategy = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: _strategy == value ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _strategy == value
                      ? AppColors.accent
                      : AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon,
                    size: 14,
                    color: _strategy == value
                        ? Colors.white
                        : AppColors.textMuted),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        color: _strategy == value
                            ? Colors.white
                            : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  Future<void> _editExtraPayment() async {
    final TextEditingController ctrl =
        TextEditingController(text: _extraPayment > 0 ? _extraPayment.toStringAsFixed(0) : '');
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Extra Monthly Payment',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly
          ],
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Amount above minimums',
            prefix:
                Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _extraPayment =
          ctrl.text.isEmpty ? 0 : double.parse(ctrl.text));
    }
    ctrl.dispose();
  }

  // ── Debt card ─────────────────────────────────────────────────────────────

  Widget _debtCard(Debt debt, {DebtPayoffResult? payoffResult}) {
    final bool paid = debt.currentBalance <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: paid ? AppColors.positive.withOpacity(0.3) : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      if (paid) ...<Widget>[
                        const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.positive),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(debt.name,
                            style: TextStyle(
                              color: paid ? AppColors.positive : AppColors.textPrimary,
                              fontSize: 14, fontWeight: FontWeight.w600,
                            )),
                      ),
                    ]),
                    if (debt.interestRate > 0)
                      Text('${debt.interestRate.toStringAsFixed(1)}% interest',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (debt.dueDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Due day ${debt.dueDay}',
                      style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showSheet(debt: debt),
                child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _delete(debt),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: debt.progress,
              backgroundColor: AppColors.divider,
              color: paid ? AppColors.positive : AppColors.accent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('${(debt.progress * 100).toStringAsFixed(0)}% paid',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text(
                paid ? 'Paid off!' : _fmt.format(debt.currentBalance) + ' remaining',
                style: TextStyle(
                  color: paid ? AppColors.positive : AppColors.textSecondary,
                  fontSize: 12, fontWeight: paid ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
          if (debt.minimumPayment != null && !paid) ...<Widget>[
            const SizedBox(height: 4),
            Text('Min payment: ${_fmt.format(debt.minimumPayment!)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          if (payoffResult != null &&
              payoffResult.months > 0 &&
              debt.interestRate > 0 &&
              !paid) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(children: <Widget>[
                  const Icon(Icons.event_outlined, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Payoff ~${DateFormat('MMM yyyy').format(payoffResult.payoffDate)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ]),
                Text(
                  '${_fmt.format(payoffResult.totalInterest)} interest',
                  style: const TextStyle(color: AppColors.negative, fontSize: 11),
                ),
              ],
            ),
          ],
          if (!paid) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _logPayment(debt),
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: const Text('Log Payment'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Add / Edit bottom sheet ───────────────────────────────────────────────────

class _DebtSheet extends StatefulWidget {
  final Debt? debt;
  const _DebtSheet({this.debt});

  @override
  State<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<_DebtSheet> {
  final GlobalKey<FormState> _form       = GlobalKey<FormState>();
  final TextEditingController _nameCtrl    = TextEditingController();
  final TextEditingController _origCtrl    = TextEditingController();
  final TextEditingController _balCtrl     = TextEditingController();
  final TextEditingController _rateCtrl    = TextEditingController();
  final TextEditingController _minPayCtrl  = TextEditingController();
  final TextEditingController _dueDayCtrl  = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (d != null) {
      _nameCtrl.text   = d.name;
      _origCtrl.text   = d.originalAmount.toStringAsFixed(0);
      _balCtrl.text    = d.currentBalance.toStringAsFixed(0);
      _rateCtrl.text   = d.interestRate > 0 ? d.interestRate.toString() : '';
      _minPayCtrl.text = d.minimumPayment != null ? d.minimumPayment!.toStringAsFixed(0) : '';
      _dueDayCtrl.text = d.dueDay != null ? d.dueDay.toString() : '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _origCtrl.dispose(); _balCtrl.dispose();
    _rateCtrl.dispose(); _minPayCtrl.dispose(); _dueDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final debt = Debt(
      id:              widget.debt?.id,
      name:            _nameCtrl.text.trim(),
      originalAmount:  double.parse(_origCtrl.text),
      currentBalance:  double.parse(_balCtrl.text),
      interestRate:    _rateCtrl.text.isEmpty ? 0 : double.parse(_rateCtrl.text),
      minimumPayment:  _minPayCtrl.text.isEmpty ? null : double.parse(_minPayCtrl.text),
      dueDay:          _dueDayCtrl.text.isEmpty ? null : int.parse(_dueDayCtrl.text),
      createdAt:       widget.debt?.createdAt ?? now,
      updatedAt:       now,
    );
    if (widget.debt == null) {
      await DBHelper().insertDebt(debt);
    } else {
      await DBHelper().updateDebt(debt);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),
                Text(widget.debt == null ? 'Add Debt' : 'Edit Debt',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Debt name (e.g. KTA BCA)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _origCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Original amount',
                    prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _balCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Current balance',
                    prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final double? bal  = double.tryParse(v);
                    final double? orig = double.tryParse(_origCtrl.text);
                    if (bal == null) return 'Enter a valid amount';
                    if (orig != null && bal > orig) return 'Cannot exceed original amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Interest rate % (optional)',
                    suffixText: '%',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (double.tryParse(v) == null) return 'Enter a valid number (e.g. 12.5)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minPayCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Minimum payment (optional)',
                    prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dueDayCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Due day of month (optional, 1–31)'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final int? d = int.tryParse(v);
                    if (d == null || d < 1 || d > 31) return 'Enter 1–31';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.debt == null ? 'Add Debt' : 'Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
