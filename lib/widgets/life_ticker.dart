import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/life_settings.dart';
import '../theme/app_theme.dart';


class LifeTicker extends StatefulWidget {
  final LifeSettings settings;
  const LifeTicker({super.key, required this.settings});

  @override
  State<LifeTicker> createState() => _LifeTickerState();
}

class _LifeTickerState extends State<LifeTicker> {
  late Timer _timer;
  late Duration _remaining;
  final NumberFormat _nf = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _remaining = _calcRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remaining = _calcRemaining());
    });
  }

  Duration _calcRemaining() {
    final DateTime end = widget.settings.estimatedEndDate;
    final DateTime now = DateTime.now();
    return now.isAfter(end) ? Duration.zero : end.difference(now);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int days = _remaining.inDays;
    final int hours = _remaining.inHours % 24;
    final int minutes = _remaining.inMinutes % 60;
    final int seconds = _remaining.inSeconds % 60;

    return Column(
      children: <Widget>[
        Text(
          _nf.format(_remaining.inSeconds),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 38,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'seconds remaining (estimate)',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _unit(days, 'days'),
            _sep(),
            _unit(hours, 'hours'),
            _sep(),
            _unit(minutes, 'minutes'),
            _sep(),
            _unit(seconds, 'seconds'),
          ],
        ),
      ],
    );
  }

  Widget _unit(int value, String label) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _sep() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(':', style: TextStyle(color: AppColors.textMuted, fontSize: 18)),
      );
}
