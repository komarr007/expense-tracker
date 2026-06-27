import 'package:flutter/material.dart';

class SavingsGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  /// ARGB hex string, e.g. 'FF6C63FF'. Stored without '#'.
  final String colorHex;
  final DateTime createdAt;

  const SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.colorHex,
    required this.createdAt,
  });

  Color get color {
    final String hex = colorHex.length == 6 ? 'FF$colorHex' : colorHex;
    return Color(int.parse(hex, radix: 16));
  }

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  bool get isComplete => currentAmount >= targetAmount;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'deadline': deadline?.toIso8601String(),
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };

  factory SavingsGoal.fromMap(Map<String, dynamic> m) => SavingsGoal(
        id: m['id'] as int?,
        name: m['name'] as String,
        targetAmount: (m['target_amount'] as num).toDouble(),
        currentAmount: (m['current_amount'] as num).toDouble(),
        deadline: m['deadline'] != null
            ? DateTime.parse(m['deadline'] as String)
            : null,
        colorHex: m['color_hex'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  SavingsGoal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    String? colorHex,
    DateTime? createdAt,
  }) =>
      SavingsGoal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        colorHex: colorHex ?? this.colorHex,
        createdAt: createdAt ?? this.createdAt,
      );
}
