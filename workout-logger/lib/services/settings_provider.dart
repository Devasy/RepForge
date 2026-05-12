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
  String? _userName;
  String? _lastSeenVersion;

  WeightUnit get weightUnit => _weightUnit;
  double get weightIncrement => _weightIncrement;
  String get unitLabel => _weightUnit == WeightUnit.kg ? 'kg' : 'lbs';
  bool get healthConnectEnabled => _healthConnectEnabled;
  String? get userName => _userName;
  String? get lastSeenVersion => _lastSeenVersion;

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

    _userName = await _storage.getSetting('userName');
    _lastSeenVersion = await _storage.getSetting('lastSeenVersion');
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
