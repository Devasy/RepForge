import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/exercise_muscle_map.dart';
import 'package:repforge/screens/widgets/body_heatmap.dart';
import 'package:repforge/services/extended_exercise_library.dart';

void main() {
  testWidgets('source map fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: ExerciseMuscleMap(
                exercise: Exercise(
                  id: 'bench_press',
                  name: 'Bench Press',
                  muscleActivations: [],
                  category: 'compound',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  const exercise = Exercise(
    id: 'sample',
    name: 'Sample',
    muscleActivations: [],
    category: 'other',
  );
  const profile = MuscleIntensityProfile(
    code: 'sample',
    name: 'Source example',
    sourceVersion: '1.136.0',
    exerciseType: ExerciseType.weightAndReps,
    resistance: {'biceps': 8, 'forearm_anterior': 3},
    stretch: {'chest': 4},
  );
  Widget page(MuscleIntensityProfile value) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ExerciseMuscleMap(exercise: exercise, profile: value),
      ),
    ),
  );

  testWidgets(
    'switches actual score datasets rather than recolouring the same muscles',
    (tester) async {
      await tester.pumpWidget(page(profile));
      expect(find.text('Biceps'), findsOneWidget);
      expect(find.text('8/10'), findsOneWidget);
      expect(
        tester.widget<MuscleBodyMap>(find.byType(MuscleBodyMap)).muscleVolumes,
        {'biceps': .8, 'forearm_anterior': .3},
      );
      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();
      expect(find.text('Biceps'), findsNothing);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('4/10'), findsOneWidget);
      expect(
        tester.widget<MuscleBodyMap>(find.byType(MuscleBodyMap)).muscleVolumes,
        {'chest': .4},
      );
      expect(find.textContaining('%'), findsNothing);
    },
  );

  testWidgets(
    'stretch-only data starts on stretch without inventing resistance',
    (tester) async {
      await tester.pumpWidget(
        page(
          const MuscleIntensityProfile(
            code: 'stretch',
            name: 'Stretch',
            sourceVersion: '1.136.0',
            exerciseType: ExerciseType.timeBased,
            resistance: {},
            stretch: {'hamstrings': 7},
          ),
        ),
      );
      expect(find.text('Hamstrings'), findsOneWidget);
      expect(find.text('7/10'), findsOneWidget);
      expect(find.text('0/10'), findsNothing);
    },
  );

  testWidgets('empty source scores have an explicit unavailable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        const MuscleIntensityProfile(
          code: 'empty',
          name: 'Empty',
          sourceVersion: '1.136.0',
          exerciseType: ExerciseType.timeBased,
          resistance: {},
          stretch: {},
        ),
      ),
    );
    expect(
      find.text('No source muscle scores available for this exercise.'),
      findsOneWidget,
    );
    expect(find.byType(MuscleBodyMap), findsNothing);
  });
}
