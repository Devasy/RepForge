import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/exercise_animations.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/screens/widgets/exercise_movement_painter.dart';
import 'package:repforge/theme/app_theme.dart';
import 'test_utils/animation_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAnimationFonts);
  testWidgets('catalogue start and end poses visual regression', (
    tester,
  ) async {
    final exercises = ExerciseDatabase.getAll();
    final rows = (exercises.length / 4).ceil();
    tester.view.physicalSize = Size(1440, rows * 176);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Column(
            children: [
              for (var row = 0; row < rows; row++)
                Row(
                  children: [
                    for (final exercise in exercises.skip(row * 4).take(4))
                      SizedBox(
                        width: 360,
                        height: 176,
                        child: Column(
                          children: [
                            Text(
                              exercise.name,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                for (final amount in [0.0, 1.0])
                                  SizedBox(
                                    width: 180,
                                    height: 140,
                                    child: CustomPaint(
                                      painter: ExerciseMovementPainter(
                                        animation:
                                            ExerciseAnimation.forExercise(
                                              exercise,
                                            )!,
                                        amount: amount,
                                        muscleColor: AppColors.muscle(
                                          exercise
                                              .muscleActivations
                                              .first
                                              .muscleGroupId,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/${Platform.operatingSystem}/exercise_animation_gallery.png',
      ),
    );
  });
}
