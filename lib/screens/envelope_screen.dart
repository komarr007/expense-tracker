import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/envelope.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';

class EnvelopeScreen extends StatefulWidget {
  const EnvelopeScreen({super.key});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  List<Envelope> _envelopes = <Envelope>[];
  Map<String, double> _spent = <String, double>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final List<Envelope> envs = await DBHelper().getEnvelopes();
    final Map<String, double> spent = <String, double>{};
    for (final env in envs) {
      spent[env.category] =
          await DBHelper().getCategoryMonthlyTotal(now.year, now.month, env.category);
    }
    if (mounted) setState(() { _envelopes = envs; _spent = spent; });
  }

  double get _totalBudget => _envelopes.fold(0, (s, e) => s + e.monthlyBudget);
  double get _totalSpent  => _spent.values.fold(0, (s, v) => s + v);

  Future<void> _showSheet({Envelope? envelope}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EnvelopeSheet(envelope: envelope),
    );
    if (result == true) {
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  Future<void> _delete(Envelope env) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete envelope?'),
        content: Text('Remove the "${env.name}" envelope?'),
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
      await DBHelper().deleteEnvelope(env.id!);
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String monthLabel = DateFormat('MMMM yyyy').format(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Envelope Budgets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _envelopes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(Icons.mail_outline_rounded, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No envelopes yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Tap + to allocate your first budget', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // ── Month summary ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(monthLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.4)),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(child: _summaryCol('Total Budget', _totalBudget, AppColors.accent)),
                          Container(width: 1, height: 36, color: AppColors.divider),
                          Expanded(child: _summaryCol('Spent', _totalSpent, AppColors.negative)),
                          Container(width: 1, height: 36, color: AppColors.divider),
                          Expanded(child: _summaryCol('Remaining', _totalBudget - _totalSpent,
                              (_totalBudget - _totalSpent) >= 0 ? AppColors.positive : AppColors.negative)),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Envelope cards ───────────────────────────────────────────
                ..._envelopes.map((env) {
                  final double spent   = _spent[env.category] ?? 0;
                  final double remain  = env.monthlyBudget - spent;
                  final double ratio   = env.monthlyBudget > 0
                      ? (spent / env.monthlyBudget).clamp(0.0, 1.0)
                      : 0.0;
                  final bool   over    = spent > env.monthlyBudget;
                  final Color  barColor = over ? AppColors.negative
                      : ratio > 0.8 ? AppColors.warning
                      : AppColors.positive;
                  final Color  catColor = AppColors.category(env.category);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(env.name,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                            GestureDetector(
                              onTap: () => _showSheet(envelope: env),
                              child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _delete(env),
                              child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: AppColors.divider,
                            color: barColor,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(_fmt.format(spent),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            Text(
                              over ? '${_fmt.format(spent - env.monthlyBudget)} over' : '${_fmt.format(remain)} left',
                              style: TextStyle(
                                color: over ? AppColors.negative : AppColors.textMuted,
                                fontSize: 12, fontWeight: over ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            Text(_fmt.format(env.monthlyBudget),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _summaryCol(String label, double value, Color color) => Column(
    children: <Widget>[
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 4),
      Text(_fmt.format(value),
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ],
  );
}

// ── Add / Edit bottom sheet ───────────────────────────────────────────────────

class _EnvelopeSheet extends StatefulWidget {
  final Envelope? envelope;
  const _EnvelopeSheet({this.envelope});

  @override
  State<_EnvelopeSheet> createState() => _EnvelopeSheetState();
}

class _EnvelopeSheetState extends State<_EnvelopeSheet> {
  final GlobalKey<FormState> _form   = GlobalKey<FormState>();
  final TextEditingController _nameCtrl   = TextEditingController();
  final TextEditingController _budgetCtrl = TextEditingController();
  late String _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final env = widget.envelope;
    if (env != null) {
      _nameCtrl.text   = env.name;
      _budgetCtrl.text = env.monthlyBudget.toStringAsFixed(0);
      _category        = env.category;
    } else {
      _category = AppCategories.expense.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final env = Envelope(
      id:            widget.envelope?.id,
      name:          _nameCtrl.text.trim(),
      category:      _category,
      monthlyBudget: double.parse(_budgetCtrl.text.replaceAll(',', '')),
      createdAt:     widget.envelope?.createdAt ?? DateTime.now(),
    );
    if (widget.envelope == null) {
      await DBHelper().insertEnvelope(env);
    } else {
      await DBHelper().updateEnvelope(env);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              Text(widget.envelope == null ? 'New Envelope' : 'Edit Envelope',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Envelope name (e.g. Food)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(hintText: 'Category'),
                items: AppCategories.expense.map((c) {
                  final Color col = AppColors.category(c);
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Row(children: <Widget>[
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(c),
                    ]),
                  );
                }).toList(),
                onChanged: (v) { if (v != null) setState(() => _category = v); },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Monthly budget',
                  prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.envelope == null ? 'Add Envelope' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
