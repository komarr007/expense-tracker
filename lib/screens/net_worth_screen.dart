import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/net_worth_item.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';

class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});

  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  List<NetWorthItem> _items = <NetWorthItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<NetWorthItem> items = await DBHelper().getNetWorthItems();
    if (mounted) setState(() => _items = items);
  }

  List<NetWorthItem> get _assets      => _items.where((i) => i.isAsset).toList();
  List<NetWorthItem> get _liabilities => _items.where((i) => !i.isAsset).toList();

  double get _totalAssets      => _assets.fold(0, (s, i) => s + i.value);
  double get _totalLiabilities => _liabilities.fold(0, (s, i) => s + i.value);
  double get _netWorth         => _totalAssets - _totalLiabilities;

  Future<void> _showSheet({NetWorthItem? item, required bool isAsset}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(item: item, isAsset: isAsset),
    );
    if (result == true) {
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  Future<void> _delete(NetWorthItem item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from your net worth?'),
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
      await DBHelper().deleteNetWorthItem(item.id!);
      ReloadNotifier.instance.notify();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool positive = _netWorth >= 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Net Worth')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── Net worth summary ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: <Widget>[
                Text('Net Worth', style: const TextStyle(color: AppColors.textMuted, fontSize: 13, letterSpacing: 0.6)),
                const SizedBox(height: 8),
                Text(
                  _fmt.format(_netWorth),
                  style: TextStyle(
                    color: positive ? AppColors.positive : AppColors.negative,
                    fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(child: _summaryCol('Assets', _totalAssets, AppColors.positive)),
                    Container(width: 1, height: 40, color: AppColors.divider),
                    Expanded(child: _summaryCol('Liabilities', _totalLiabilities, AppColors.negative)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Assets ────────────────────────────────────────────────────────
          _sectionHeader('ASSETS', isAsset: true),
          const SizedBox(height: 8),
          if (_assets.isEmpty)
            _emptyHint('No assets yet. Tap + to add one.')
          else
            ..._assets.map((item) => _itemTile(item)),
          const SizedBox(height: 24),

          // ── Liabilities ───────────────────────────────────────────────────
          _sectionHeader('LIABILITIES', isAsset: false),
          const SizedBox(height: 8),
          if (_liabilities.isEmpty)
            _emptyHint('No liabilities. ')
          else
            ..._liabilities.map((item) => _itemTile(item)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryCol(String label, double value, Color color) => Column(
    children: <Widget>[
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 4),
      Text(_fmt.format(value),
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
    ],
  );

  Widget _sectionHeader(String title, {required bool isAsset}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Text(title, style: const TextStyle(
          color: AppColors.textMuted, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      GestureDetector(
        onTap: () => _showSheet(isAsset: isAsset),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: const <Widget>[
              Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
              SizedBox(width: 4),
              Text('Add', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _emptyHint(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
  );

  Widget _itemTile(NetWorthItem item) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: (item.isAsset ? AppColors.positive : AppColors.negative).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _typeIcon(item.type),
          size: 18,
          color: item.isAsset ? AppColors.positive : AppColors.negative,
        ),
      ),
      title: Text(item.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(item.type, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_fmt.format(item.value),
              style: TextStyle(
                color: item.isAsset ? AppColors.positive : AppColors.negative,
                fontWeight: FontWeight.w700, fontSize: 14,
              )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSheet(item: item, isAsset: item.isAsset),
            child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _delete(item),
            child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bank':        return Icons.account_balance_outlined;
      case 'property':    return Icons.home_outlined;
      case 'investment':  return Icons.trending_up_rounded;
      case 'vehicle':     return Icons.directions_car_outlined;
      case 'loan':        return Icons.handshake_outlined;
      case 'credit card': return Icons.credit_card_outlined;
      case 'mortgage':    return Icons.house_outlined;
      default:            return Icons.circle_outlined;
    }
  }
}

// ── Add / Edit bottom sheet ───────────────────────────────────────────────────

class _ItemSheet extends StatefulWidget {
  final NetWorthItem? item;
  final bool isAsset;
  const _ItemSheet({this.item, required this.isAsset});

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _nameCtrl  = TextEditingController();
  final TextEditingController _valueCtrl = TextEditingController();
  late String _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameCtrl.text  = item.name;
      _valueCtrl.text = item.value.toStringAsFixed(0);
      _type           = item.type;
    } else {
      _type = widget.isAsset
          ? NetWorthItem.assetTypes.first
          : NetWorthItem.liabilityTypes.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final now  = DateTime.now();
    final item = NetWorthItem(
      id:        widget.item?.id,
      name:      _nameCtrl.text.trim(),
      value:     double.parse(_valueCtrl.text.replaceAll(',', '')),
      type:      _type,
      isAsset:   widget.isAsset,
      createdAt: widget.item?.createdAt ?? now,
      updatedAt: now,
    );
    if (widget.item == null) {
      await DBHelper().insertNetWorthItem(item);
    } else {
      await DBHelper().updateNetWorthItem(item);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> types = widget.isAsset
        ? NetWorthItem.assetTypes
        : NetWorthItem.liabilityTypes;
    final String title = widget.item == null
        ? (widget.isAsset ? 'Add Asset' : 'Add Liability')
        : (widget.isAsset ? 'Edit Asset' : 'Edit Liability');

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
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Name (e.g. BCA Savings)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: '0',
                  prefix: Text('Rp  ', style: TextStyle(color: AppColors.textSecondary)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                items: types.map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                onChanged: (v) { if (v != null) setState(() => _type = v); },
                decoration: const InputDecoration(hintText: 'Type'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.item == null ? 'Add' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
