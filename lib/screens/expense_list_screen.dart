import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import '../models/expense.dart';
import '../models/income_record.dart';
import '../helpers/db_helper.dart';
import '../services/category_registry.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  _ExpenseListScreenState createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen>
    with SingleTickerProviderStateMixin {
  // ── Raw data ───────────────────────────────────────────────────────────────
  List<Expense>      _allExpenses = <Expense>[];
  List<IncomeRecord> _allIncome   = <IncomeRecord>[];

  // ── Filtered/grouped data ──────────────────────────────────────────────────
  List<Expense>      _expenses = <Expense>[];
  List<IncomeRecord> _income   = <IncomeRecord>[];
  final Map<String, List<Expense>>      _byMonth       = <String, List<Expense>>{};
  final Map<String, List<IncomeRecord>> _incomeByMonth = <String, List<IncomeRecord>>{};

  // ── Filter state ───────────────────────────────────────────────────────────
  bool           _showSearch      = false;
  String         _searchQuery     = '';
  DateTime?      _filterStart;
  DateTime?      _filterEnd;
  Set<String>    _filterExpCats   = <String>{};
  Set<String>    _filterIncCats   = <String>{};

  late TabController _tabCtrl;

  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  static List<String> get _expCategories => CategoryRegistry().names;
  static List<String> get _incCategories => IncomeRecord.categories;

  // ── Computed helpers ───────────────────────────────────────────────────────
  bool get _anyFilter =>
      _filterStart != null || _filterEnd != null ||
      _filterExpCats.isNotEmpty || _filterIncCats.isNotEmpty;

  bool get _anyFilterForTab =>
      _filterStart != null || _filterEnd != null ||
      (_tabCtrl.index == 0 ? _filterExpCats.isNotEmpty : _filterIncCats.isNotEmpty);

  String get _filterSummary {
    final List<String> parts = <String>[];
    if (_searchQuery.isNotEmpty) parts.add('"$_searchQuery"');
    if (_filterStart != null || _filterEnd != null) {
      parts.add(
        '${_filterStart != null ? DateFormat('MMM d').format(_filterStart!) : '…'}'
        '–${_filterEnd != null ? DateFormat('MMM d').format(_filterEnd!) : '…'}',
      );
    }
    final Set<String> cats = _tabCtrl.index == 0 ? _filterExpCats : _filterIncCats;
    if (cats.isNotEmpty) {
      parts.add(cats.length == 1 ? cats.first : '${cats.length} categories');
    }
    return parts.join('  ·  ');
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    ReloadNotifier.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ReloadNotifier.instance.removeListener(_load);
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<Expense>      exp = await DBHelper().getExpenses();
    final List<IncomeRecord> inc = await DBHelper().getIncomeRecords();
    setState(() {
      _allExpenses = exp;
      _allIncome   = inc;
      _applyAll();
    });
  }

  // ── Filter application ─────────────────────────────────────────────────────

  void _applyAll() {
    _applyExpenses();
    _applyIncome();
  }

  void _applyExpenses() {
    List<Expense> result = List.from(_allExpenses);
    if (_searchQuery.isNotEmpty) {
      result = result.where((e) => e.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_filterStart != null) {
      result = result.where((e) => !e.spend_date.isBefore(_filterStart!)).toList();
    }
    if (_filterEnd != null) {
      final DateTime end = DateTime(_filterEnd!.year, _filterEnd!.month, _filterEnd!.day, 23, 59, 59);
      result = result.where((e) => !e.spend_date.isAfter(end)).toList();
    }
    if (_filterExpCats.isNotEmpty) {
      result = result.where((e) => _filterExpCats.contains(e.category)).toList();
    }
    _expenses = result;
    _byMonth.clear();
    for (final Expense e in _expenses) {
      _byMonth.putIfAbsent(DateFormat('MMMM yyyy').format(e.spend_date), () => <Expense>[]).add(e);
    }
  }

  void _applyIncome() {
    List<IncomeRecord> result = List.from(_allIncome);
    if (_searchQuery.isNotEmpty) {
      result = result.where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_filterStart != null) {
      result = result.where((r) => !r.income_date.isBefore(_filterStart!)).toList();
    }
    if (_filterEnd != null) {
      final DateTime end = DateTime(_filterEnd!.year, _filterEnd!.month, _filterEnd!.day, 23, 59, 59);
      result = result.where((r) => !r.income_date.isAfter(end)).toList();
    }
    if (_filterIncCats.isNotEmpty) {
      result = result.where((r) => _filterIncCats.contains(r.category)).toList();
    }
    _income = result;
    _incomeByMonth.clear();
    for (final IncomeRecord r in _income) {
      _incomeByMonth.putIfAbsent(DateFormat('MMMM yyyy').format(r.income_date), () => <IncomeRecord>[]).add(r);
    }
  }

  void _search(String q) {
    setState(() { _searchQuery = q; _applyAll(); });
  }

  void _resetFilters() {
    setState(() {
      _filterStart   = null;
      _filterEnd     = null;
      _filterExpCats = <String>{};
      _filterIncCats = <String>{};
      _searchQuery   = '';
      _showSearch    = false;
      _applyAll();
    });
  }

  // ── Filter bottom sheet ────────────────────────────────────────────────────

  Future<void> _showFilterSheet() async {
    final bool isExpTab             = _tabCtrl.index == 0;
    DateTime? tempStart             = _filterStart;
    DateTime? tempEnd               = _filterEnd;
    Set<String> tempCats            = isExpTab
        ? Set.from(_filterExpCats)
        : Set.from(_filterIncCats);
    final List<String> categories   = isExpTab ? _expCategories : _incCategories;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Handle
                  Center(
                    child: Container(width: 36, height: 4,
                        decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Filter Records',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () { setLocal(() { tempStart = null; tempEnd = null; tempCats = <String>{}; }); },
                        child: const Text('Clear all', style: TextStyle(color: AppColors.accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date range
                  const Text('DATE RANGE',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Row(children: <Widget>[
                    Expanded(child: _dateButton(
                      label: tempStart != null ? DateFormat('MMM d, yyyy').format(tempStart!) : 'From date',
                      icon: Icons.calendar_today_rounded,
                      set: (d) => setLocal(() => tempStart = d),
                      initial: tempStart,
                      last: tempEnd,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _dateButton(
                      label: tempEnd != null ? DateFormat('MMM d, yyyy').format(tempEnd!) : 'To date',
                      icon: Icons.calendar_month_rounded,
                      set: (d) => setLocal(() => tempEnd = d),
                      initial: tempEnd,
                      first: tempStart,
                    )),
                  ]),

                  const SizedBox(height: 24),

                  // Category chips
                  const Text('CATEGORY',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: categories.map((cat) {
                      final bool selected = tempCats.contains(cat);
                      final Color col     = isExpTab ? AppColors.category(cat) : AppColors.income(cat);
                      return FilterChip(
                        label: Text(cat,
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.textSecondary,
                              fontSize: 12,
                            )),
                        selected: selected,
                        onSelected: (v) => setLocal(() {
                          if (v) { tempCats.add(cat); } else { tempCats.remove(cat); }
                        }),
                        avatar: Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                        selectedColor: col,
                        backgroundColor: AppColors.card,
                        checkmarkColor: Colors.white,
                        side: BorderSide(color: selected ? col : AppColors.divider),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterStart = tempStart;
                          _filterEnd   = tempEnd;
                          if (isExpTab) { _filterExpCats = tempCats; } else { _filterIncCats = tempCats; }
                          _applyAll();
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required IconData icon,
    required void Function(DateTime) set,
    DateTime? initial,
    DateTime? first,
    DateTime? last,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        textStyle: const TextStyle(fontSize: 12),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
      onPressed: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initial ?? DateTime.now(),
          firstDate: first ?? DateTime(2000),
          lastDate: last ?? DateTime.now(),
          builder: (bCtx, child) => Theme(
            data: Theme.of(bCtx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.accent, onPrimary: Colors.white,
                surface: AppColors.card, onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) set(picked);
      },
    );
  }

  // ── Expense CRUD ───────────────────────────────────────────────────────────

  Future<bool> _confirmDeleteExpense(Expense e) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${e.name}"?\nIt will be saved to history.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.negative))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteExpense(Expense e) async {
    if (e.id == null) return;
    await DBHelper().softDeleteExpense(e);
    ReloadNotifier.instance.notify();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted and moved to history')),
    );
  }

  Future<void> _editExpense(Expense e) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: e)));
    _load();
  }

  // ── Income CRUD ────────────────────────────────────────────────────────────

  Future<bool> _confirmDeleteIncome(IncomeRecord r) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Income'),
        content: Text('Delete "${r.name}"?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.negative))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteIncome(IncomeRecord r) async {
    if (r.id == null) return;
    await DBHelper().deleteIncome(r.id!);
    ReloadNotifier.instance.notify();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Income record deleted')),
    );
  }

  Future<void> _editIncome(IncomeRecord r) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddIncomeScreen(income: r)));
    _load();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  hintText: _tabCtrl.index == 0 ? 'Search expenses…' : 'Search income…',
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero,
                  fillColor: Colors.transparent,
                ),
                onChanged: _search,
              )
            : const Text('Records'),
        actions: <Widget>[
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _showSearch = true),
            ),
          if (_showSearch)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _showSearch  = false;
                  _searchQuery = '';
                  _applyAll();
                });
              },
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _anyFilterForTab,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: _showFilterSheet,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          onTap: (_) => setState(() {}),
          indicatorColor: AppColors.accent,
          indicatorWeight: 2,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const <Tab>[Tab(text: 'Expenses'), Tab(text: 'Income')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_tabCtrl.index == 0) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddIncomeScreen()));
          }
          _load();
        },
        backgroundColor: _tabCtrl.index == 0 ? AppColors.accent : AppColors.positive,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: <Widget>[
          // Active filter bar
          if (_anyFilter || _searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: AppColors.accent.withOpacity(0.08),
              child: Row(children: <Widget>[
                Icon(Icons.filter_list_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_filterSummary,
                      style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                  onTap: _resetFilters,
                  child: const Text('Clear', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: <Widget>[_expenseTab(), _incomeTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Expense tab ────────────────────────────────────────────────────────────

  Widget _expenseTab() {
    if (_byMonth.isEmpty) return _emptyState('No expense records', Icons.receipt_long_outlined);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _byMonth.length,
      itemBuilder: (_, i) {
        final String month       = _byMonth.keys.elementAt(i);
        final List<Expense> list = _byMonth[month]!;
        final double total       = list.fold(0, (s, e) => s + e.amount);
        return _expenseMonthSection(month, total, list);
      },
    );
  }

  Widget _expenseMonthSection(String month, double total, List<Expense> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(children: <Widget>[
            Text(month.toUpperCase(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: AppColors.divider)),
            const SizedBox(width: 8),
            Text(_fmt.format(total),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
          child: Column(
            children: list.asMap().entries.map((entry) =>
                _expenseItem(entry.value, isLast: entry.key == list.length - 1)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _expenseItem(Expense e, {required bool isLast}) {
    final Color cat = AppColors.category(e.category);
    return Dismissible(
      key: Key('exp_${e.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteExpense(e),
      onDismissed: (_) => _deleteExpense(e),
      background: Container(
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.negative.withOpacity(0.15),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
        ),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 22),
      ),
      child: Column(children: <Widget>[
        InkWell(
          onLongPress: () => _expenseOptions(e),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(children: <Widget>[
              Row(children: <Widget>[
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: cat.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: cat, shape: BoxShape.circle))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(e.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${e.category}  ·  ${DateFormat('MMM d').format(e.spend_date)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                  Text(_fmt.format(e.amount),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _expenseOptions(e),
                    child: const Icon(Icons.more_horiz_rounded, color: AppColors.textMuted, size: 18),
                  ),
                ]),
              ]),
              if (e.notes != null && e.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 52),
                  child: Row(children: <Widget>[
                    const Icon(Icons.notes_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(e.notes!,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 68, endIndent: 16),
      ]),
    );
  }

  void _expenseOptions(Expense e) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(e.name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: AppColors.accent),
            title: const Text('Edit', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _editExpense(e); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.negative),
            title: const Text('Delete', style: TextStyle(color: AppColors.negative)),
            onTap: () async {
              Navigator.pop(context);
              if (await _confirmDeleteExpense(e)) _deleteExpense(e);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Income tab ─────────────────────────────────────────────────────────────

  Widget _incomeTab() {
    if (_incomeByMonth.isEmpty) return _emptyState('No income records', Icons.arrow_downward_rounded);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _incomeByMonth.length,
      itemBuilder: (_, i) {
        final String month            = _incomeByMonth.keys.elementAt(i);
        final List<IncomeRecord> list = _incomeByMonth[month]!;
        final double total            = list.fold(0, (s, r) => s + r.amount);
        return _incomeMonthSection(month, total, list);
      },
    );
  }

  Widget _incomeMonthSection(String month, double total, List<IncomeRecord> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(children: <Widget>[
            Text(month.toUpperCase(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: AppColors.divider)),
            const SizedBox(width: 8),
            Text(_fmt.format(total),
                style: const TextStyle(color: AppColors.positive, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
          child: Column(
            children: list.asMap().entries.map((entry) =>
                _incomeItem(entry.value, isLast: entry.key == list.length - 1)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _incomeItem(IncomeRecord r, {required bool isLast}) {
    final Color cat = AppColors.income(r.category);
    return Dismissible(
      key: Key('inc_${r.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteIncome(r),
      onDismissed: (_) => _deleteIncome(r),
      background: Container(
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.negative.withOpacity(0.15),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
        ),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 22),
      ),
      child: Column(children: <Widget>[
        InkWell(
          onLongPress: () => _incomeOptions(r),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(children: <Widget>[
              Row(children: <Widget>[
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: cat.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: cat, shape: BoxShape.circle))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(r.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${r.category}  ·  ${DateFormat('MMM d').format(r.income_date)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                  Text('+${_fmt.format(r.amount)}',
                      style: const TextStyle(color: AppColors.positive, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _incomeOptions(r),
                    child: const Icon(Icons.more_horiz_rounded, color: AppColors.textMuted, size: 18),
                  ),
                ]),
              ]),
              if (r.notes != null && r.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 52),
                  child: Row(children: <Widget>[
                    const Icon(Icons.notes_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(r.notes!,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 68, endIndent: 16),
      ]),
    );
  }

  void _incomeOptions(IncomeRecord r) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(r.name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: AppColors.accent),
            title: const Text('Edit', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _editIncome(r); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.negative),
            title: const Text('Delete', style: TextStyle(color: AppColors.negative)),
            onTap: () async {
              Navigator.pop(context);
              if (await _confirmDeleteIncome(r)) _deleteIncome(r);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _emptyState(String label, IconData icon) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Icon(icon, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
    ]),
  );
}

