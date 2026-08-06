import 'package:home_widget/home_widget.dart';
import 'life_calculator_service.dart';

class HomeWidgetService {
  static const String androidWidgetName = 'LifeCountdownWidgetProvider';

  Future<void> update(LifeStats stats) async {
    await HomeWidget.saveWidgetData<int>('remaining_days', stats.remainingDays);
    await HomeWidget.saveWidgetData<int>('remaining_years', stats.remainingYears);
    await HomeWidget.saveWidgetData<int>('remaining_weeks', stats.remainingWeeks);
    await HomeWidget.saveWidgetData<double>('percent_lived', stats.percentLived);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }
}
