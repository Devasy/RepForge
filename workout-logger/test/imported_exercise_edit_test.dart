import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/add_custom_exercise_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

void main() {
  for (final custom in [false, true]) {
    testWidgets(
      'renaming a stretch-only exercise preserves empty resistance weights (custom: $custom)',
      (tester) async {
        final storage = MockStorageService();
        final provider = WorkoutProvider(
          storage,
          mlService: MockMLService(),
          programManager: ProgramManager(storage),
        );
        await provider.init();
        await provider.loadExtendedLibrary(
          File('../catalogues/fitify-v1.json').readAsStringSync(),
        );
        addTearDown(provider.dispose);
        if (custom) {
          await provider.addCustomExercise(
            name: 'Coach chest stretch',
            category: 'isolation',
            primaryMuscleGroupId: 'chest',
            resistanceIntensities: {},
            stretchIntensities: {'chest': 7},
          );
        }
        final exercise = custom
            ? provider.allExercises.singleWhere(
                (e) => e.name == 'Coach chest stretch',
              )
            : provider.getExercise('fitify:bo033_hurdler_stretch')!;
        expect(exercise.muscleActivations, isEmpty);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AddCustomExerciseScreen(initialExercise: exercise),
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'My hurdler stretch',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        final edited = provider.getExercise(exercise.id)!;
        expect(edited.name, 'My hurdler stretch');
        expect(edited.muscleActivations, isEmpty);
        expect(storage.lastSavedExercise!.muscleActivations, isEmpty);
        expect(provider.muscleProfileFor(exercise.id)!.stretch, isNotEmpty);
      },
    );
  }
}
