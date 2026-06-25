import 'dart:convert';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/income_record.dart';
import '../models/financial_score.dart';
import '../models/recurring_expense.dart';
import '../helpers/db_helper.dart';
import '../theme/app_theme.dart';
import 'package:logger/logger.dart';

// ── Private data model ────────────────────────────────────────────────────────

class _TrendMonth {
  final String label;
  final double expenses;
  final double income;
  final Map<String, double> catTotals;
  final int score;
  final Color scoreColor;
  const _TrendMonth({
    required this.label,
    required this.expenses,
    required this.income,
    required this.catTotals,
    required this.score,
    required this.scoreColor,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Raw data ───────────────────────────────────────────────────────────────
  List<Expense>      _expenses = <Expense>[];
  List<IncomeRecord> _income   = <IncomeRecord>[];
  String _selectedMonth        = '';
  List<String> _months         = <String>[];

  // ── Per-selected-month ─────────────────────────────────────────────────────
  double _monthlyTotal   = 0;
  double _prevMonthTotal = 0;
  double _monthlyIncome  = 0;
  double _avgDaily       = 0;
  double _projected      = 0;
  double _savingsTotal   = 0;
  double _budget         = 0;
  Map<String, double> _catBudgets = <String, double>{};
  Expense? _biggest;
  Map<String, double> _catTotals  = <String, double>{};
  double _fixedSpend               = 0;
  double _varSpend                 = 0;

  // ── All-time computed ──────────────────────────────────────────────────────
  List<_TrendMonth> _history   = <_TrendMonth>[];
  List<String>      _topCats   = <String>[];
  Map<int, double>  _payDayAvg = <int, double>{};
  List<MapEntry<String, double>> _topPayees = <MapEntry<String, double>>[];
  Set<String>       _fixedCats = <String>{};

  final Logger       _log = Logger();
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    try {
      final List<Expense>           expenses  = await DBHelper().getExpenses();
      final List<IncomeRecord>      income    = await DBHelper().getIncomeRecords();
      final List<RecurringExpense>  recurring = await DBHelper().getRecurringExpenses();
      final SharedPreferences       prefs     = await SharedPreferences.getInstance();

      final double budget   = prefs.getDouble('monthly_budget') ?? 0;
      final String? rawCat  = prefs.getString('category_budgets');
      final Map<String, double> catBudgets = rawCat != null
          ? Map<String, double>.from(
              (jsonDecode(rawCat) as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, (v as num).toDouble())))
          : <String, double>{};

      final List<String> months = expenses
          .map((e) => DateFormat('MMMM yyyy').format(e.spend_date))
          .toSet()
          .toList();

      // ── Fixed categories (from recurring templates) ──────────────────────
      final Set<String> fixedCats = recurring.map((r) => r.category).toSet();

      // ── History: last 12 months ──────────────────────────────────────────
      final DateTime now        = DateTime.now();
      final List<_TrendMonth> history = <_TrendMonth>[];
      double? prevExp;
      for (int m = 11; m >= 0; m--) {
        final DateTime d       = DateTime(now.year, now.month - m);
        final String monthFull = DateFormat('MMMM yyyy').format(d);
        final String monthShort = DateFormat('MMM yy').format(d);

        final Iterable<Expense>      mExp = expenses.where((e) => DateFormat('MMMM yyyy').format(e.spend_date) == monthFull);
        final Iterable<IncomeRecord> mInc = income.where((r)  => DateFormat('MMMM yyyy').format(r.income_date) == monthFull);

        final double mExpTotal = mExp.fold(0.0, (s, e) => s + e.amount);
        final double mIncTotal = mInc.fold(0.0, (s, r) => s + r.amount);

        if (mExpTotal > 0 || mIncTotal > 0) {
          final Map<String, double> mCats = <String, double>{};
          for (final e in mExp) {
            mCats.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
          }
          final FinancialScore score = FinancialScore.compute(
            monthExpenses: mExpTotal, monthIncome: mIncTotal,
            prevMonthExpenses: prevExp ?? 0, budget: budget,
          );
          history.add(_TrendMonth(
            label: monthShort, expenses: mExpTotal, income: mIncTotal,
            catTotals: mCats, score: score.total, scoreColor: score.color,
          ));
        }
        prevExp = mExpTotal;
      }

      // ── Top 5 categories all-time ────────────────────────────────────────
      final Map<String, double> allCats = <String, double>{};
      for (final e in expenses) {
        allCats.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
      }
      final List<String> topCats = (allCats.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key)
          .toList();

      // ── Payday pattern (avg spending per day-of-month) ───────────────────
      final Map<int, double>      dayTotals  = <int, double>{};
      final Map<int, Set<String>> dayMonths  = <int, Set<String>>{};
      for (final e in expenses) {
        final int    day   = e.spend_date.day;
        final String mKey  = DateFormat('MMMM yyyy').format(e.spend_date);
        dayTotals.update(day, (v) => v + e.amount, ifAbsent: () => e.amount);
        dayMonths.putIfAbsent(day, () => <String>{}).add(mKey);
      }
      final Map<int, double> payDayAvg = <int, double>{};
      for (final entry in dayTotals.entries) {
        payDayAvg[entry.key] = entry.value / (dayMonths[entry.key]?.length ?? 1);
      }

      // ── Top payees all-time ──────────────────────────────────────────────
      final Map<String, double> payeeTotals = <String, double>{};
      for (final e in expenses) {
        final String n = e.name.trim();
        payeeTotals.update(n, (v) => v + e.amount, ifAbsent: () => e.amount);
      }
      final List<MapEntry<String, double>> topPayees =
          (payeeTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .take(10)
              .toList();

      setState(() {
        _expenses   = expenses;
        _income     = income;
        _budget     = budget;
        _catBudgets = catBudgets;
        _months     = months;
        _history    = history;
        _topCats    = topCats;
        _payDayAvg  = payDayAvg;
        _topPayees  = topPayees;
        _fixedCats  = fixedCats;
        _selectedMonth = months.isNotEmpty ? months.first : '';
        _apply(_selectedMonth);
      });
    } catch (e, st) {
      _log.e('dashboard fetch', error: e, stackTrace: st);
    }
  }

  void _apply(String month) {
    if (month.isEmpty) return;
    final fmt  = DateFormat('MMMM yyyy');
    final sel  = fmt.parse(month);
    final prev = fmt.format(DateTime(sel.year, sel.month - 1));

    final List<Expense>      cur    = _expenses.where((e) => DateFormat('MMMM yyyy').format(e.spend_date) == month).toList();
    final List<Expense>      prv    = _expenses.where((e) => DateFormat('MMMM yyyy').format(e.spend_date) == prev).toList();
    final List<IncomeRecord> incCur = _income.where((r) => DateFormat('MMMM yyyy').format(r.income_date) == month).toList();

    final double mTotal = cur.fold(0, (s, e) => s + e.amount);
    final double pTotal = prv.fold(0, (s, e) => s + e.amount);
    final double mInc   = incCur.fold(0, (s, r) => s + r.amount);

    final DateTime now = DateTime.now();
    final bool isCur   = sel.year == now.year && sel.month == now.month;
    final int elapsed  = isCur ? now.day : _daysInMonth(sel.year, sel.month);

    final Map<String, double> cats = <String, double>{};
    for (final e in cur) cats.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);

    double fixed = 0, variable = 0;
    for (final entry in cats.entries) {
      if (_fixedCats.contains(entry.key)) { fixed += entry.value; } else { variable += entry.value; }
    }

    _monthlyTotal   = mTotal;
    _prevMonthTotal = pTotal;
    _monthlyIncome  = mInc;
    _savingsTotal   = cur.where((e) => e.category.toLowerCase() == 'savings').fold(0, (s, e) => s + e.amount);
    _biggest        = cur.isEmpty ? null : cur.reduce((a, b) => a.amount > b.amount ? a : b);
    _avgDaily       = elapsed > 0 ? mTotal / elapsed : 0;
    _projected      = isCur ? _avgDaily * _daysInMonth(sel.year, sel.month) : mTotal;
    _catTotals      = cats;
    _fixedSpend     = fixed;
    _varSpend       = variable;
  }

  int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
          const SizedBox(width: 4),
        ],
      ),
      body: _expenses.isEmpty
          ? _empty()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _monthPicker(),
                  const SizedBox(height: 16),
                  _heroCard(),
                  const SizedBox(height: 12),
                  _statsGrid(),
                  if (_budget > 0) ...<Widget>[
                    const SizedBox(height: 12),
                    _budgetCard(),
                  ],
                  if (_monthlyIncome > 0) ...<Widget>[
                    const SizedBox(height: 12),
                    _cashflowCard(),
                  ],

                  // ── Monthly breakdown ──────────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('Spending by Category'),
                  const SizedBox(height: 8),
                  _categoryCard(),
                  if (_catBudgets.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    _sectionLabel('Category Limits'),
                    const SizedBox(height: 8),
                    _categoryBudgetsCard(),
                  ],

                  // ── Fixed vs Variable ──────────────────────────
                  if (_monthlyTotal > 0) ...<Widget>[
                    const SizedBox(height: 20),
                    _sectionLabel('Fixed vs Variable'),
                    const SizedBox(height: 8),
                    _fixedVarCard(),
                  ],

                  // ── Monthly trend bar chart ────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('Monthly Trend'),
                  const SizedBox(height: 8),
                  _barChart(),

                  // ── Category trends (line chart) ───────────────
                  if (_history.length >= 2) ...<Widget>[
                    const SizedBox(height: 20),
                    _sectionLabel('Category Trends'),
                    const SizedBox(height: 8),
                    _catTrendChart(),
                  ],

                  // ── Health score history ───────────────────────
                  if (_history.length >= 2) ...<Widget>[
                    const SizedBox(height: 20),
                    _sectionLabel('Health Score History'),
                    const SizedBox(height: 8),
                    _scoreHistoryChart(),
                  ],

                  // ── Payday effect ──────────────────────────────
                  if (_payDayAvg.length >= 5) ...<Widget>[
                    const SizedBox(height: 20),
                    _sectionLabel('Spending by Day of Month'),
                    const SizedBox(height: 8),
                    _payDayChart(),
                  ],

                  // ── Top payees ─────────────────────────────────
                  if (_topPayees.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    _sectionLabel('Top Payees / Merchants'),
                    const SizedBox(height: 8),
                    _topPayeesCard(),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Existing widgets ──────────────────────────────────────────────────────

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Icon(Icons.bar_chart_rounded, size: 72, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('No data yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      const SizedBox(height: 6),
      const Text('Add some expenses to see analytics', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    ]),
  );

  Widget _monthPicker() {
    if (_months.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMonth,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
          dropdownColor: AppColors.card,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          items: _months.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
          onChanged: (v) { if (v == null) return; setState(() { _selectedMonth = v; _apply(v); }); },
        ),
      ),
    );
  }

  Widget _heroCard() {
    final double diff  = _monthlyTotal - _prevMonthTotal;
    final bool isUp    = diff > 0;
    final double pct   = _prevMonthTotal > 0 ? (diff / _prevMonthTotal) * 100 : 0.0;
    final String sign  = isUp ? '+' : '';
    final Color tColor = isUp ? AppColors.negative : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFF1E1B4B), Color(0xFF2D2369)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3730A3).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(_selectedMonth, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              if (_prevMonthTotal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: tColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: tColor, size: 14),
                    const SizedBox(width: 3),
                    Text('$sign${pct.toStringAsFixed(1)}%', style: TextStyle(color: tColor, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_fmt.format(_monthlyTotal),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 6),
          Text(
            _prevMonthTotal > 0 ? '$sign${_fmt.format(diff)} vs last month' : 'No data from last month',
            style: TextStyle(color: tColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7,
    children: <Widget>[
      _stat('Daily Average',   _fmt.format(_avgDaily),   Icons.today_rounded,          const Color(0xFF2DD4BF)),
      _stat('Month Forecast',  _fmt.format(_projected),  Icons.timeline_rounded,       const Color(0xFF60A5FA)),
      _stat('Total Savings',   _fmt.format(_savingsTotal), Icons.savings_rounded,      AppColors.positive),
      _stat('Biggest Expense', _biggest != null ? _fmt.format(_biggest!.amount) : '—',
          Icons.arrow_upward_rounded, AppColors.warning, sub: _biggest?.name),
    ],
  );

  Widget _stat(String label, String value, IconData icon, Color accent, {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(children: <Widget>[
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: accent, size: 14)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null)
              Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ],
      ),
    );
  }

  Widget _budgetCard() {
    final double remaining = _budget - _monthlyTotal;
    final double progress  = (_monthlyTotal / _budget).clamp(0.0, 1.0);
    final bool isOver      = _monthlyTotal > _budget;
    final Color barColor   = isOver ? AppColors.negative : progress > 0.8 ? AppColors.warning : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
          Row(children: <Widget>[Icon(Icons.account_balance_wallet_rounded, color: barColor, size: 16), const SizedBox(width: 6),
              const Text('Monthly Budget', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          Text('${(progress * 100).toStringAsFixed(0)}% used', style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 8,
            backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(barColor))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
          Text(isOver ? 'Over by ${_fmt.format(-remaining)}' : '${_fmt.format(remaining)} remaining',
              style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w600)),
          Text('Budget: ${_fmt.format(_budget)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _cashflowCard() {
    final double net = _monthlyIncome - _monthlyTotal;
    final bool isPos = net >= 0;
    final Color col  = isPos ? AppColors.positive : AppColors.negative;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: col.withOpacity(0.3))),
      child: Row(children: <Widget>[
        Expanded(child: _cfItem('Income', _monthlyIncome, AppColors.positive)),
        Container(width: 1, height: 36, color: AppColors.divider),
        Expanded(child: _cfItem('Expenses', _monthlyTotal, AppColors.negative)),
        Container(width: 1, height: 36, color: AppColors.divider),
        Expanded(child: Column(children: <Widget>[
          const Text('Net', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 3),
          Text('${isPos ? '+' : ''}${_fmt.format(net)}',
              style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _cfItem(String label, double amount, Color color) => Column(children: <Widget>[
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    const SizedBox(height: 3),
    Text(_fmt.format(amount), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        maxLines: 1, overflow: TextOverflow.ellipsis),
  ]);

  Widget _categoryCard() {
    if (_catTotals.isEmpty) {
      return Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
          child: const Center(child: Text('No spending data', style: TextStyle(color: AppColors.textMuted))));
    }
    final sorted = _catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(children: sorted.map((entry) {
        final double pct  = _monthlyTotal > 0 ? entry.value / _monthlyTotal : 0.0;
        final Color color = AppColors.category(entry.key);
        return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(children: <Widget>[
          Row(children: <Widget>[
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(entry.key, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
            Text('${(pct * 100).toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 10),
            Text(_fmt.format(entry.value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 4,
              backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(color))),
        ]));
      }).toList()),
    );
  }

  Widget _categoryBudgetsCard() {
    final List<String> categories = _catBudgets.keys.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(children: categories.asMap().entries.map((entry) {
        final String cat   = entry.value;
        final double limit = _catBudgets[cat] ?? 0;
        final double spent = _catTotals[cat] ?? 0;
        final double pct   = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0;
        final bool isOver  = spent > limit;
        final Color col    = isOver ? AppColors.negative : pct > 0.8 ? AppColors.warning : AppColors.positive;
        final Color catCol = AppColors.category(cat);
        final bool isLast  = entry.key == categories.length - 1;
        return Column(children: <Widget>[
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: <Widget>[
            Row(children: <Widget>[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: catCol, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(cat, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
              Text(isOver ? 'OVER' : '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${_fmt.format(spent)} / ${_fmt.format(limit)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 4,
                backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(col))),
          ])),
          if (!isLast) const Divider(height: 1),
        ]);
      }).toList()),
    );
  }

  Widget _barChart() {
    final Map<String, double> monthly = <String, double>{};
    for (final e in _expenses) {
      final String key = DateFormat('MMM yy').format(e.spend_date);
      monthly.update(key, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    if (monthly.isEmpty) return const SizedBox.shrink();
    final keys   = monthly.keys.toList();
    final maxVal = monthly.values.reduce((a, b) => a > b ? a : b);
    final bars   = keys.asMap().entries.map((entry) => BarChartGroupData(
      x: entry.key,
      barRods: <BarChartRodData>[BarChartRodData(
        toY: monthly[entry.value]!, width: 22,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        gradient: const LinearGradient(colors: <Color>[Color(0xFF4D46CC), Color(0xFF6C63FF)],
            begin: Alignment.bottomCenter, end: Alignment.topCenter),
      )],
    )).toList();
    return Container(
      height: 220, padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: (keys.length * 52.0).clamp(300.0, double.infinity),
          child: BarChart(BarChartData(
            barGroups: bars, maxY: maxVal * 1.25,
            gridData: FlGridData(drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(_short(v), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                  getTitlesWidget: (v, _) {
                    final int i = v.toInt();
                    if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 6),
                        child: Text(keys[i], style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)));
                  })),
            ),
            barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.cardLight,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${keys[group.x]}\n${_fmt.format(rod.toY)}',
                  const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
            )),
          )),
        ),
      ),
    );
  }

  // ── New: Category Trend Lines ──────────────────────────────────────────────

  Widget _catTrendChart() {
    if (_topCats.isEmpty || _history.length < 2) return const SizedBox.shrink();

    final List<_TrendMonth> months = _history.length > 6
        ? _history.sublist(_history.length - 6) : _history;

    double maxY = 0;
    final List<LineChartBarData> lines = _topCats.map((cat) {
      final List<FlSpot> spots = months.asMap().entries.map((e) {
        final double v = e.value.catTotals[cat] ?? 0;
        if (v > maxY) maxY = v;
        return FlSpot(e.key.toDouble(), v);
      }).toList();
      final Color col = AppColors.category(cat);
      return LineChartBarData(
        spots: spots, color: col, isCurved: true, barWidth: 2.5,
        dotData: FlDotData(show: spots.length <= 4),
        belowBarData: BarAreaData(show: true, color: col.withOpacity(0.06)),
      );
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Container(
        height: 200, padding: const EdgeInsets.fromLTRB(4, 12, 8, 8),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: LineChart(LineChartData(
          lineBarsData: lines,
          minY: 0, maxY: maxY > 0 ? maxY * 1.2 : 100,
          gridData: FlGridData(drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 52,
                getTitlesWidget: (v, _) => Text(_short(v), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final int i = v.toInt();
                  if (i < 0 || i >= months.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(months[i].label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)));
                })),
          ),
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.cardLight,
            // Use spot.barIndex (line index in lineBarsData) — not the spot's
            // position in the touched-spots list, which may be sparse.
            getTooltipItems: (spots) => spots.map((spot) {
              final int idx = spot.barIndex.clamp(0, _topCats.length - 1);
              return LineTooltipItem(
                '${_topCats[idx]}: ${_fmt.format(spot.y)}',
                TextStyle(color: AppColors.category(_topCats[idx]), fontSize: 11, fontWeight: FontWeight.w600),
              );
            }).toList(),
          )),
        )),
      ),
      const SizedBox(height: 8),
      // Legend
      Wrap(spacing: 12, runSpacing: 6, children: _topCats.map((cat) {
        final Color col = AppColors.category(cat);
        return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(width: 16, height: 3, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(cat, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]);
      }).toList()),
    ]);
  }

  // ── New: Health Score History ──────────────────────────────────────────────

  Widget _scoreHistoryChart() {
    if (_history.length < 2) return const SizedBox.shrink();
    final List<_TrendMonth> months = _history.length > 6
        ? _history.sublist(_history.length - 6) : _history;

    final bars = months.asMap().entries.map((entry) => BarChartGroupData(
      x: entry.key,
      barRods: <BarChartRodData>[BarChartRodData(
        toY: entry.value.score.toDouble(), width: 24,
        color: entry.value.scoreColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      )],
    )).toList();

    return Container(
      height: 200, padding: const EdgeInsets.fromLTRB(4, 16, 8, 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: BarChart(BarChartData(
        barGroups: bars, maxY: 100, minY: 0,
        gridData: FlGridData(drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 32,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) {
                final int i = v.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(months[i].label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)));
              })),
        ),
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.cardLight,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${months[group.x].label}\nScore: ${rod.toY.toInt()}',
              const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
        )),
      )),
    );
  }

  // ── New: Payday Effect ────────────────────────────────────────────────────

  Widget _payDayChart() {
    if (_payDayAvg.isEmpty) return const SizedBox.shrink();

    final List<int> days = List.generate(31, (i) => i + 1);
    final double maxVal  = _payDayAvg.values.fold(0.0, max);
    if (maxVal == 0) return const SizedBox.shrink();

    final bars = days.map((day) => BarChartGroupData(
      x: day,
      barRods: <BarChartRodData>[BarChartRodData(
        toY: _payDayAvg[day] ?? 0, width: 12,
        color: day <= 7
            ? AppColors.accent
            : day <= 14
                ? AppColors.accent.withOpacity(0.7)
                : AppColors.textMuted,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      )],
    )).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Container(
        height: 200,
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(4, 12, 8, 8),
          child: SizedBox(
            width: 31 * 22.0,
            child: BarChart(BarChartData(
              barGroups: bars, maxY: maxVal * 1.3, minY: 0,
              gridData: FlGridData(drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
                    getTitlesWidget: (v, _) {
                      final int d = v.toInt();
                      if (d % 5 != 0 && d != 1) return const SizedBox.shrink();
                      return Padding(padding: const EdgeInsets.only(top: 4),
                          child: Text('$d', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)));
                    })),
              ),
              barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.cardLight,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    'Day ${group.x}\n${_fmt.format(rod.toY)}',
                    const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 11)),
              )),
            )),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: <Widget>[
        Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        const Text('Days 1–7 (post-payday)', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(width: 14),
        Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        const Text('Rest of month', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    ]);
  }

  // ── New: Fixed vs Variable ─────────────────────────────────────────────────

  Widget _fixedVarCard() {
    final double total    = _fixedSpend + _varSpend;
    final double fixedPct = total > 0 ? _fixedSpend / total : 0;
    final double varPct   = total > 0 ? _varSpend   / total : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        // Split bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(children: <Widget>[
            if (fixedPct > 0)
              Expanded(flex: (fixedPct * 100).round(), child: Container(height: 12, color: const Color(0xFF60A5FA))),
            if (varPct > 0)
              Expanded(flex: (varPct * 100).round(), child: Container(height: 12, color: AppColors.accent)),
          ]),
        ),
        const SizedBox(height: 14),
        // Two columns
        Row(children: <Widget>[
          Expanded(child: _fvCol('Fixed', _fixedSpend, fixedPct, const Color(0xFF60A5FA),
              'Recurring expense categories')),
          Container(width: 1, height: 56, color: AppColors.divider),
          Expanded(child: _fvCol('Variable', _varSpend, varPct, AppColors.accent,
              'Discretionary spending')),
        ]),
        if (_fixedCats.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Add recurring expenses in Profile to classify fixed costs',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _fvCol(String label, double amount, double pct, Color color, String sub) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(children: <Widget>[
      Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      Text(_fmt.format(amount), style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
    ]),
  );

  // ── New: Top Payees ────────────────────────────────────────────────────────

  Widget _topPayeesCard() {
    if (_topPayees.isEmpty) return const SizedBox.shrink();
    final double maxAmt   = _topPayees.first.value;
    final double grandTotal = _topPayees.fold(0.0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(children: _topPayees.asMap().entries.map((entry) {
        final int    rank   = entry.key + 1;
        final String name   = entry.value.key;
        final double amount = entry.value.value;
        final double bar    = maxAmt > 0 ? amount / maxAmt : 0;
        final double pct    = grandTotal > 0 ? amount / grandTotal * 100 : 0;
        final bool isLast   = entry.key == _topPayees.length - 1;
        return Column(children: <Widget>[
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: <Widget>[
            SizedBox(width: 24, child: Text('#$rank',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                  value: bar, minHeight: 4,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent))),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
              Text(_fmt.format(amount),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${pct.toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ]),
          ])),
          if (!isLast) const Divider(height: 1, indent: 30),
        ]);
      }).toList()),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));

  String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
