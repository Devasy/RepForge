import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/history_screen.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_ml_service.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/test_harness.dart';

void main() {
  for (final importedTitle in ['Morning training', '', '   ']) {
    final displayedTitle = importedTitle.trim().isEmpty
        ? 'Saved workout'
        : importedTitle;
    testWidgets('summary-only import title "$importedTitle" is searchable', (
      tester,
    ) async {
      await TestHarness.prepareTester(tester, size: const Size(800, 1800));
      final storage = MockStorageService();
      await storage.saveWorkoutSession(
        WorkoutSession(
          id: 'summary-import',
          date: DateTime.now(),
          duration: 20,
          exercises: [],
          importSource: {
            'origin': 'another.app',
            'rawRecord': {'title': importedTitle},
          },
        ),
      );
      final history = HistoryManager(storage);
      await history.loadSessions();
      final workout = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
        historyManager: history,
      );
      await workout.init();
      await tester.pumpWidget(
        TestHarness.wrap(
          const Scaffold(body: HistoryScreen()),
          storage: storage,
          workoutProvider: workout,
          historyManager: history,
          viewportSize: const Size(800, 1800),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(displayedTitle), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        displayedTitle.toUpperCase(),
      );
      await tester.pumpAndSettle();
      expect(find.text(displayedTitle), findsOneWidget);
      expect(find.text('No results'), findsNothing);

      await tester.enterText(find.byType(TextField), 'unmatched title');
      await tester.pumpAndSettle();
      expect(find.text(displayedTitle), findsNothing);
      expect(find.text('No results'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
