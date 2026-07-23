import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/settings_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders SettingsScreen title and preference options', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(TestHarness.wrap(
      const SettingsScreen(),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Weight Unit'), findsOneWidget);
  });
}
