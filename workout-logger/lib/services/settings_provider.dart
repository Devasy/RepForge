// Settings Provider - User preferences (weight unit, increments, user profile)

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'interfaces/storage_service_interface.dart';

enum WeightUnit { kg, lbs }

class SettingsProvider extends ChangeNotifier {
  final IStorageService _storage;

  WeightUnit _weightUnit = WeightUnit.kg;
  double _weightIncrement = 2.5;
  bool _healthConnectEnabled = false;
  bool _readinessEnabled = false;
  String? _userName;
  String? _lastSeenVersion;
  String _geminiApiKey = '';
  String _geminiModel = 'gemini-2.5-flash';
  String _weeklyInsights = '';
  DateTime? _weeklyInsightsDate;
  bool _showAdvancedMetrics = false;

  WeightUnit get weightUnit => _weightUnit;
  double get weightIncrement => _weightIncrement;
  String get unitLabel => _weightUnit == WeightUnit.kg ? 'kg' : 'lbs';
  bool get healthConnectEnabled => _healthConnectEnabled;
  bool get readinessEnabled => _readinessEnabled;
  String? get userName => _userName;
  String? get lastSeenVersion => _lastSeenVersion;
  String get geminiApiKey => _geminiApiKey;
  String get geminiModel => _geminiModel;
  String get weeklyInsights => _weeklyInsights;
  DateTime? get weeklyInsightsDate => _weeklyInsightsDate;
  bool get showAdvancedMetrics => _showAdvancedMetrics;

  SettingsProvider(this._storage);

  Future<void> init() async {
    final unit = await _storage.getSetting('weightUnit');
    _weightUnit = unit == 'lbs' ? WeightUnit.lbs : WeightUnit.kg;

    final increment = await _storage.getSetting('weightIncrement');
    _weightIncrement = increment != null
        ? (double.tryParse(increment) ?? _defaultIncrement)
        : _defaultIncrement;

    final hcEnabled = await _storage.getSetting('healthConnectEnabled');
    _healthConnectEnabled = hcEnabled == 'true';

    final readiness = await _storage.getSetting('readinessEnabled');
    _readinessEnabled = readiness == 'true';

    _userName = await _storage.getSetting('userName');
    _lastSeenVersion = await _storage.getSetting('lastSeenVersion');
    _geminiApiKey = await _storage.getSetting('geminiApiKey') ?? '';
    _geminiModel = await _storage.getSetting('geminiModel') ?? 'gemini-2.5-flash';
    _weeklyInsights = await _storage.getSetting('weeklyInsights') ?? '';
    final dateStr = await _storage.getSetting('weeklyInsightsDate');
    _weeklyInsightsDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final advMetrics = await _storage.getSetting('showAdvancedMetrics');
    _showAdvancedMetrics = advMetrics == 'true';
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    await _storage.saveSetting('userName', _userName!);
    notifyListeners();
  }

  Future<void> markVersionSeen(String version) async {
    _lastSeenVersion = version;
    await _storage.saveSetting('lastSeenVersion', version);
    notifyListeners();
  }

  /// Returns the current app version string (e.g. "1.0.19").
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return 'unknown';
    }
  }

  double get _defaultIncrement => _weightUnit == WeightUnit.kg ? 2.5 : 5.0;

  Future<void> setWeightUnit(WeightUnit unit) async {
    _weightUnit = unit;
    _weightIncrement = _defaultIncrement;
    await _storage.saveSetting('weightUnit', unit == WeightUnit.kg ? 'kg' : 'lbs');
    await _storage.saveSetting('weightIncrement', _weightIncrement.toString());
    notifyListeners();
  }

  Future<void> setWeightIncrement(double increment) async {
    _weightIncrement = increment;
    await _storage.saveSetting('weightIncrement', increment.toString());
    notifyListeners();
  }

  Future<void> setHealthConnectEnabled(bool enabled) async {
    _healthConnectEnabled = enabled;
    await _storage.saveSetting('healthConnectEnabled', enabled.toString());
    notifyListeners();
  }

  Future<void> setReadinessEnabled(bool enabled) async {
    _readinessEnabled = enabled;
    await _storage.saveSetting('readinessEnabled', enabled.toString());
    notifyListeners();
  }

  Future<void> setGeminiModel(String model) async {
    _geminiModel = model;
    await _storage.saveSetting('geminiModel', model);
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String key) async {
    _geminiApiKey = key.trim();
    await _storage.saveSetting('geminiApiKey', _geminiApiKey);
    notifyListeners();
  }

  Future<void> setShowAdvancedMetrics(bool value) async {
    _showAdvancedMetrics = value;
    await _storage.saveSetting('showAdvancedMetrics', value.toString());
    notifyListeners();
  }

  Future<void> saveWeeklyInsights(String insights) async {
    _weeklyInsights = insights;
    _weeklyInsightsDate = DateTime.now();
    await _storage.saveSetting('weeklyInsights', insights);
    await _storage.saveSetting(
      'weeklyInsightsDate',
      _weeklyInsightsDate!.toIso8601String(),
    );
    notifyListeners();
  }

  /// Convert from internal kg storage to display unit.
  double toDisplay(double kg) {
    if (_weightUnit == WeightUnit.lbs) return kg * 2.20462;
    return kg;
  }

  /// Convert from display unit back to kg for storage.
  double toStorage(double display) {
    if (_weightUnit == WeightUnit.lbs) return display / 2.20462;
    return display;
  }

  /// Format a kg weight value with the correct unit label.
  String formatWeight(double kg) {
    final d = toDisplay(kg);
    final str = d == d.truncateToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
    return '$str $unitLabel';
  }

  /// Available weight increments for the current unit.
  List<double> get availableIncrements => _weightUnit == WeightUnit.kg
      ? [1.25, 2.5, 5.0, 10.0]
      : [2.5, 5.0, 10.0, 25.0];
}
