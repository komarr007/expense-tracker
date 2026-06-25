import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FinancialScore {
  final int total;

  // Savings component (max 40 pts) — only available when income is tracked
  final int? savingsPoints;
  final double? savingsRate;

  // Budget component (max 35 pts) — only available when a budget is set
  final int? budgetPoints;
  final double? budgetUsage;

  // Trend component (max 25 pts) — only available when previous month has data
  final int? trendPoints;
  final double? spendingChange;

  final int maxPossible;

  const FinancialScore({
    required this.total,
    this.savingsPoints,
    this.savingsRate,
    this.budgetPoints,
    this.budgetUsage,
    this.trendPoints,
    this.spendingChange,
    required this.maxPossible,
  });

  // ── Computed ───────────────────────────────────────────────────────────────

  int get activeComponents =>
      (savingsPoints != null ? 1 : 0) +
      (budgetPoints  != null ? 1 : 0) +
      (trendPoints   != null ? 1 : 0);

  String get label {
    if (maxPossible == 0) return 'No Data';
    if (total >= 85) return 'Excellent';
    if (total >= 70) return 'Good';
    if (total >= 55) return 'Fair';
    if (total >= 40) return 'Needs Work';
    return 'At Risk';
  }

  Color get color {
    if (maxPossible == 0) return AppColors.textMuted;
    if (total >= 85) return AppColors.positive;
    if (total >= 70) return const Color(0xFF34D399);
    if (total >= 55) return AppColors.warning;
    if (total >= 40) return const Color(0xFFFB923C);
    return AppColors.negative;
  }

  // Actionable tip based on the weakest component
  String get tip {
    if (maxPossible == 0) {
      return 'Set a monthly budget and track income to unlock your score.';
    }
    final double sRatio = savingsPoints != null ? savingsPoints! / 40 : 1.0;
    final double bRatio = budgetPoints  != null ? budgetPoints!  / 35 : 1.0;
    final double tRatio = trendPoints   != null ? trendPoints!   / 25 : 1.0;

    if (sRatio <= bRatio && sRatio <= tRatio && savingsPoints != null) {
      if (savingsRate! < 0)    return 'Expenses exceed income — review your biggest categories.';
      if (savingsRate! < 0.05) return 'Aim to save at least 5% of income to improve your score.';
      if (savingsRate! < 0.10) return 'Good start! Try to reach 10% savings rate.';
      if (savingsRate! < 0.20) return 'Almost there — 20% savings rate earns full marks.';
      return 'Outstanding savings rate! Keep it up.';
    }
    if (bRatio <= tRatio && budgetPoints != null) {
      if (budgetUsage! > 1.0) return 'Over budget this month — see Analytics for which categories drove it.';
      if (budgetUsage! > 0.9) return 'Close to your limit. Slow down spending for the rest of the month.';
      return 'Keep spending under 80% of your budget for maximum points.';
    }
    if (trendPoints != null) {
      if (spendingChange! > 0.20) return 'Spending jumped >20% vs last month. Investigate the increase.';
      if (spendingChange! > 0.10) return 'Spending trending up. Try to bring it back in line.';
      return 'Spending is trending in the right direction. Keep going!';
    }
    return 'Great job — all tracked areas look healthy!';
  }

  // ── Factory ────────────────────────────────────────────────────────────────

  static FinancialScore compute({
    required double monthExpenses,
    required double monthIncome,
    required double prevMonthExpenses,
    required double budget,
  }) {
    int rawPoints  = 0;
    int maxPoints  = 0;

    // ── Savings rate (40 pts) ──────────────────────────────────────────────
    int? savingsPoints;
    double? savingsRate;
    if (monthIncome > 0) {
      maxPoints += 40;
      savingsRate = (monthIncome - monthExpenses) / monthIncome;
      if      (savingsRate >= 0.20) savingsPoints = 40;
      else if (savingsRate >= 0.15) savingsPoints = 30;
      else if (savingsRate >= 0.10) savingsPoints = 20;
      else if (savingsRate >= 0.05) savingsPoints = 10;
      else if (savingsRate >= 0)    savingsPoints = 5;
      else                          savingsPoints = 0;
      rawPoints += savingsPoints;
    }

    // ── Budget adherence (35 pts) ─────────────────────────────────────────
    int? budgetPoints;
    double? budgetUsage;
    if (budget > 0) {
      maxPoints += 35;
      budgetUsage = monthExpenses / budget;
      if      (budgetUsage <= 0.70) budgetPoints = 35;
      else if (budgetUsage <= 0.80) budgetPoints = 28;
      else if (budgetUsage <= 0.90) budgetPoints = 18;
      else if (budgetUsage <= 1.00) budgetPoints = 8;
      else                          budgetPoints = 0;
      rawPoints += budgetPoints;
    }

    // ── Spending trend (25 pts) ───────────────────────────────────────────
    int? trendPoints;
    double? spendingChange;
    if (prevMonthExpenses > 0) {
      maxPoints += 25;
      spendingChange = (monthExpenses - prevMonthExpenses) / prevMonthExpenses;
      if      (spendingChange <= -0.10) trendPoints = 25;
      else if (spendingChange <= 0)     trendPoints = 20;
      else if (spendingChange <= 0.10)  trendPoints = 12;
      else if (spendingChange <= 0.20)  trendPoints = 5;
      else                              trendPoints = 0;
      rawPoints += trendPoints;
    }

    final int total = maxPoints > 0
        ? (rawPoints / maxPoints * 100).round().clamp(0, 100)
        : 0;

    return FinancialScore(
      total:          total,
      savingsPoints:  savingsPoints,
      savingsRate:    savingsRate,
      budgetPoints:   budgetPoints,
      budgetUsage:    budgetUsage,
      trendPoints:    trendPoints,
      spendingChange: spendingChange,
      maxPossible:    maxPoints,
    );
  }
}
