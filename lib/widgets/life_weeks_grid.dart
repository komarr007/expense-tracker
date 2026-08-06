import 'package:flutter/material.dart';
import '../theme/app_theme.dart';


class LifeWeeksGrid extends StatelessWidget {
  final int weeksLived;
  final int weeksExpected;

  const LifeWeeksGrid({
    super.key,
    required this.weeksLived,
    required this.weeksExpected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Your Age in Weeks',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        const Text(
          'Each dot = 1 week. Lighter dots = already passed.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List<Widget>.generate(weeksExpected, (int i) {
            final bool lived = i < weeksLived;
            return Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lived ? AppColors.accent : AppColors.divider,
              ),
            );
          }),
        ),
      ],
    );
  }
}
