import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/session_details_sheet.dart';
import 'package:repforge/screens/workout_summary_screen.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStorageService mockStorage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;

  setUp(() async {
    mockStorage = MockStorageService();
    workoutProvider = WorkoutProvider(
      mockStorage,
      programManager: ProgramManager(mockStorage),
    );
    settingsProvider = SettingsProvider(mockStorage);

    await workoutProvider.init();
    await settingsProvider.init();
  });

  group('WorkoutSummaryScreen time-based display tests', () {
    testWidgets('zero-load timed sets display hold duration and not derived volume as weight', (tester) async {
      final session = WorkoutSession(
        id: 's_zero_load',
        date: DateTime.now(),
        duration: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'plank',
            sets: [
              WorkoutSet(weight: 0, reps: 0, timeTaken: 60),
            ],
          ),
        ],
      );

      await tester.pumpWidget(TestHarness.wrap(
        Scaffold(
          body: WorkoutSummaryScreen(session: session),
        ),
        storage: mockStorage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      ));
      await tester.pumpAndSettle();

      // Right-hand metric should show '1m' for the hold duration, not '60 kg'
      expect(find.text('1m'), findsWidgets);
      expect(find.text('60 kg'), findsNothing);
    });

    testWidgets('weighted timed sets display weight volume and unit', (tester) async {
      final session = WorkoutSession(
        id: 's_weighted_hold',
        date: DateTime.now(),
        duration: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'weighted_plank',
            sets: [
              WorkoutSet(weight: 10, reps: 0, timeTaken: 60),
            ],
          ),
        ],
      );

      await tester.pumpWidget(TestHarness.wrap(
        Scaffold(
          body: WorkoutSummaryScreen(session: session),
        ),
        storage: mockStorage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      ));
      await tester.pumpAndSettle();

      // 10kg * 60s = 600kg volume
      expect(find.text('600 kg'), findsOneWidget);
    });
  });

  group('SessionDetailsSheet time-based display tests', () {
    testWidgets('zero-load timed sets do not append derived volume in total row', (tester) async {
      final session = WorkoutSession(
        id: 's_zero_details',
        date: DateTime.now(),
        duration: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'plank',
            sets: [
              WorkoutSet(weight: 0, reps: 0, timeTaken: 60),
            ],
          ),
        ],
      );

      await tester.pumpWidget(TestHarness.wrap(
        Scaffold(
          body: SessionDetailsSheet(
            session: session,
            provider: workoutProvider,
            scrollController: ScrollController(),
            onEdit: () {},
            onDelete: () {},
          ),
        ),
        storage: mockStorage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Total Hold '), findsOneWidget);
      expect(find.text('1m'), findsWidgets);
      // Ensure it does not append '· 60 kg'
      expect(find.textContaining('· 60 kg'), findsNothing);
    });

    testWidgets('weighted timed sets append derived volume in total row', (tester) async {
      final session = WorkoutSession(
        id: 's_weighted_details',
        date: DateTime.now(),
        duration: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'weighted_plank',
            sets: [
              WorkoutSet(weight: 10, reps: 0, timeTaken: 60),
            ],
          ),
        ],
      );

      await tester.pumpWidget(TestHarness.wrap(
        Scaffold(
          body: SessionDetailsSheet(
            session: session,
            provider: workoutProvider,
            scrollController: ScrollController(),
            onEdit: () {},
            onDelete: () {},
          ),
        ),
        storage: mockStorage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Total Hold '), findsOneWidget);
      expect(find.text('1m · 600 kg'), findsOneWidget);
    });
  });
}
