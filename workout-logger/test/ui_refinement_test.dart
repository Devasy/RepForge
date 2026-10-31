import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/analytics_screen.dart';
import 'package:repforge/screens/home_screen.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/theme/app_theme.dart';

import 'test_utils/mock_ml_service.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/test_fixtures.dart';
import 'test_utils/test_harness.dart';

void main() {
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final analytics in [false, true]) {
        testWidgets(
          '${analytics ? "Analytics" : "Home"} at ${width}px with ${scale}x text',
          (tester) async {
            final size = Size(width, 900);
            await TestHarness.prepareTester(tester, size: size);
            final storage = MockStorageService();
            storage.addMockSession(
              TestFixtures.sampleSession(date: DateTime.now()),
            );
            final settings = SettingsProvider(storage);
            await settings.init();
            final workout = WorkoutProvider(
              storage,
              mlService: MockMLService(),
              programManager: ProgramManager(storage),
            );
            await workout.init();
            addTearDown(workout.dispose);
            addTearDown(settings.dispose);
            await tester.pumpWidget(
              TestHarness.wrap(
                Builder(
                  builder: (context) => Theme(
                    data: AppTheme.darkTheme,
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: analytics
                          ? const AnalyticsScreen()
                          : const HomeScreen(),
                    ),
                  ),
                ),
                storage: storage,
                workoutProvider: workout,
                settingsProvider: settings,
                viewportSize: size,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (analytics) {
              await tester.tap(find.text('4W'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            } else {
              expect(find.text('Training'), findsOneWidget);
              expect(find.text('/ 5 goal'), findsNothing);
              await tester.ensureVisible(find.text('min · last 1 workout'));
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
