import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/exercise_input_section.dart';
import 'package:repforge/screens/widgets/time_exercise_card.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/theme/app_theme.dart';

import '../../test_utils/mock_storage_service.dart';

void main() {
  late SettingsProvider settings;

  setUp(() async {
    settings = SettingsProvider(MockStorageService());
    await settings.init();
  });

  Widget buildSection({
    bool isTimeBased = false,
    int durationSeconds = 45,
    List<SetRecommendation> recommendations = const [],
    List<WorkoutSet> previousSets = const [],
    WorkoutSession? lastSession,
    ValueChanged<int>? onDurationChanged,
    ValueChanged<double>? onWeightChanged,
    ValueChanged<int>? onRepsChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 1200,
          child: SingleChildScrollView(
            child: IntrinsicHeight(
              child: ExerciseInputSection(
                contentWidth: 360,
                currentWeight: 10.0,
                currentReps: 10,
                isDropset: false,
                drops: const [],
                mainWeightController: TextEditingController(),
                mainRepsController: TextEditingController(),
                dropWeightControllers: const [],
                dropRepsControllers: const [],
                recommendations: recommendations,
                previousSets: previousSets,
                lastSession: lastSession != null && lastSession.exercises.isNotEmpty ? lastSession.exercises.first : null,
                settings: settings,
                onWeightChanged: onWeightChanged ?? (_) {},
                onRepsChanged: onRepsChanged ?? (_) {},
                onDropsetToggled: (_) {},
                onDropAdded: () {},
                onDropRemoved: (_) {},
                onDropWeightChanged: (_, _) {},
                onDropRepsChanged: (_, _) {},
                onApplyRecommendation: () {},
                isTimeBased: isTimeBased,
                durationSeconds: durationSeconds,
                onDurationChanged: onDurationChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ExerciseInputSection Time-Based Tests', () {
    testWidgets('renders TimeExerciseCard when isTimeBased is true', (tester) async {
      await tester.pumpWidget(
        buildSection(
          isTimeBased: true,
          durationSeconds: 60,
          onDurationChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimeExerciseCard), findsOneWidget);
      expect(find.text('REPS'), findsNothing);
    });

    testWidgets('renders recommendation card with target duration and reasoning', (tester) async {
      final rec = SetRecommendation(
        weight: 0,
        reps: 0,
        targetDuration: 45,
        confidence: 'high',
        reasoning: 'Aim for 45s hold',
      );

      await tester.pumpWidget(
        buildSection(
          isTimeBased: true,
          durationSeconds: 30,
          recommendations: [rec],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45s hold'), findsOneWidget);
      expect(find.text('Aim for 45s hold'), findsOneWidget);
    });

    testWidgets('renders recommendation card with weighted hold duration', (tester) async {
      final rec = SetRecommendation(
        weight: 15.0,
        reps: 0,
        targetDuration: 60,
        confidence: 'high',
        reasoning: 'Progress to 15kg hold',
      );

      await tester.pumpWidget(
        buildSection(
          isTimeBased: true,
          durationSeconds: 30,
          recommendations: [rec],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('15 kg × 60s hold'), findsOneWidget);
      expect(find.text('Progress to 15kg hold'), findsOneWidget);
    });

    testWidgets('renders previousSets and lastSession with time-based duration chips', (tester) async {
      final prevSet1 = WorkoutSet(weight: 0, reps: 0, timeTaken: 50);
      final prevSet2 = WorkoutSet(weight: 10, reps: 0, timeTaken: 40);

      final lastSession = WorkoutSession(
        id: 'last_s',
        date: DateTime.now().subtract(const Duration(days: 2)),
        duration: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'test_ex',
            sets: [
              WorkoutSet(weight: 0, reps: 0, timeTaken: 55),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        buildSection(
          isTimeBased: true,
          durationSeconds: 60,
          previousSets: [prevSet1, prevSet2],
          lastSession: lastSession,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('50s'), findsOneWidget);
      expect(find.text('10 × 40s'), findsOneWidget);
      expect(find.text('55s'), findsOneWidget);
    });
  });
}
