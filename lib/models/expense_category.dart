import 'package:flutter/material.dart';

class ExpenseCategory {
  final int? id;
  final String name;
  /// 8-char ARGB hex without '#', e.g. 'FF2DD4BF'.
  final String colorHex;
  /// '50/30/20' bucket: 'needs' | 'wants' | 'savings'
  final String nature;
  final int sortOrder;
  /// True → shown with a lock icon and cannot be deleted.
  final bool isDefault;

  const ExpenseCategory({
    this.id,
    required this.name,
    required this.colorHex,
    required this.nature,
    required this.sortOrder,
    this.isDefault = false,
  });

  Color get color => Color(int.parse(colorHex, radix: 16));

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'color_hex': colorHex,
        'nature': nature,
        'sort_order': sortOrder,
        'is_default': isDefault ? 1 : 0,
      };

  factory ExpenseCategory.fromMap(Map<String, dynamic> m) => ExpenseCategory(
        id: m['id'] as int?,
        name: m['name'] as String,
        colorHex: m['color_hex'] as String,
        nature: m['nature'] as String,
        sortOrder: (m['sort_order'] as int?) ?? 0,
        isDefault: (m['is_default'] as int?) == 1,
      );

  ExpenseCategory copyWith({
    int? id,
    String? name,
    String? colorHex,
    String? nature,
    int? sortOrder,
    bool? isDefault,
  }) =>
      ExpenseCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        nature: nature ?? this.nature,
        sortOrder: sortOrder ?? this.sortOrder,
        isDefault: isDefault ?? this.isDefault,
      );
}
