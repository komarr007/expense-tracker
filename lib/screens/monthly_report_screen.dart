import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/db_helper.dart';
import '../models/expense.dart';
import '../models/income_record.dart';
import '../theme/app_theme.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  List<Expense>      _allExpenses = <Expense>[];
  List<IncomeRecord> _allIncome   = <IncomeRecord>[];
  List<String>       _months      = <String>[];
  String _selectedMonth           = '';

  // Computed
  double _totalExp      = 0;
  double _totalInc      = 0;
  double _prevTotalExp  = 0;
  double _budget        = 0;
  Map<String, double> _catTotals      = <String, double>{};
  Map<String, double> _prevCatTotals  = <String, double>{};
  Map<int, double>    _dowTotals      = <int, double>{};   // 1=Mon…7=Sun
  Map<int, int>       _dowCounts      = <int, int>{};
  Map<String, double> _dailyTotals    = <String, double>{};
  Map<String, int>    _dailyCounts    = <String, int>{};

  bool _loading = true;

  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  double get _net        => _totalInc - _totalExp;
  double get _savingsRate => _totalInc > 0 ? (_net / _totalInc).clamp(0.0, 1.0) : 0;

  static const List<String> _dowLabels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final List<Expense>      expenses = await DBHelper().getExpenses();
    final List<IncomeRecord> income   = await DBHelper().getIncomeRecords();
    final prefs = await SharedPreferences.getInstance();
    final double budget = prefs.getDouble('monthly_budget') ?? 0;

    // Collect unique months from expenses + income combined
    final Set<String> monthSet = <String>{};
    for (final e in expenses) monthSet.add(DateFormat('MMMM yyyy').format(e.spend_date));
    for (final r in income)   monthSet.add(DateFormat('MMMM yyyy').format(r.income_date));
    final List<String> months = monthSet.toList();

    // Default to current month, or first available
    final String currentM = DateFormat('MMMM yyyy').format(DateTime.now());
    final String selected = months.contains(currentM)
        ? currentM
        : (months.isNotEmpty ? months.first : currentM);

    setState(() {
      _allExpenses    = expenses;
      _allIncome      = income;
      _months         = months;
      _selectedMonth  = selected;
      _budget         = budget;
    });
    _compute(selected);
    setState(() => _loading = false);
  }

  void _compute(String month) {
    final fmt  = DateFormat('MMMM yyyy');
    DateTime sel;
    try { sel = fmt.parse(month); } catch (_) { sel = DateTime.now(); }
    final String prev = fmt.format(DateTime(sel.year, sel.month - 1));

    final List<Expense>      cur    = _allExpenses.where((e) => DateFormat('MMMM yyyy').format(e.spend_date) == month).toList();
    final List<Expense>      prv    = _allExpenses.where((e) => DateFormat('MMMM yyyy').format(e.spend_date) == prev).toList();
    final List<IncomeRecord> incCur = _allIncome.where((r)  => DateFormat('MMMM yyyy').format(r.income_date) == month).toList();

    // Totals
    final double tExp = cur.fold(0.0, (s, e) => s + e.amount);
    final double tInc = incCur.fold(0.0, (s, r) => s + r.amount);
    final double pExp = prv.fold(0.0, (s, e) => s + e.amount);

    // Category totals
    final Map<String, double> cats = <String, double>{};
    for (final e in cur) cats.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);

    final Map<String, double> prevCats = <String, double>{};
    for (final e in prv) prevCats.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);

    // Day of week (1=Mon … 7=Sun)
    final Map<int, double> dow = <int, double>{};
    final Map<int, int>    dowN = <int, int>{};
    for (final e in cur) {
      final int d = e.spend_date.weekday;
      dow.update(d, (v) => v + e.amount, ifAbsent: () => e.amount);
      dowN.update(d, (v) => v + 1, ifAbsent: () => 1);
    }

    // Daily totals (key: 'yyyy-MM-dd')
    final Map<String, double> daily = <String, double>{};
    final Map<String, int>    dailyN = <String, int>{};
    for (final e in cur) {
      final String k = DateFormat('yyyy-MM-dd').format(e.spend_date);
      daily.update(k, (v) => v + e.amount, ifAbsent: () => e.amount);
      dailyN.update(k, (v) => v + 1, ifAbsent: () => 1);
    }

    setState(() {
      _totalExp     = tExp;
      _totalInc     = tInc;
      _prevTotalExp = pExp;
      _catTotals    = cats;
      _prevCatTotals = prevCats;
      _dowTotals    = dow;
      _dowCounts    = dowN;
      _dailyTotals  = daily;
      _dailyCounts  = dailyN;
    });
  }

  void _selectMonth(String? m) {
    if (m == null) return;
    setState(() => _selectedMonth = m);
    _compute(m);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _months.isEmpty
            ? const Text('Monthly Report')
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth.isNotEmpty && _months.contains(_selectedMonth)
                      ? _selectedMonth : null,
                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.textSecondary, size: 20),
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  items: _months.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
                  onChanged: _selectMonth,
                ),
              ),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allExpenses.isEmpty
              ? _empty()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _heroCard(),
                      const SizedBox(height: 12),
                      _cashflowCard(),
                      if (_totalInc > 0) ...<Widget>[
                        const SizedBox(height: 12),
                        _savingsCard(),
                      ],
                      if (_budget > 0) ...<Widget>[
                        const SizedBox(height: 12),
                        _budgetCard(),
                      ],
                      const SizedBox(height: 24),
                      _sectionHeader('Top Spending Categories'),
                      const SizedBox(height: 8),
                      _categoriesCard(),
                      const SizedBox(height: 24),
                      _sectionHeader('Spending by Day of Week'),
                      const SizedBox(height: 8),
                      _dowCard(),
                      const SizedBox(height: 24),
                      _sectionHeader('Spending Calendar'),
                      const SizedBox(height: 8),
                      _calendarHeatmap(),
                      const SizedBox(height: 24),
                      _sectionHeader('Daily Breakdown'),
                      const SizedBox(height: 8),
                      _dailyCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.assessment_outlined, size: 72, color: AppColors.textMuted),
        const SizedBox(height: 16),
        const Text('No data yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Add expenses to generate reports', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    ),
  );

  Widget _sectionHeader(String label) => Text(label,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4));

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _heroCard() {
    final double diff = _totalExp - _prevTotalExp;
    final bool isUp   = diff > 0;
    final double pct  = _prevTotalExp > 0 ? (diff.abs() / _prevTotalExp) * 100 : 0;
    final Color tCol  = isUp ? AppColors.negative : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1E1B4B), Color(0xFF2D2369)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3730A3).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Total Expenses', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Text(_fmt.format(_totalExp),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 8),
          Row(children: <Widget>[
            if (_prevTotalExp > 0) ...<Widget>[
              Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: tCol, size: 16),
              const SizedBox(width: 4),
              Text(
                '${isUp ? '+' : '-'}${pct.toStringAsFixed(1)}% vs last month',
                style: TextStyle(color: tCol, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ] else
              const Text('No data from last month', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ],
      ),
    );
  }

  Widget _cashflowCard() {
    if (_totalInc == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 8),
            const Text('No income recorded this month', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    final bool isPos = _net >= 0;
    final Color col  = isPos ? AppColors.positive : AppColors.negative;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(0.3)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _cfCol('Income', _totalInc, AppColors.positive)),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(child: _cfCol('Expenses', _totalExp, AppColors.negative)),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(child: _cfCol('Net', _net, col, prefix: isPos ? '+' : '')),
        ],
      ),
    );
  }

  Widget _cfCol(String label, double amount, Color color, {String prefix = ''}) => Column(
    children: <Widget>[
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 4),
      Text('$prefix${_fmt.format(amount)}',
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    ],
  );

  Widget _savingsCard() {
    final double rate = _savingsRate;
    final Color col   = rate >= 0.2 ? AppColors.positive : rate >= 0.1 ? AppColors.warning : AppColors.negative;
    final String msg  = rate >= 0.3 ? 'Excellent savings rate!'
        : rate >= 0.2 ? 'Good job saving this month'
        : rate >= 0.1 ? 'Try to save more next month'
        : 'Consider reducing expenses';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Savings Rate', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${(rate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: col, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate, minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(col),
            ),
          ),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('Saved ${_fmt.format(_net)} out of ${_fmt.format(_totalInc)} income',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _budgetCard() {
    final double progress = (_totalExp / _budget).clamp(0.0, 1.0);
    final bool isOver     = _totalExp > _budget;
    final Color col       = isOver ? AppColors.negative : progress > 0.8 ? AppColors.warning : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Monthly Budget', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${(progress * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 8,
                backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(col)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                isOver ? 'Over by ${_fmt.format(_totalExp - _budget)}' : '${_fmt.format(_budget - _totalExp)} remaining',
                style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text('Limit: ${_fmt.format(_budget)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoriesCard() {
    if (_catTotals.isEmpty) {
      return _noDataCard('No spending recorded');
    }
    final sorted = _catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final double maxVal = top.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: top.map((entry) {
          final Color color  = AppColors.category(entry.key);
          final double pct   = _totalExp > 0 ? entry.value / _totalExp : 0;
          final double bar   = maxVal > 0 ? entry.value / maxVal : 0;
          final double? prev = _prevCatTotals[entry.key];
          final bool hasChange = prev != null && prev > 0;
          final double change  = hasChange ? (entry.value - prev) / prev * 100 : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(children: <Widget>[
              Row(children: <Widget>[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                if (hasChange)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                      style: TextStyle(color: change > 0 ? AppColors.negative : AppColors.positive, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                Text('${(pct * 100).toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                Text(_fmt.format(entry.value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: bar, minHeight: 4,
                    backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(color)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _dowCard() {
    if (_dowTotals.isEmpty) return _noDataCard('No spending data');
    final double maxAvg = _dowTotals.entries
        .map((e) => e.value / (_dowCounts[e.key] ?? 1))
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: List.generate(7, (i) {
          final int dow   = i + 1;
          final double avg = _dowTotals.containsKey(dow)
              ? _dowTotals[dow]! / (_dowCounts[dow] ?? 1) : 0;
          final double bar = maxAvg > 0 ? avg / maxAvg : 0;
          final bool isWeekend = dow >= 6;
          final Color col = isWeekend ? AppColors.warning : AppColors.accent;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: <Widget>[
              SizedBox(
                width: 32,
                child: Text(_dowLabels[i],
                    style: TextStyle(
                      color: isWeekend ? AppColors.warning : AppColors.textSecondary,
                      fontSize: 12, fontWeight: isWeekend ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: bar, minHeight: 12,
                      backgroundColor: AppColors.divider, valueColor: AlwaysStoppedAnimation<Color>(col)),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: Text(
                  avg > 0 ? _fmt.format(avg) : '—',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _dailyCard() {
    if (_dailyTotals.isEmpty) return _noDataCard('No transactions recorded');
    final sorted = _dailyTotals.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final bool isLast = entry.key == sorted.length - 1;
          final String dateKey = entry.value.key;
          final double total   = entry.value.value;
          final int    count   = _dailyCounts[dateKey] ?? 0;
          DateTime date;
          try { date = DateFormat('yyyy-MM-dd').parse(dateKey); } catch (_) { date = DateTime.now(); }
          return Column(children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: <Widget>[
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(DateFormat('d').format(date),
                        style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(DateFormat('EEEE, MMMM d').format(date),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('$count transaction${count != 1 ? 's' : ''}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ),
                Text(_fmt.format(total),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
            if (!isLast) const Divider(height: 1, indent: 68, endIndent: 16),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _noDataCard(String msg) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
    child: Center(child: Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
  );

  // ── Calendar Heatmap ──────────────────────────────────────────────────────

  Widget _calendarHeatmap() {
    if (_dailyTotals.isEmpty) return _noDataCard('No spending data for this month');

    DateTime sel;
    try { sel = DateFormat('MMMM yyyy').parse(_selectedMonth); }
    catch (_) { return const SizedBox.shrink(); }

    final int daysInMonth  = DateTime(sel.year, sel.month + 1, 0).day;
    final int firstWeekday = DateTime(sel.year, sel.month, 1).weekday; // 1=Mon, 7=Sun
    final int leadingBlanks = firstWeekday - 1;

    // Day-of-month → total amount
    final Map<int, double> dayAmt = <int, double>{};
    for (final entry in _dailyTotals.entries) {
      try {
        final DateTime d = DateFormat('yyyy-MM-dd').parse(entry.key);
        dayAmt[d.day] = entry.value;
      } catch (_) {}
    }

    // Color scale: percentile tiers from non-zero amounts
    final List<double> amounts = dayAmt.values.where((v) => v > 0).toList()..sort();
    double p33 = 0, p66 = 0;
    if (amounts.length >= 3) {
      p33 = amounts[(amounts.length * 0.33).floor()];
      p66 = amounts[(amounts.length * 0.66).floor()];
    } else if (amounts.length == 2) {
      p33 = amounts[0]; p66 = amounts[1];
    } else if (amounts.length == 1) {
      p33 = p66 = amounts[0];
    }

    Color cellColor(double amount) {
      if (amount <= 0) return const Color(0xFF13132A);
      if (amount <= p33) return AppColors.positive.withOpacity(0.40);
      if (amount <= p66) return AppColors.warning.withOpacity(0.50);
      return AppColors.negative.withOpacity(0.55);
    }

    final DateTime now = DateTime.now();
    final List<Widget> cells = <Widget>[];

    // Leading empty cells
    for (int i = 0; i < leadingBlanks; i++) cells.add(const SizedBox());

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final double amount = dayAmt[day] ?? 0;
      final Color bg      = cellColor(amount);
      final bool isToday  = sel.year == now.year && sel.month == now.month && day == now.day;

      String shortAmt = '';
      if (amount >= 1000000) shortAmt = '${(amount / 1000000).toStringAsFixed(1)}M';
      else if (amount >= 1000) shortAmt = '${(amount / 1000).toStringAsFixed(0)}K';
      else if (amount > 0)    shortAmt = amount.toStringAsFixed(0);

      cells.add(Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: isToday
              ? Border.all(color: AppColors.accent, width: 1.5)
              : Border.all(color: AppColors.divider.withOpacity(0.4), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('$day',
                style: TextStyle(
                  color: amount > 0 ? Colors.white : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center),
            if (shortAmt.isNotEmpty)
              Text(shortAmt,
                  style: const TextStyle(color: Colors.white70, fontSize: 7),
                  textAlign: TextAlign.center),
          ],
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: <Widget>[
        // Day-of-week headers
        Row(
          children: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((d) => Expanded(
                    child: Text(d,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // Grid
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.95,
          children: cells,
        ),
        const SizedBox(height: 10),
        // Legend
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          _legendChip(const Color(0xFF13132A), 'None'),
          const SizedBox(width: 10),
          _legendChip(AppColors.positive.withOpacity(0.45), 'Low'),
          const SizedBox(width: 10),
          _legendChip(AppColors.warning.withOpacity(0.55), 'Medium'),
          const SizedBox(width: 10),
          _legendChip(AppColors.negative.withOpacity(0.60), 'High'),
        ]),
      ]),
    );
  }

  Widget _legendChip(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ],
  );
}
