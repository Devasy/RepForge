import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/settings_screen.dart';
import 'package:repforge/services/api_service.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';

Widget _buildTestApp({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required ApiService apiService,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStorageService mockStorage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;
  late ApiService apiService;

  setUp(() async {
    mockStorage = MockStorageService();
    workoutProvider = WorkoutProvider(
      mockStorage,
      programManager: ProgramManager(mockStorage),
    );
    settingsProvider = SettingsProvider(mockStorage);
    apiService = ApiService();

    await workoutProvider.init();
    await settingsProvider.init();
  });

  group('Userflow 4: Settings & Storage Flow', () {
    testWidgets('SettingsScreen renders title, section headers, and unit options', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        apiService: apiService,
        child: const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
    });

    testWidgets('Toggling weight unit in SettingsProvider persists to storage and updates display label', (tester) async {
      expect(settingsProvider.weightUnit, equals(WeightUnit.kg));
      expect(settingsProvider.unitLabel, equals('kg'));

      await settingsProvider.setWeightUnit(WeightUnit.lbs);
      expect(settingsProvider.weightUnit, equals(WeightUnit.lbs));
      expect(settingsProvider.unitLabel, equals('lbs'));
      expect(mockStorage.settings['weightUnit'], equals('lbs'));

      await settingsProvider.setWeightIncrement(5.0);
      expect(settingsProvider.weightIncrement, equals(5.0));
      expect(mockStorage.settings['weightIncrement'], equals('5.0'));
    });
  });
}
