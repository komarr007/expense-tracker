import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/savings_goal.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/ring_painter.dart';

class SavingsGoalScreen extends StatefulWidget {
  const SavingsGoalScreen({super.key});

  @override
  State<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends State<SavingsGoalScreen> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  List<SavingsGoal> _goals = <SavingsGoal>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<SavingsGoal> goals = await DBHelper().getGoals();
    if (mounted) setState(() => _goals = goals);
  }

  double get _totalTarget  => _goals.fold(0, (s, g) => s + g.targetAmount);
  double get _totalCurrent => _goals.fold(0, (s, g) => s + g.currentAmount);

  Future<void> _showSheet({SavingsGoal? goal}) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(goal: goal),
    );
    if (result == true) {
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  Future<void> _addFunds(SavingsGoal goal) async {
    final TextEditingController ctrl = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Add to "${goal.name}"',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Amount to add',
            prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirm == true && ctrl.text.isNotEmpty) {
      final double amount = double.parse(ctrl.text);
      final double newAmount =
          (goal.currentAmount + amount).clamp(0, goal.targetAmount);
      await DBHelper().updateGoal(goal.copyWith(currentAmount: newAmount));
      ReloadNotifier.instance.notify();
      _load();
    }
    ctrl.dispose();
  }

  Future<void> _delete(SavingsGoal goal) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete goal?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Remove "${goal.name}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper().deleteGoal(goal.id!);
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _goals.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(Icons.savings_outlined, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No goals yet',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Tap + to set your first saving target',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // ── Summary card ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Text('OVERALL PROGRESS',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                              child: _summaryCol(
                                  'Saved', _totalCurrent, AppColors.positive)),
                          Container(width: 1, height: 36, color: AppColors.divider),
                          Expanded(
                              child: _summaryCol(
                                  'Target', _totalTarget, AppColors.accent)),
                          Container(width: 1, height: 36, color: AppColors.divider),
                          Expanded(
                              child: _summaryCol(
                                  'Remaining',
                                  math.max(0, _totalTarget - _totalCurrent),
                                  AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _totalTarget > 0
                              ? (_totalCurrent / _totalTarget).clamp(0.0, 1.0)
                              : 0,
                          backgroundColor: AppColors.divider,
                          color: AppColors.positive,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Goal cards ───────────────────────────────────────────────
                ..._goals.map(_goalCard),
              ],
            ),
    );
  }

  Widget _goalCard(SavingsGoal goal) {
    final bool complete = goal.isComplete;
    final String? deadlineStr = goal.deadline != null
        ? DateFormat('d MMM yyyy').format(goal.deadline!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: complete
                ? AppColors.positive.withOpacity(0.4)
                : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row
          Row(
            children: <Widget>[
              if (complete)
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.positive),
              if (complete) const SizedBox(width: 6),
              Expanded(
                child: Text(goal.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () => _showSheet(goal: goal),
                child: const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.textMuted),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _delete(goal),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ring + details
          Row(
            children: <Widget>[
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: RingPainter(
                    progress: goal.progress,
                    color: complete ? AppColors.positive : goal.color,
                    strokeWidth: 7,
                  ),
                  child: Center(
                    child: Text(
                      '${(goal.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_fmt.format(goal.currentAmount),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text('of ${_fmt.format(goal.targetAmount)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    if (deadlineStr != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(children: <Widget>[
                        const Icon(Icons.event_rounded,
                            size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('By $deadlineStr',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ]),
                    ],
                    if (complete) ...<Widget>[
                      const SizedBox(height: 4),
                      const Text('Goal reached! 🎉',
                          style: TextStyle(
                              color: AppColors.positive,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!complete) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addFunds(goal),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Funds'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: goal.color,
                  side: BorderSide(color: goal.color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryCol(String label, double value, Color color) => Column(
        children: <Widget>[
          Text(label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(_fmt.format(value),
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

// ── Add / Edit sheet ──────────────────────────────────────────────────────────

class _GoalSheet extends StatefulWidget {
  final SavingsGoal? goal;
  const _GoalSheet({this.goal});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  static const List<String> _presetColors = <String>[
    'FF6C63FF', // accent purple
    'FF4ADE80', // positive green
    'FFFBBF24', // amber
    'FFFC8181', // red
    'FF60A5FA', // blue
    'FFF472B6', // pink
  ];

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _nameCtrl    = TextEditingController();
  final TextEditingController _targetCtrl  = TextEditingController();
  final TextEditingController _currentCtrl = TextEditingController();
  late String _selectedColor;
  DateTime? _deadline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final SavingsGoal? g = widget.goal;
    if (g != null) {
      _nameCtrl.text    = g.name;
      _targetCtrl.text  = g.targetAmount.toStringAsFixed(0);
      _currentCtrl.text = g.currentAmount.toStringAsFixed(0);
      _selectedColor    = g.colorHex;
      _deadline         = g.deadline;
    } else {
      _selectedColor = _presetColors.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final SavingsGoal goal = SavingsGoal(
      id: widget.goal?.id,
      name: _nameCtrl.text.trim(),
      targetAmount: double.parse(_targetCtrl.text.replaceAll(',', '')),
      currentAmount: double.parse(_currentCtrl.text.isEmpty ? '0' : _currentCtrl.text.replaceAll(',', '')),
      deadline: _deadline,
      colorHex: _selectedColor,
      createdAt: widget.goal?.createdAt ?? DateTime.now(),
    );
    if (widget.goal == null) {
      await DBHelper().insertGoal(goal);
    } else {
      await DBHelper().updateGoal(goal);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.goal == null ? 'New Goal' : 'Edit Goal',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration:
                      const InputDecoration(hintText: 'Goal name (e.g. Bali Trip)'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Target amount
                TextFormField(
                  controller: _targetCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Target amount',
                    prefix: Text('Rp  ',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if ((double.tryParse(v) ?? 0) <= 0)
                      return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Current/starting amount
                TextFormField(
                  controller: _currentCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Already saved (optional)',
                    prefix: Text('Rp  ',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 12),
                // Deadline
                GestureDetector(
                  onTap: _pickDeadline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.event_rounded,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _deadline != null
                                ? 'By ${DateFormat('d MMM yyyy').format(_deadline!)}'
                                : 'Set deadline (optional)',
                            style: TextStyle(
                              color: _deadline != null
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_deadline != null)
                          GestureDetector(
                            onTap: () => setState(() => _deadline = null),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Color picker
                const Text('Color',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: _presetColors.map((hex) {
                    final Color col = Color(int.parse(hex, radix: 16));
                    final bool selected = _selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: AppColors.textPrimary, width: 2.5)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(widget.goal == null ? 'Add Goal' : 'Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
