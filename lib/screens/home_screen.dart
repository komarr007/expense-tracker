import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/db_helper.dart';
import '../models/expense.dart';
import '../models/financial_score.dart';
import '../models/income_record.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';
import 'add_expense_screen.dart';
import 'dashboard_screen.dart';
import 'expense_list_screen.dart';
import 'finance_screen.dart';
import 'profile_screen.dart';
import 'monthly_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreenContent(),
    ExpenseListScreen(),
    DashboardScreen(),
    FinanceScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              ),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int i) => setState(() => _selectedIndex = i),
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Records'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Finance'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ── Home overview ─────────────────────────────────────────────────────────────

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  List<Expense> _todayExpenses   = <Expense>[];
  double _todayTotal             = 0.0;
  double _monthExpenses          = 0.0;
  double _monthIncome            = 0.0;
  double _prevMonthExpenses      = 0.0;
  double _monthBudget            = 0.0;
  Map<String, double> _todayCats   = <String, double>{};
  List<_Insight>      _insights    = <_Insight>[];
  FinancialScore?     _score;
  bool _loading                    = true;

  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    ReloadNotifier.instance.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    ReloadNotifier.instance.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final List<Expense>      allExpenses = await DBHelper().getExpenses();
    final List<IncomeRecord> allIncome   = await DBHelper().getIncomeRecords();
    final SharedPreferences  prefs       = await SharedPreferences.getInstance();

    final DateTime now       = DateTime.now();
    final DateTime today     = DateTime(now.year, now.month, now.day);
    final int thisYear       = now.year,  thisMonth = now.month;
    final DateTime prevDate  = DateTime(now.year, now.month - 1);
    final int prevYear       = prevDate.year, prevMonth = prevDate.month;

    final List<Expense> todayExp = allExpenses.where((e) =>
        DateTime(e.spend_date.year, e.spend_date.month, e.spend_date.day) == today).toList();

    final List<Expense> monthExp = allExpenses.where((e) =>
        e.spend_date.year == thisYear && e.spend_date.month == thisMonth).toList();

    final List<Expense> prevExp = allExpenses.where((e) =>
        e.spend_date.year == prevYear && e.spend_date.month == prevMonth).toList();

    final List<IncomeRecord> monthInc = allIncome.where((r) =>
        r.income_date.year == thisYear && r.income_date.month == thisMonth).toList();

    final Map<String, double> cats = <String, double>{};
    for (final Expense e in todayExp) {
      cats.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }

    final double mExp  = monthExp.fold(0.0, (s, e) => s + e.amount);
    final double pExp  = prevExp.fold(0.0, (s, e) => s + e.amount);
    final double mInc  = monthInc.fold(0.0, (s, r) => s + r.amount);
    final double budget = prefs.getDouble('monthly_budget') ?? 0.0;

    if (mounted) {
      setState(() {
        _todayExpenses   = todayExp;
        _todayTotal      = todayExp.fold(0.0, (s, e) => s + e.amount);
        _monthExpenses   = mExp;
        _monthIncome     = mInc;
        _prevMonthExpenses = pExp;
        _monthBudget     = budget;
        _todayCats       = cats;
        _insights = _computeInsights(
          allExpenses: allExpenses, monthExp: monthExp, prevExp: prevExp,
          monthInc: mInc, budget: budget,
        );
        _score = FinancialScore.compute(
          monthExpenses:     mExp,
          monthIncome:       mInc,
          prevMonthExpenses: pExp,
          budget:            budget,
        );
        _loading = false;
      });
    }
  }

  List<_Insight> _computeInsights({
    required List<Expense> allExpenses,
    required List<Expense> monthExp,
    required List<Expense> prevExp,
    required double monthInc,
    required double budget,
  }) {
    final List<_Insight> out = <_Insight>[];
    if (monthExp.isEmpty) return out;

    final double mTotal = monthExp.fold(0.0, (s, e) => s + e.amount);

    // 1. Net cashflow
    if (monthInc > 0) {
      final double net = monthInc - mTotal;
      out.add(_Insight(
        icon: net >= 0 ? '💚' : '🔴',
        title: net >= 0 ? 'Positive cashflow' : 'Negative cashflow',
        body: '${net >= 0 ? '+' : ''}${_fmt.format(net)} net this month (income ${_fmt.format(monthInc)})',
        color: net >= 0 ? AppColors.positive : AppColors.negative,
      ));
    }

    // 2. Budget pace
    if (budget > 0) {
      final DateTime now  = DateTime.now();
      final int elapsed   = now.day;
      final int total     = DateTime(now.year, now.month + 1, 0).day;
      final double pace   = mTotal / elapsed * total;
      if (pace > budget) {
        out.add(_Insight(
          icon: '⚠️',
          title: 'Budget at risk',
          body: 'On pace to spend ${_fmt.format(pace)} — ${_fmt.format(pace - budget)} over budget',
          color: AppColors.warning,
        ));
      } else {
        out.add(_Insight(
          icon: '✅',
          title: 'On track',
          body: 'Projected ${_fmt.format(pace)} — ${_fmt.format(budget - pace)} under budget',
          color: AppColors.positive,
        ));
      }
    }

    // 3. Fastest growing category (vs last month)
    if (prevExp.isNotEmpty) {
      final Map<String, double> cur = <String, double>{};
      final Map<String, double> prv = <String, double>{};
      for (final e in monthExp) cur.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
      for (final e in prevExp)  prv.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);

      String? topCat; double topPct = 0;
      for (final entry in cur.entries) {
        if (prv.containsKey(entry.key) && prv[entry.key]! > 0) {
          final double pct = (entry.value - prv[entry.key]!) / prv[entry.key]! * 100;
          if (pct > topPct) { topPct = pct; topCat = entry.key; }
        }
      }
      if (topCat != null && topPct > 10) {
        out.add(_Insight(
          icon: '📈',
          title: '$topCat spending up',
          body: '+${topPct.toStringAsFixed(0)}% vs last month (${_fmt.format(cur[topCat]!)})',
          color: AppColors.warning,
        ));
      }
    }

    // 4. Weekend vs weekday
    final List<Expense> weekendExp  = monthExp.where((e) => e.spend_date.weekday >= 6).toList();
    final List<Expense> weekdayExp  = monthExp.where((e) => e.spend_date.weekday < 6).toList();
    if (weekendExp.isNotEmpty && weekdayExp.isNotEmpty) {
      final double wkAvg  = weekendExp.fold(0.0, (s, e) => s + e.amount) / weekendExp.length;
      final double wdAvg  = weekdayExp.fold(0.0, (s, e) => s + e.amount) / weekdayExp.length;
      if (wkAvg > wdAvg * 1.3) {
        final double pct = (wkAvg - wdAvg) / wdAvg * 100;
        out.add(_Insight(
          icon: '🎉',
          title: 'Weekend spender',
          body: 'You spend ${pct.toStringAsFixed(0)}% more on weekends (${_fmt.format(wkAvg)}/transaction)',
          color: AppColors.accent,
        ));
      }
    }

    return out;
  }

  String _greeting() {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double diff = _monthExpenses - _prevMonthExpenses;
    final bool isUp   = diff > 0;
    final double pct  = _prevMonthExpenses > 0 ? (diff.abs() / _prevMonthExpenses) * 100 : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Greeting ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _greeting(),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
                      onPressed: _loadData,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Today hero ────────────────────────────────────
                _heroToday(),

                const SizedBox(height: 12),

                // ── Month summary ─────────────────────────────────
                _monthCard(isUp, pct, diff),

                // ── Financial Health Score ────────────────────────
                if (_score != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _scoreCard(_score!),
                ],

                // ── Net cashflow ──────────────────────────────────
                if (_monthIncome > 0) ...<Widget>[
                  const SizedBox(height: 12),
                  _cashflowCard(),
                ],

                // ── Insights ──────────────────────────────────────
                if (_insights.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  const Text('INSIGHTS', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  ..._insights.map((ins) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _insightCard(ins),
                  )),
                ],

                // ── Today's transactions ───────────────────────────
                if (_todayExpenses.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  const Text("TODAY'S TRANSACTIONS",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  _transactionList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroToday() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1E1B4B), Color(0xFF2D2369)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3730A3).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text("Today's Spending", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Text(_fmt.format(_todayTotal),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 4),
              Text(
                _todayExpenses.isEmpty ? 'No transactions today'
                    : '${_todayExpenses.length} transaction${_todayExpenses.length > 1 ? 's' : ''}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _monthCard(bool isUp, double pct, double diff) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              if (_prevMonthExpenses > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isUp ? AppColors.negative : AppColors.positive).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 13, color: isUp ? AppColors.negative : AppColors.positive),
                      const SizedBox(width: 3),
                      Text('${isUp ? '+' : '-'}${pct.toStringAsFixed(1)}%',
                          style: TextStyle(color: isUp ? AppColors.negative : AppColors.positive, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_fmt.format(_monthExpenses),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          if (_monthBudget > 0) ...<Widget>[
            const SizedBox(height: 12),
            _budgetBar(),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: const Text('Set a budget in Profile to track your limit',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyReportScreen())),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('View Monthly Report',
                      style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.accent, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetBar() {
    final double remaining = _monthBudget - _monthExpenses;
    final double progress  = (_monthExpenses / _monthBudget).clamp(0.0, 1.0);
    final bool isOver      = _monthExpenses > _monthBudget;
    final Color barColor   = isOver ? AppColors.negative : progress > 0.8 ? AppColors.warning : AppColors.positive;
    return Column(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress, minHeight: 6,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              isOver ? 'Over by ${_fmt.format(-remaining)}' : '${_fmt.format(remaining)} left',
              style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text('of ${_fmt.format(_monthBudget)}  ·  ${(progress * 100).toStringAsFixed(0)}% used',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _cashflowCard() {
    final double net   = _monthIncome - _monthExpenses;
    final bool isPos   = net >= 0;
    final Color netCol = isPos ? AppColors.positive : AppColors.negative;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: netCol.withOpacity(0.3)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: netCol.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
                child: Icon(isPos ? Icons.account_balance_rounded : Icons.trending_down_rounded, color: netCol, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Monthly Cashflow', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${isPos ? '+' : ''}${_fmt.format(net)}',
                style: TextStyle(color: netCol, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _cfItem('Income', _monthIncome, AppColors.positive),
              Container(width: 1, height: 30, color: AppColors.divider),
              _cfItem('Expenses', _monthExpenses, AppColors.negative),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cfItem(String label, double amount, Color color) => Expanded(
    child: Column(
      children: <Widget>[
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(_fmt.format(amount), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  // ── Financial Health Score card ───────────────────────────────────────────

  Widget _scoreCard(FinancialScore score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: score.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row: circle score + label + tip
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Score circle
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: score.color, width: 3.5),
                  color: score.color.withOpacity(0.1),
                ),
                child: Center(
                  child: Text(
                    score.maxPossible > 0 ? '${score.total}' : '—',
                    style: TextStyle(color: score.color, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('FINANCIAL HEALTH',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(score.label,
                        style: TextStyle(color: score.color, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      score.activeComponents > 0
                          ? 'Based on ${score.activeComponents} factor${score.activeComponents > 1 ? 's' : ''}'
                          : 'Not enough data',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (score.activeComponents > 0) ...<Widget>[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Component rows
            if (score.savingsPoints != null)
              _scoreRow(
                icon: Icons.savings_rounded,
                label: 'Savings Rate',
                pts: score.savingsPoints!,
                maxPts: 40,
                detail: '${(score.savingsRate! * 100).toStringAsFixed(1)}% of income saved',
              ),
            if (score.budgetPoints != null)
              _scoreRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Budget Control',
                pts: score.budgetPoints!,
                maxPts: 35,
                detail: '${(score.budgetUsage! * 100).toStringAsFixed(0)}% of budget used',
              ),
            if (score.trendPoints != null)
              _scoreRow(
                icon: Icons.trending_up_rounded,
                label: 'Spending Trend',
                pts: score.trendPoints!,
                maxPts: 25,
                detail: score.spendingChange! <= 0
                    ? '${(-score.spendingChange! * 100).toStringAsFixed(0)}% less than last month'
                    : '+${(score.spendingChange! * 100).toStringAsFixed(0)}% vs last month',
              ),
          ],

          // Tip
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: score.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: score.color.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.lightbulb_outline_rounded, color: score.color, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(score.tip,
                      style: TextStyle(color: score.color, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreRow({
    required IconData icon,
    required String label,
    required int pts,
    required int maxPts,
    required String detail,
  }) {
    final double pct  = pts / maxPts;
    final Color col   = pct >= 0.8 ? AppColors.positive : pct >= 0.5 ? AppColors.warning : AppColors.negative;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Icon(icon, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            Text('$pts / $maxPts pts',
                style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(col),
            ),
          ),
          const SizedBox(height: 3),
          Text(detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _insightCard(_Insight ins) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ins.color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(ins.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(ins.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(ins.body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: <Widget>[
          ..._todayExpenses.asMap().entries.map((entry) {
            final int idx     = entry.key;
            final Expense e   = entry.value;
            final Color cat   = AppColors.category(e.category);
            final bool isLast = idx == _todayExpenses.length - 1 && _todayCats.length <= 1;
            return Column(
              children: <Widget>[
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: e)),
                  ),
                  borderRadius: isLast
                      ? const BorderRadius.vertical(bottom: Radius.circular(16))
                      : BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                    children: <Widget>[
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: cat.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: cat, shape: BoxShape.circle))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(e.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(e.category, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(_fmt.format(e.amount),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  ),
                ),
                if (!isLast) const Divider(height: 1, indent: 68, endIndent: 16),
              ],
            );
          }),
          if (_todayCats.length > 1) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('BY CATEGORY', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  ..._todayCats.entries.toList()
                      .sorted((a, b) => b.value.compareTo(a.value))
                      .map((entry) {
                    final Color c = AppColors.category(entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                          Text(_fmt.format(entry.value),
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Insight {
  final String icon;
  final String title;
  final String body;
  final Color  color;
  const _Insight({required this.icon, required this.title, required this.body, required this.color});
}

extension _ListSortExt<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}
