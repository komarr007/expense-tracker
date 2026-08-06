import 'package:shared_preferences/shared_preferences.dart';
import '../models/life_settings.dart';


class LifeSettingsService {
  static const String _keyBirthDate = 'life_birth_date';
  static const String _keyExpectancy = 'life_expectancy_years';

  static const int defaultExpectancyYears = 80;

  Future<bool> hasSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyBirthDate);
  }

  Future<LifeSettings?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_keyBirthDate);
    if (raw == null) return null;
    final DateTime birthDate = DateTime.parse(raw);
    final int expectancy = prefs.getInt(_keyExpectancy) ?? defaultExpectancyYears;
    return LifeSettings(birthDate: birthDate, lifeExpectancyYears: expectancy);
  }

  Future<void> save(LifeSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBirthDate, settings.birthDate.toIso8601String());
    await prefs.setInt(_keyExpectancy, settings.lifeExpectancyYears);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBirthDate);
    await prefs.remove(_keyExpectancy);
  }
}
