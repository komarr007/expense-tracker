import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/life_settings.dart';
import '../services/life_calculator_service.dart';
import '../services/life_settings_service.dart';
import '../services/home_widget_service.dart';
import '../theme/app_theme.dart';
import '../widgets/life_stat_card.dart';
import '../widgets/life_ticker.dart';
import '../widgets/life_weeks_grid.dart';

class LifeCountdownScreen extends StatefulWidget {
  const LifeCountdownScreen({super.key});

  @override
  State<LifeCountdownScreen> createState() => _LifeCountdownScreenState();
}

class _LifeCountdownScreenState extends State<LifeCountdownScreen> with WidgetsBindingObserver {
  final LifeSettingsService _settingsService = LifeSettingsService();
  final LifeCalculatorService _calculator = LifeCalculatorService();
  final HomeWidgetService _homeWidget = HomeWidgetService();

  LifeSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settings != null) {
      _pushToHomeWidget(_settings!);
    }
  }

  Future<void> _load() async {
    final LifeSettings? s = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loading = false;
    });
    if (s != null) _pushToHomeWidget(s);
  }

  Future<void> _pushToHomeWidget(LifeSettings settings) async {
    final LifeStats stats = _calculator.calculate(settings);
    await _homeWidget.update(stats);
  }

  Future<void> _saveSettings(LifeSettings settings) async {
    await _settingsService.save(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
    await _pushToHomeWidget(settings);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Countdown'),
        actions: <Widget>[
          if (_settings != null)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => _openSettingsSheet(existing: _settings),
            ),
        ],
      ),
      body: SafeArea(
        child: _settings == null
            ? _OnboardingForm(onSubmit: _saveSettings)
            : _Dashboard(settings: _settings!, calculator: _calculator),
      ),
    );
  }

  void _openSettingsSheet({LifeSettings? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _OnboardingForm(
          embedded: true,
          existing: existing,
          onSubmit: (LifeSettings s) {
            Navigator.pop(ctx);
            _saveSettings(s);
          },
        ),
      ),
    );
  }
}

class _OnboardingForm extends StatefulWidget {
  final ValueChanged<LifeSettings> onSubmit;
  final LifeSettings? existing;
  final bool embedded;

  const _OnboardingForm({required this.onSubmit, this.existing, this.embedded = false});

  @override
  State<_OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends State<_OnboardingForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _dobCtrl = TextEditingController();
  final TextEditingController _expectancyCtrl = TextEditingController();
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _dob = widget.existing!.birthDate;
      _dobCtrl.text = DateFormat('d MMMM yyyy').format(_dob!);
      _expectancyCtrl.text = widget.existing!.lifeExpectancyYears.toString();
    } else {
      _expectancyCtrl.text = LifeSettingsService.defaultExpectancyYears.toString();
    }
  }

  @override
  void dispose() {
    _dobCtrl.dispose();
    _expectancyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      builder: (BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent, onPrimary: Colors.white,
            surface: AppColors.card, onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = DateFormat('d MMMM yyyy').format(picked);
      });
    }
  }

  void _submit() {
    if (!_form.currentState!.validate() || _dob == null) return;
    widget.onSubmit(LifeSettings(
      birthDate: _dob!,
      lifeExpectancyYears: int.parse(_expectancyCtrl.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!widget.embedded) ...<Widget>[
              const Text(
                'Life Countdown',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hope when you count your days, you’ll find a life well spent. — Abraham Lincoln',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
            ],
            _label('Date of Birth'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _dobCtrl,
              readOnly: true,
              onTap: _pickDob,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Select birth date',
                prefixIcon: Icon(Icons.cake_outlined, size: 20, color: AppColors.textMuted),
              ),
              validator: (String? v) => (v == null || v.isEmpty) ? 'Birth date is required' : null,
            ),
            const SizedBox(height: 16),
            _label('Estimated Life Expectancy (years)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _expectancyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: '80',
                prefixIcon: Icon(Icons.favorite_border_rounded, size: 20, color: AppColors.textMuted),
              ),
              validator: (String? v) {
                final int? n = int.tryParse(v ?? '');
                if (n == null || n <= 0 || n > 130) return 'Please enter a valid age (1-130)';
                return null;
              },
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.hourglass_bottom_rounded),
              label: Text(widget.existing != null ? 'Update' : 'Start Counting'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) =>
      Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500));
}

class _Dashboard extends StatelessWidget {
  final LifeSettings settings;
  final LifeCalculatorService calculator;

  const _Dashboard({required this.settings, required this.calculator});

  @override
  Widget build(BuildContext context) {
    final LifeStats stats = calculator.calculate(settings);

    if (stats.isPastEstimate) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'You have exceeded your estimated life expectancy of ${settings.lifeExpectancyYears} years. '
            'Good — it means you have extra time. Perhaps it\'s time to update your estimate in the settings (icon in the top right).',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: LifeTicker(settings: settings),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.percentLived / 100,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.percentLived.toStringAsFixed(1)}% of your estimated life expectancy has passed',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: <Widget>[
              LifeStatCard(icon: Icons.calendar_today_rounded, value: '${stats.remainingYears}', label: 'Years Remaining'),
              LifeStatCard(icon: Icons.view_week_rounded, value: '${stats.remainingWeeks}', label: 'Weeks Remaining'),
              LifeStatCard(icon: Icons.mosque_rounded, value: '${stats.remainingLebarans}', label: 'Eid Celebrations Remaining (Estimate)'),
              LifeStatCard(icon: Icons.weekend_rounded, value: '${stats.remainingWeekends}', label: 'Weekends Remaining (Estimate)'),
            ],
          ),
          const SizedBox(height: 28),
          LifeWeeksGrid(weeksLived: stats.weeksLivedForGrid, weeksExpected: stats.weeksExpectedForGrid),
        ],
      ),
    );
  }
}
