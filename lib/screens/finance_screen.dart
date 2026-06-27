import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../helpers/finance_math.dart';
import '../models/debt.dart';
import '../models/envelope.dart';
import '../models/net_worth_item.dart';
import '../models/savings_goal.dart';
import '../services/category_registry.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/ring_painter.dart';
import 'debt_screen.dart';
import 'envelope_screen.dart';
import 'net_worth_screen.dart';
import 'savings_goal_screen.dart';

// ── Data holder ───────────────────────────────────────────────────────────────

class _MonthSummary {
  final int year;
  final int month;
  final double income;
  final double expenses;
  const _MonthSummary(this.year, this.month, this.income, this.expenses);
  double get savings => income - expenses;
  double get rate    => income > 0 ? (savings / income).clamp(-1.0, 1.0) : 0.0;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final NumberFormat _pct = NumberFormat('#,##0.0');

  bool _loading = true;

  // savings rate
  List<_MonthSummary> _history = <_MonthSummary>[];

  // 50/30/20
  Map<String, double> _catTotals = <String, double>{};
  double _thisMonthIncome        = 0;

  // net worth
  List<NetWorthItem> _netWorthItems = <NetWorthItem>[];

  // envelopes
  List<Envelope> _envelopes        = <Envelope>[];
  Map<String, double> _envSpent    = <String, double>{};

  // debts
  List<Debt> _debts = <Debt>[];

  // savings goals
  List<SavingsGoal> _goals = <SavingsGoal>[];

  // future-value projector settings
  double _projectorReturn = 7.0; // annual %
  int    _projectorYears  = 10;

  @override
  void initState() {
    super.initState();
    ReloadNotifier.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ReloadNotifier.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final db  = DBHelper();

    // Savings rate: last 6 months
    final List<Future<_MonthSummary>> futures = List<Future<_MonthSummary>>.generate(6, (i) async {
      final DateTime dt = DateTime(now.year, now.month - (5 - i), 1);
      final double inc = await db.getMonthlyIncomeTotal(dt.year, dt.month);
      final double exp = await db.getMonthlyExpenseTotal(dt.year, dt.month);
      return _MonthSummary(dt.year, dt.month, inc, exp);
    });
    final List<_MonthSummary> history = await Future.wait(futures);

    // 50/30/20
    final double thisIncome  = history.last.income;
    final Map<String, double> catTotals =
        await db.getExpenseCategoryTotals(now.year, now.month);

    // Net worth
    final List<NetWorthItem> nwItems = await db.getNetWorthItems();

    // Envelopes
    final List<Envelope> envelopes = await db.getEnvelopes();
    final Map<String, double> envSpent = <String, double>{};
    await Future.wait(envelopes.map((env) async {
      envSpent[env.category] =
          await db.getCategoryMonthlyTotal(now.year, now.month, env.category);
    }));

    // Debts
    final List<Debt> debts = await db.getDebts();

    // Savings goals
    final List<SavingsGoal> goals = await db.getGoals();

    if (mounted) {
      setState(() {
        _loading         = false;
        _history         = history;
        _thisMonthIncome = thisIncome;
        _catTotals       = catTotals;
        _netWorthItems   = nwItems;
        _envelopes       = envelopes;
        _envSpent        = envSpent;
        _debts           = debts;
        _goals           = goals;
      });
    }
  }

  // ── Derived getters ───────────────────────────────────────────────────────

  _MonthSummary get _current => _history.isNotEmpty ? _history.last : const _MonthSummary(0, 0, 0, 0);

  double get _totalAssets      => _netWorthItems.where((i) => i.isAsset).fold(0, (s, i) => s + i.value);
  double get _totalLiabilities => _netWorthItems.where((i) => !i.isAsset).fold(0, (s, i) => s + i.value);
  double get _netWorth         => _totalAssets - _totalLiabilities;

  double get _totalDebt => _debts.fold(0, (s, d) => s + d.currentBalance);

  // Average monthly savings from last 3 months that have income data
  double get _avgMonthlySavings {
    final List<_MonthSummary> recent = _history
        .where((m) => m.income > 0)
        .toList()
        .reversed
        .take(3)
        .toList();
    if (recent.isEmpty) return 0;
    return recent.fold(0.0, (s, m) => s + m.savings.clamp(0, double.infinity)) /
        recent.length;
  }

  Map<String, double> _buckets() {
    double needs = 0, wants = 0, savings = 0;
    for (final entry in _catTotals.entries) {
      final String bucket = CategoryRegistry().natureOf(entry.key);
      if (bucket == 'needs')   needs   += entry.value;
      if (bucket == 'wants')   wants   += entry.value;
      if (bucket == 'savings') savings += entry.value;
    }
    return <String, double>{'needs': needs, 'wants': wants, 'savings': savings};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  title: const Text('Finance'),
                  backgroundColor: AppColors.background,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(<Widget>[
                      _sectionLabel('THIS MONTH'),
                      const SizedBox(height: 10),
                      _savingsRateCard(),
                      const SizedBox(height: 12),
                      _projectorCard(),
                      const SizedBox(height: 12),
                      _fiftyThirtyTwentyCard(),
                      const SizedBox(height: 24),
                      _sectionLabel('PLANNING'),
                      const SizedBox(height: 10),
                      _savingsGoalsCard(),
                      const SizedBox(height: 12),
                      _netWorthCard(),
                      const SizedBox(height: 12),
                      _envelopesCard(),
                      const SizedBox(height: 12),
                      _debtCard(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Savings rate ──────────────────────────────────────────────────────────

  Widget _savingsRateCard() {
    final double rate    = _current.rate;
    final double savings = _current.savings;
    final bool positive  = savings >= 0;
    final Color rateColor = positive ? AppColors.positive : AppColors.negative;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Savings Rate', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rateColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(rate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: rateColor, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _current.income > 0
                ? '${_fmt.format(savings.abs())} ${positive ? "saved" : "over-spent"} from ${_fmt.format(_current.income)} income'
                : 'No income recorded this month',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          // 6-month bar chart — max bar area is 40px; label row is 12px
          SizedBox(
            height: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _history.asMap().entries.map((entry) {
                final int idx = entry.key;
                final _MonthSummary m = entry.value;
                final bool pos        = m.savings >= 0;
                final bool isCurrent  = idx == _history.length - 1;
                final bool hasData    = _history.any((h) => h.income > 0 || h.expenses > 0);
                final double barHeight = hasData
                    ? ((m.rate.abs() * 0.9 + 0.1).clamp(0.05, 1.0) * 38).roundToDouble()
                    : 6.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (pos ? AppColors.positive : AppColors.negative)
                                : (pos
                                    ? AppColors.positive.withOpacity(0.35)
                                    : AppColors.negative.withOpacity(0.35)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM').format(DateTime(m.year, m.month)),
                          style: TextStyle(
                            color: isCurrent ? AppColors.textSecondary : AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 50/30/20 ──────────────────────────────────────────────────────────────

  Widget _fiftyThirtyTwentyCard() {
    final Map<String, double> buckets = _buckets();
    final double totalExp  = buckets.values.fold(0, (s, v) => s + v);
    final double income    = _thisMonthIncome;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('50/30/20 Breakdown', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            income > 0 ? 'Based on ${_fmt.format(income)} income' : 'No income recorded',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _bucketRow('Needs',   buckets['needs']!,   income, const Color(0xFF60A5FA), 0.50),
          const SizedBox(height: 10),
          _bucketRow('Wants',   buckets['wants']!,   income, AppColors.warning,        0.30),
          const SizedBox(height: 10),
          _bucketRow('Savings', buckets['savings']!, income, AppColors.positive,       0.20),
          if (income > 0 && totalExp > 0) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('Total expenses', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text(_fmt.format(totalExp), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bucketRow(String label, double amount, double income, Color color, double target) {
    final double actual = income > 0 ? (amount / income).clamp(0.0, 2.0) : 0.0;
    final bool overTarget = actual > target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(children: <Widget>[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
            Row(children: <Widget>[
              Text(
                '${_pct.format(actual * 100)}%',
                style: TextStyle(
                  color: overTarget ? AppColors.warning : AppColors.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' / ${(target * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: <Widget>[
            Container(
              height: 6, decoration: BoxDecoration(
                color: AppColors.divider, borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: actual.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            FractionallySizedBox(
              widthFactor: target,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.textPrimary.withOpacity(0.5), width: 2)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(_fmt.format(amount), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  // ── Net worth ─────────────────────────────────────────────────────────────

  Widget _netWorthCard() {
    final bool positive = _netWorth >= 0;
    return _card(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetWorthScreen())),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Net Worth', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  _fmt.format(_netWorth),
                  style: TextStyle(
                    color: positive ? AppColors.positive : AppColors.negative,
                    fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _pillText('Assets ${_fmt.format(_totalAssets)}', AppColors.positive),
                    const SizedBox(width: 8),
                    _pillText('Debts ${_fmt.format(_totalLiabilities)}', AppColors.negative),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  // ── Envelopes ─────────────────────────────────────────────────────────────

  Widget _envelopesCard() {
    final double totalBudget = _envelopes.fold(0, (s, e) => s + e.monthlyBudget);
    final double totalSpent  = _envSpent.values.fold(0, (s, v) => s + v);

    return _card(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnvelopeScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Envelope Budgets', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
          if (_envelopes.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text('Tap to set up envelope budgets', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ] else ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${_fmt.format(totalSpent)} of ${_fmt.format(totalBudget)} spent',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...(_envelopes.take(3).map((env) {
              final double spent = _envSpent[env.category] ?? 0;
              final double ratio = env.monthlyBudget > 0
                  ? (spent / env.monthlyBudget).clamp(0.0, 1.0)
                  : 0.0;
              final bool over = spent > env.monthlyBudget;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(env.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(
                          over ? 'Over budget' : '${_fmt.format(env.monthlyBudget - spent)} left',
                          style: TextStyle(color: over ? AppColors.negative : AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: AppColors.divider,
                        color: over ? AppColors.negative : ratio > 0.8 ? AppColors.warning : AppColors.positive,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              );
            })),
            if (_envelopes.length > 3)
              Text('+${_envelopes.length - 3} more',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  // ── Debt tracker ──────────────────────────────────────────────────────────

  Widget _debtCard() {
    return _card(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Debt Tracker', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
          if (_debts.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text('Tap to track your debts', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ] else ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${_fmt.format(_totalDebt)} remaining across ${_debts.length} debt${_debts.length == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...(_debts.take(3).map((debt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(debt.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('${(debt.progress * 100).toStringAsFixed(0)}% paid',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: debt.progress,
                        backgroundColor: AppColors.divider,
                        color: debt.progress >= 1.0 ? AppColors.positive : AppColors.accent,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              );
            })),
            if (_debts.length > 3)
              Text('+${_debts.length - 3} more',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  // ── Savings Goals card ────────────────────────────────────────────────────

  Widget _savingsGoalsCard() {
    return _card(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SavingsGoalScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const <Widget>[
              Text('Savings Goals',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
          if (_goals.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text('Tap to set saving targets',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: _goals.take(4).map((g) {
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CustomPaint(
                          painter: RingPainter(
                            progress: g.progress,
                            color: g.isComplete ? AppColors.positive : g.color,
                            strokeWidth: 5,
                          ),
                          child: Center(
                            child: Text(
                              '${(g.progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 52,
                        child: Text(g.name,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (_goals.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${_goals.length - 4} more',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }

  // ── Future-Value Projector card ───────────────────────────────────────────

  Widget _projectorCard() {
    final double pmt = _avgMonthlySavings;
    final double r   = _projectorReturn / 100;

    Widget body;
    if (pmt <= 0) {
      body = const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Add income records to see future-value projections.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    } else {
      final List<double> points =
          FinanceMath.projectionPoints(pmt, r, 30);
      final double fv10 = FinanceMath.futureValueAnnuity(pmt, r, 10);
      final double fv20 = FinanceMath.futureValueAnnuity(pmt, r, 20);
      final double fv30 = FinanceMath.futureValueAnnuity(pmt, r, 30);

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Based on avg ${_fmt.format(pmt)}/mo savings (last 3 months)',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // Year toggles
          Row(
            children: <int>[10, 20, 30].map((y) {
              final bool selected = _projectorYears == y;
              return GestureDetector(
                onTap: () => setState(() => _projectorYears = y),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? AppColors.accent
                            : AppColors.divider),
                  ),
                  child: Text('${y}yr',
                      style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Curve chart
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: _FVCurvePainter(
                points: points,
                highlightYears: _projectorYears,
              ),
              size: const Size(double.infinity, 90),
            ),
          ),
          const SizedBox(height: 12),
          // Milestone row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _milestone('10 yr', fv10),
              _milestone('20 yr', fv20),
              _milestone('30 yr', fv30),
            ],
          ),
        ],
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Future-Value Projector',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              // Tappable return-rate pill
              GestureDetector(
                onTap: _editProjectorReturn,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_projectorReturn.toStringAsFixed(1)}%/yr ▾',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          body,
        ],
      ),
    );
  }

  Future<void> _editProjectorReturn() async {
    double temp = _projectorReturn;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Annual Return Rate',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${temp.toStringAsFixed(1)}% / year',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              Slider(
                value: temp,
                min: 1,
                max: 20,
                divisions: 190,
                activeColor: AppColors.accent,
                onChanged: (v) => setLocal(() => temp = v),
              ),
              const Text('Adjust to match expected investment return',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                setState(() => _projectorReturn = temp);
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _milestone(String label, double value) => Column(
        children: <Widget>[
          Text(label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(_fmt.format(value),
              style: const TextStyle(
                  color: AppColors.positive,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required Widget child, VoidCallback? onTap}) => Container(
    margin: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          )
        : Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          color: AppColors.textMuted, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 0.8));

  Widget _pillText(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
  );
}

// ── Future-value curve painter ────────────────────────────────────────────────

class _FVCurvePainter extends CustomPainter {
  final List<double> points;   // index 0..30 (year 0 = 0)
  final int highlightYears;    // which year to mark with a dot

  const _FVCurvePainter({required this.points, required this.highlightYears});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final double maxVal = points.last > 0 ? points.last : 1;
    final int n = points.length - 1;

    double xOf(int i) => i / n * size.width;
    double yOf(double v) => size.height - (v / maxVal) * size.height;

    // Fill path (gradient)
    final Path fillPath = Path();
    fillPath.moveTo(xOf(0), size.height);
    for (int i = 0; i <= n; i++) {
      fillPath.lineTo(xOf(i), yOf(points[i]));
    }
    fillPath.lineTo(xOf(n), size.height);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          AppColors.accent.withOpacity(0.25),
          AppColors.accent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke path
    final Path strokePath = Path();
    strokePath.moveTo(xOf(0), yOf(points[0]));
    for (int i = 1; i <= n; i++) {
      strokePath.lineTo(xOf(i), yOf(points[i]));
    }
    canvas.drawPath(
      strokePath,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // Highlight dot at the selected year
    if (highlightYears <= n) {
      final double hx = xOf(highlightYears);
      final double hy = yOf(points[highlightYears]);
      canvas.drawCircle(
        Offset(hx, hy),
        4,
        Paint()..color = AppColors.accent,
      );
      canvas.drawCircle(
        Offset(hx, hy),
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FVCurvePainter old) =>
      old.highlightYears != highlightYears || !listEquals(old.points, points);
}
