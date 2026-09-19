import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/exercise_details_sheet.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';

import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/test_harness.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider provider;
  late SettingsProvider settings;

  setUp(() async {
    storage = MockStorageService();
    settings = SettingsProvider(storage);
    provider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    await provider.init();
  });

  Widget buildSheet(Exercise exercise) {
    return TestHarness.wrap(
      Scaffold(
        body: ExerciseDetailsSheet(
          exercise: exercise,
          provider: provider,
        ),
      ),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: provider,
    );
  }

  group('ExerciseDetailsSheet Widget Tests', () {
    testWidgets('renders time-based exercise with available attachments, type chip, and edit button', (tester) async {
      final exercise = Exercise(
        id: 'plank_weighted',
        name: 'Weighted Plank',
        category: 'isometric',
        isCustom: true,
        exerciseType: ExerciseType.timeBased,
        availableHandles: ['Standard', 'Elevated Feet'],
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'abs', activationPercentage: 80),
          MuscleActivation(muscleGroupId: 'obliques', activationPercentage: 20),
        ],
      );

      await tester.pumpWidget(buildSheet(exercise));
      await tester.pumpAndSettle();

      expect(find.text('Weighted Plank'), findsOneWidget);
      expect(find.text('Time-Based'), findsOneWidget);
      expect(find.text('AVAILABLE ATTACHMENTS'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Elevated Feet'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
    });

    testWidgets('formats last session time-based sets with duration and optional weight', (tester) async {
      final exercise = Exercise(
        id: 'plank',
        name: 'Plank',
        category: 'isometric',
        isCustom: false,
        exerciseType: ExerciseType.timeBased,
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'abs', activationPercentage: 100),
        ],
      );

      // Add a session with a time-based set (60s with 10kg weight)
      final session = WorkoutSession(
        id: 's_plank',
        date: DateTime.now(),
        duration: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'plank',
            sets: [
              WorkoutSet(
                weight: 10.0,
                reps: 0,
                timeTaken: 60,
                timestamp: DateTime.now(),
              ),
              WorkoutSet(
                weight: 0.0,
                reps: 0,
                timeTaken: 45,
                timestamp: DateTime.now(),
              ),
            ],
          ),
        ],
      );
      await storage.saveWorkoutSession(session);
      await provider.init();

      await tester.pumpWidget(buildSheet(exercise));
      await tester.pumpAndSettle();

      // Check formatted duration text
      expect(find.textContaining('60s (+10kg)'), findsOneWidget);
      expect(find.text('45s'), findsOneWidget);
    });
  });
}
