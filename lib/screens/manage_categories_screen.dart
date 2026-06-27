import 'package:flutter/material.dart';
import '../helpers/db_helper.dart';
import '../models/expense_category.dart';
import '../services/category_registry.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<ExpenseCategory> _cats = <ExpenseCategory>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await CategoryRegistry().reload();
    if (mounted) setState(() => _cats = List<ExpenseCategory>.from(CategoryRegistry().all));
  }

  Future<void> _delete(ExpenseCategory cat) async {
    if (cat.isDefault) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Category',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${cat.name}"?\n\nExisting expenses with this category will keep the name but lose the color.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.negative))),
        ],
      ),
    );
    if (confirmed != true) return;
    await DBHelper().deleteCategory(cat.id!);
    ReloadNotifier.instance.notify();
    _load();
  }

  void _showSheet({ExpenseCategory? cat}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        category: cat,
        onSaved: () {
          ReloadNotifier.instance.notify();
          _load();
        },
      ),
    );
  }

  String _natureLabel(String nature) {
    switch (nature) {
      case 'needs':   return 'Needs';
      case 'savings': return 'Savings';
      default:        return 'Wants';
    }
  }

  Color _natureBadgeColor(String nature) {
    switch (nature) {
      case 'needs':   return AppColors.negative;
      case 'savings': return AppColors.positive;
      default:        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Categories'),
      ),
      body: _cats.isEmpty
          ? const Center(
              child: Text('No categories yet.',
                  style: TextStyle(color: AppColors.textMuted)))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _cats.length,
              onReorder: _onReorder,
              itemBuilder: (ctx, i) {
                final ExpenseCategory cat = _cats[i];
                return _catTile(cat, key: ValueKey<int?>(cat.id));
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final ExpenseCategory moved = _cats.removeAt(oldIndex);
      _cats.insert(newIndex, moved);
    });
    // Persist new sort_order values
    final db = DBHelper();
    for (int i = 0; i < _cats.length; i++) {
      final ExpenseCategory c = _cats[i];
      if (c.id != null) {
        await db.updateCategory(c.copyWith(sortOrder: i));
      }
    }
    await CategoryRegistry().reload();
    ReloadNotifier.instance.notify();
  }

  Widget _catTile(ExpenseCategory cat, {required Key key}) {
    final Widget tile = Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
        ),
        title: Text(cat.name,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _natureBadgeColor(cat.nature).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _natureLabel(cat.nature),
            style: TextStyle(
                color: _natureBadgeColor(cat.nature),
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ),
        subtitleTextStyle: const TextStyle(fontSize: 11),
        trailing: cat.isDefault
            ? const Icon(Icons.lock_outline_rounded,
                color: AppColors.textMuted, size: 18)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.textMuted, size: 18),
                    onPressed: () => _showSheet(cat: cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.negative, size: 18),
                    onPressed: () => _delete(cat),
                  ),
                ],
              ),
      ),
    );

    return tile;
  }
}

// ── Category add / edit sheet ─────────────────────────────────────────────────

class _CategorySheet extends StatefulWidget {
  final ExpenseCategory? category;
  final VoidCallback onSaved;
  const _CategorySheet({this.category, required this.onSaved});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  static const List<String> _palette = <String>[
    'FFF472B6', // pink
    'FF60A5FA', // blue
    'FFFB7185', // red
    'FFA78BFA', // purple
    'FF2DD4BF', // cyan
    'FFFBBF24', // amber
    'FF4ADE80', // green
    'FF94A3B8', // slate
  ];

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  String _nature = 'wants';
  String _colorHex = 'FFF472B6';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ExpenseCategory? cat = widget.category;
    if (cat != null) {
      _nameCtrl.text = cat.name;
      _nature        = cat.nature;
      _colorHex      = cat.colorHex;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    final String name = _nameCtrl.text.trim();
    final bool isEdit = widget.category != null;

    // Check duplicate name (excluding self on edit), case-insensitive
    final List<String> existing = CategoryRegistry().names
        .where((n) => !isEdit || n.toLowerCase() != widget.category!.name.toLowerCase())
        .toList();
    if (existing.any((n) => n.toLowerCase() == name.toLowerCase())) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A category with that name already exists.')),
      );
      return;
    }

    final int sortOrder = isEdit
        ? widget.category!.sortOrder
        : (CategoryRegistry().all.isEmpty
            ? 0
            : CategoryRegistry().all.last.sortOrder + 1);

    final ExpenseCategory cat = ExpenseCategory(
      id:        widget.category?.id,
      name:      name,
      colorHex:  _colorHex,
      nature:    _nature,
      sortOrder: sortOrder,
      isDefault: widget.category?.isDefault ?? false,
    );

    if (isEdit) {
      await DBHelper().updateCategory(cat);
    } else {
      await DBHelper().insertCategory(cat);
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20, right: 20, top: 12),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.category == null ? 'New Category' : 'Edit Category',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameCtrl,
                autofocus: widget.category == null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'e.g. groceries',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),

              // Nature
              const Text('50/30/20 bucket',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(children: <Widget>[
                _natureToggle('Needs',   'needs',   AppColors.negative),
                const SizedBox(width: 8),
                _natureToggle('Wants',   'wants',   AppColors.warning),
                const SizedBox(width: 8),
                _natureToggle('Savings', 'savings', AppColors.positive),
              ]),
              const SizedBox(height: 20),

              // Color
              const Text('Color',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: _palette.map((String hex) {
                  final Color c = Color(int.parse(hex, radix: 16));
                  final bool selected = _colorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: selected
                            ? <BoxShadow>[
                                BoxShadow(
                                    color: c.withOpacity(0.5),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Save
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48)),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(widget.category == null
                          ? 'Add Category'
                          : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _natureToggle(String label, String value, Color accent) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _nature = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _nature == value
                  ? accent.withOpacity(0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _nature == value ? accent : AppColors.divider,
              ),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _nature == value ? accent : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}
