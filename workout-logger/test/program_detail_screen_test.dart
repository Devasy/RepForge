import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/programs/program_detail_screen.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_storage_service.dart';

Widget createTestWidget({
  required Widget child,
  required WorkoutProvider provider,
  required SettingsProvider settingsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: provider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('ProgramDetailScreen Widget Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;
    late SettingsProvider settingsProvider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(
        mockStorage,
        programManager: ProgramManager(mockStorage),
      );
      settingsProvider = SettingsProvider(mockStorage);
      await provider.init();
      await settingsProvider.init();
    });

    testWidgets('resume uses active workout program context', (
      WidgetTester tester,
    ) async {
      final resumeDay = ProgramDay(
        id: 'resume_day',
        name: 'Resume Day',
        exercises: [
          ProgramExerciseSlot(
            exerciseId: 'bench_press',
            sets: 4,
            minReps: 6,
            maxReps: 6,
            restSeconds: 120,
          ),
        ],
      );
      final resumeWeek = ProgramWeek(weekNumber: 2, days: [resumeDay]);

      final tappedDay = ProgramDay(
        id: 'tapped_day',
        name: 'Tapped Day',
        exercises: [
          ProgramExerciseSlot(
            exerciseId: 'squat',
            sets: 2,
            minReps: 12,
            maxReps: 12,
            restSeconds: 45,
          ),
        ],
      );
      final tappedWeek = ProgramWeek(weekNumber: 1, days: [tappedDay]);
      final program = TrainingProgram(
        id: 'program_1',
        name: 'Program Under Test',
        totalWeeks: 1,
        phases: const [],
        weeks: [tappedWeek],
      );

      provider.startWorkout(
        exerciseIds: const ['bench_press'],
        programDay: resumeDay,
        programWeek: resumeWeek,
      );

      await tester.pumpWidget(
        createTestWidget(
          child: ProgramDetailScreen(program: program),
          provider: provider,
          settingsProvider: settingsProvider,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('W1'));
      await tester.pumpAndSettle();

      final startButton = find.text('Start Tapped Day');
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(find.text('Workout already in progress'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutFlowScreen), findsOneWidget);
      expect(find.textContaining('120s rest'), findsOneWidget);
      expect(find.textContaining('45s rest'), findsNothing);
    });
  });
}
