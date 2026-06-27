import 'package:flutter/material.dart';
import '../helpers/db_helper.dart';
import '../models/expense_category.dart';

/// In-memory cache of user-defined expense categories.
///
/// Call [reload] once at startup (SplashScreen._init) and after any
/// category CRUD operation. All other code reads synchronously from [all],
/// [names], [colorOf], and [natureOf].
class CategoryRegistry {
  static final CategoryRegistry _i = CategoryRegistry._();
  factory CategoryRegistry() => _i;
  CategoryRegistry._();

  List<ExpenseCategory> _list = <ExpenseCategory>[];

  List<ExpenseCategory> get all => _list;
  List<String> get names => _list.map((ExpenseCategory c) => c.name).toList();
  bool get isEmpty => _list.isEmpty;

  /// Returns the stored color for [name], or accent purple as fallback.
  Color colorOf(String name) {
    final String lower = name.toLowerCase();
    for (final ExpenseCategory c in _list) {
      if (c.name.toLowerCase() == lower) return c.color;
    }
    return const Color(0xFF6C63FF);
  }

  /// Returns 'needs' | 'wants' | 'savings' for [name], defaulting to 'wants'.
  String natureOf(String name) {
    final String lower = name.toLowerCase();
    for (final ExpenseCategory c in _list) {
      if (c.name.toLowerCase() == lower) return c.nature;
    }
    return 'wants';
  }

  Future<void> reload() async {
    _list = await DBHelper().getCategories();
  }
}
