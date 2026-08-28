import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/settings_provider.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('SettingsProvider', () {
    late MockStorageService mockStorage;
    late SettingsProvider provider;

    setUp(() {
      mockStorage = MockStorageService();
      provider = SettingsProvider(mockStorage);
    });

    test('initial values and fallback defaults before init', () {
      expect(provider.weightUnit, equals(WeightUnit.kg));
      expect(provider.unitLabel, equals('kg'));
      expect(provider.weightIncrement, equals(2.5));
      expect(provider.healthConnectEnabled, isFalse);
      expect(provider.readinessEnabled, isFalse);
      expect(provider.userName, isNull);
      expect(provider.geminiApiKey, isEmpty);
      expect(provider.geminiModel, equals('gemini-3.6-flash'));
      expect(provider.geminiThinkingLevel, equals('minimal'));
      expect(provider.showAdvancedMetrics, isFalse);
    });

    test('init loads saved settings from storage', () async {
      await mockStorage.saveSetting('weightUnit', 'lbs');
      await mockStorage.saveSetting('weightIncrement', '5.0');
      await mockStorage.saveSetting('healthConnectEnabled', 'true');
      await mockStorage.saveSetting('readinessEnabled', 'true');
      await mockStorage.saveSetting('userName', 'Devasy');
      await mockStorage.saveSetting('geminiApiKey', 'secret_key');
      await mockStorage.saveSetting('geminiModel', 'gemini-1.5-pro');
      await mockStorage.saveSetting('geminiThinkingLevel', 'high');
      await mockStorage.saveSetting('showAdvancedMetrics', 'true');

      await provider.init();

      expect(provider.weightUnit, equals(WeightUnit.lbs));
      expect(provider.unitLabel, equals('lbs'));
      expect(provider.weightIncrement, equals(5.0));
      expect(provider.healthConnectEnabled, isTrue);
      expect(provider.readinessEnabled, isTrue);
      expect(provider.userName, equals('Devasy'));
      expect(provider.geminiApiKey, equals('secret_key'));
      expect(provider.geminiModel, equals('gemini-1.5-pro'));
      expect(provider.geminiThinkingLevel, equals('high'));
      expect(provider.showAdvancedMetrics, isTrue);
    });

    test('init clamps a stored thinking level that the stored model no longer supports', () async {
      await mockStorage.saveSetting('geminiModel', 'gemini-3.7-flash');
      await mockStorage.saveSetting('geminiThinkingLevel', 'minimal');

      await provider.init();

      expect(provider.geminiThinkingLevel, equals('low'));
    });

    test('setUserName updates state and notifies listeners', () async {
      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.setUserName('  John Doe  ');

      expect(provider.userName, equals('John Doe'));
      expect(mockStorage.settings['userName'], equals('John Doe'));
      expect(notified, isTrue);
    });

    test('setWeightUnit updates weightUnit, default increment, and saves settings', () async {
      await provider.setWeightUnit(WeightUnit.lbs);

      expect(provider.weightUnit, equals(WeightUnit.lbs));
      expect(provider.unitLabel, equals('lbs'));
      expect(provider.weightIncrement, equals(5.0));
      expect(mockStorage.settings['weightUnit'], equals('lbs'));
      expect(mockStorage.settings['weightIncrement'], equals('5.0'));

      await provider.setWeightUnit(WeightUnit.kg);

      expect(provider.weightUnit, equals(WeightUnit.kg));
      expect(provider.unitLabel, equals('kg'));
      expect(provider.weightIncrement, equals(2.5));
    });

    test('weight conversions and formatting for kg and lbs', () async {
      // In kg mode
      expect(provider.toDisplay(100.0), equals(100.0));
      expect(provider.toStorage(100.0), equals(100.0));
      expect(provider.formatWeight(100.0), equals('100 kg'));
      expect(provider.formatWeight(102.5), equals('102.5 kg'));

      // Switch to lbs mode
      await provider.setWeightUnit(WeightUnit.lbs);

      expect(provider.toDisplay(100.0), closeTo(220.462, 0.01));
      expect(provider.toStorage(220.462), closeTo(100.0, 0.01));
      expect(provider.formatWeight(100.0), equals('220.5 lbs'));
    });

    test('setters for healthConnect, readiness, gemini, and advanced metrics', () async {
      await provider.setHealthConnectEnabled(true);
      expect(provider.healthConnectEnabled, isTrue);
      expect(mockStorage.settings['healthConnectEnabled'], equals('true'));

      await provider.setReadinessEnabled(true);
      expect(provider.readinessEnabled, isTrue);
      expect(mockStorage.settings['readinessEnabled'], equals('true'));

      await provider.setGeminiApiKey('key123');
      expect(provider.geminiApiKey, equals('key123'));

      await provider.setGeminiModel('custom-model');
      expect(provider.geminiModel, equals('custom-model'));

      await provider.setGeminiThinkingLevel('high');
      expect(provider.geminiThinkingLevel, equals('high'));
      expect(mockStorage.settings['geminiThinkingLevel'], equals('high'));

      await provider.setShowAdvancedMetrics(true);
      expect(provider.showAdvancedMetrics, isTrue);
    });

    test('setGeminiModel clamps an already-set thinking level the new model does not support', () async {
      await provider.setGeminiThinkingLevel('minimal');
      await provider.setGeminiModel('gemini-3.7-flash');

      expect(provider.geminiThinkingLevel, equals('low'));
      expect(mockStorage.settings['geminiThinkingLevel'], equals('low'));
    });

    test('saveWeeklyInsights updates insights string and date', () async {
      await provider.saveWeeklyInsights('Great progress this week!');

      expect(provider.weeklyInsights, equals('Great progress this week!'));
      expect(provider.weeklyInsightsDate, isNotNull);
      expect(mockStorage.settings['weeklyInsights'], equals('Great progress this week!'));
    });

    test('availableIncrements returns correct values for unit', () async {
      expect(provider.availableIncrements, equals([1.25, 2.5, 5.0, 10.0]));

      await provider.setWeightUnit(WeightUnit.lbs);
      expect(provider.availableIncrements, equals([2.5, 5.0, 10.0, 25.0]));
    });
  });
}
