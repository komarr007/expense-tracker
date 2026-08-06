import '../models/life_settings.dart';


const double kAverageHijriYearDays = 354.36;

class LifeStats {
  final Duration remaining;
  final double percentLived;
  final int remainingYears;
  final int remainingMonths;
  final int remainingWeeks;
  final int remainingDays;
  final int remainingWeekends;
  final int remainingLebarans;
  final int weeksLivedForGrid;
  final int weeksExpectedForGrid;
  final bool isPastEstimate;

  const LifeStats({
    required this.remaining,
    required this.percentLived,
    required this.remainingYears,
    required this.remainingMonths,
    required this.remainingWeeks,
    required this.remainingDays,
    required this.remainingWeekends,
    required this.remainingLebarans,
    required this.weeksLivedForGrid,
    required this.weeksExpectedForGrid,
    required this.isPastEstimate,
  });
}

class LifeCalculatorService {
  LifeStats calculate(LifeSettings settings, {DateTime? now}) {
    final DateTime today = now ?? DateTime.now();
    final DateTime end = settings.estimatedEndDate;

    final bool isPast = today.isAfter(end);
    final Duration remaining = isPast ? Duration.zero : end.difference(today);
    final int totalDays = remaining.inDays;

    final int livedDays = today.difference(settings.birthDate).inDays;
    final int totalLifeDays = end.difference(settings.birthDate).inDays;
    final double percentLived = totalLifeDays <= 0
        ? 100
        : (livedDays / totalLifeDays * 100).clamp(0, 100).toDouble();

    return LifeStats(
      remaining: remaining,
      percentLived: percentLived,
      remainingYears: (totalDays / 365.25).floor(),
      remainingMonths: (totalDays / 30.44).floor(),
      remainingWeeks: (totalDays / 7).floor(),
      remainingDays: totalDays,
      remainingWeekends: (totalDays / 7).floor() * 2,
      remainingLebarans: (totalDays / kAverageHijriYearDays).floor(),
      weeksLivedForGrid: (livedDays / 7).floor().clamp(0, 1 << 30),
      weeksExpectedForGrid: (totalLifeDays / 7).ceil().clamp(1, 1 << 30),
      isPastEstimate: isPast,
    );
  }
}
