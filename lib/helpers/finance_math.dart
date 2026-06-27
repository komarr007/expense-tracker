import 'dart:math' as math;

/// Pure-math helpers for financial projections and debt simulation.
/// All methods are pure functions with no I/O or Flutter dependencies.
abstract final class FinanceMath {
  /// Future value of a lump sum invested for [years] at [annualRate].
  /// FV = pv × (1 + annualRate)^years
  static double futureValueLump(double pv, double annualRate, double years) {
    if (pv <= 0 || years <= 0) return 0;
    return pv * math.pow(1 + annualRate, years);
  }

  /// Future value of regular monthly contributions (ordinary annuity).
  /// FV = pmt × [((1 + r)^n − 1) / r]  where r = annualRate/12, n = years×12.
  static double futureValueAnnuity(
      double pmt, double annualRate, double years) {
    if (pmt <= 0 || years <= 0) return 0;
    final double r = annualRate / 12;
    final int n = (years * 12).round();
    if (r == 0) return pmt * n;
    return pmt * (math.pow(1 + r, n) - 1) / r;
  }

  /// Simulates month-by-month debt payoff.
  /// Capped at 600 months (50 years) to prevent infinite loops when
  /// [monthlyPayment] barely covers the accruing interest.
  static DebtPayoffResult simulateDebtPayoff({
    required double balance,
    required double annualInterestRate,
    required double monthlyPayment,
  }) {
    if (balance <= 0) return const DebtPayoffResult(months: 0, totalInterest: 0);
    if (monthlyPayment <= 0) return const DebtPayoffResult(months: 600, totalInterest: double.infinity);

    final double monthlyRate = annualInterestRate / 100 / 12;
    double remaining = balance;
    double totalInterest = 0;
    int months = 0;

    while (remaining > 0.01 && months < 600) {
      final double interest = remaining * monthlyRate;
      totalInterest += interest;
      remaining += interest;
      final double payment = math.min(monthlyPayment, remaining);
      remaining -= payment;
      months++;
    }
    return DebtPayoffResult(months: months, totalInterest: totalInterest);
  }

  /// Builds a year-by-year projection list from year 0 to [maxYears].
  /// Returns [maxYears + 1] values (index 0 = present value = 0).
  static List<double> projectionPoints(
      double monthlyContribution, double annualRate, int maxYears) {
    return List<double>.generate(
      maxYears + 1,
      (i) => i == 0 ? 0 : futureValueAnnuity(monthlyContribution, annualRate, i.toDouble()),
    );
  }
}

class DebtPayoffResult {
  final int months;
  final double totalInterest;
  const DebtPayoffResult({required this.months, required this.totalInterest});

  DateTime get payoffDate {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month + months);
  }
}
