import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:repforge/data/body_figure.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/data/exercise_muscle_motion.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/screens/widgets/body_heatmap.dart';
import 'package:repforge/screens/widgets/exercise_muscle_map.dart';
import 'package:repforge/screens/widgets/gender_picker.dart';
import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/services/settings_provider.dart';
import 'test_utils/mock_storage_service.dart';

class _FailingStorage extends MockStorageService {
  @override
  Future<void> saveSetting(String key, String value) async =>
      throw StateError('Write failed');
}

Exercise _exercise(String id) =>
    ExerciseDatabase.getAll().firstWhere((e) => e.id == id);

void main() {
  test(
    'saved gender selects diagrams and setup is required only without a valid choice',
    () async {
      final storage = MockStorageService();
      final settings = SettingsProvider(storage);
      await settings.init();
      expect(settings.needsGenderSelection, isTrue);
      await settings.setUserGender(UserGender.female);
      expect(settings.needsGenderSelection, isFalse);
      expect(settings.bodyFigure, BodyFigure.female);
      final restored = SettingsProvider(storage);
      await restored.init();
      expect(restored.needsGenderSelection, isFalse);
      expect(restored.bodyFigure, BodyFigure.female);
      await restored.setUserGender(UserGender.male);
      expect(restored.bodyFigure, BodyFigure.male);
      // Ignore obsolete independent figure overrides in older backups.
      await storage.saveSetting('bodyFigure', 'female');
      await restored.init();
      expect(restored.bodyFigure, BodyFigure.male);
      await restored.setUserGender(UserGender.preferNotToSay);
      await restored.init();
      expect(restored.needsGenderSelection, isFalse);
      await storage.saveSetting('userGender', 'invalid');
      await restored.init();
      expect(restored.needsGenderSelection, isTrue);
    },
  );

  test(
    'failed gender writes preserve active values and keep setup pending',
    () async {
      final settings = SettingsProvider(_FailingStorage());
      await expectLater(
        settings.setUserGender(UserGender.female),
        throwsStateError,
      );
      expect(settings.needsGenderSelection, isTrue);
      expect(settings.userGender, UserGender.preferNotToSay);
      expect(settings.bodyFigure, BodyFigure.male);
    },
  );

  testWidgets(
    'failed Profile gender save keeps the displayed saved selection',
    (tester) async {
      final settings = SettingsProvider(_FailingStorage());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PreferencesSection(settings: settings, onHaptic: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButton<UserGender>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();
      expect(settings.userGender, UserGender.preferNotToSay);
      expect(
        tester
            .widget<DropdownButton<UserGender>>(
              find.byType(DropdownButton<UserGender>),
            )
            .value,
        UserGender.preferNotToSay,
      );
      expect(find.text('Could not save gender. Try again.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gender picker follows successful external changes and onboarding selection',
    (tester) async {
      final settings = SettingsProvider(MockStorageService());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<SettingsProvider>(
                builder: (context, settings, _) => GenderPicker(
                  value: settings.userGender,
                  onChanged: settings.setUserGender,
                ),
              ),
            ),
          ),
        ),
      );
      await settings.setUserGender(UserGender.female);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<UserGender>>(
              find.byType(DropdownButton<UserGender>),
            )
            .value,
        UserGender.female,
      );
      await tester.tap(find.byType(DropdownButton<UserGender>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Male').last);
      await tester.pumpAndSettle();
      expect(settings.userGender, UserGender.male);
      expect(
        tester
            .widget<DropdownButton<UserGender>>(
              find.byType(DropdownButton<UserGender>),
            )
            .value,
        UserGender.male,
      );
    },
  );

  testWidgets(
    'both shoulder presses show shoulder and triceps involvement in both phases',
    (tester) async {
      for (final id in ['overhead_press', 'dumbbell_shoulder_press']) {
        final exercise = _exercise(id);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseMuscleMap(key: ValueKey(id), exercise: exercise),
              ),
            ),
          ),
        );
        final expected = {
          for (final a in exercise.muscleActivations)
            if (['shoulders', 'triceps'].contains(a.muscleGroupId))
              a.muscleGroupId: a.activationPercentage / 100,
        };
        expect(expected.keys.toSet(), {'shoulders', 'triceps'});
        expect(
          tester
              .widget<MuscleBodyMap>(find.byType(MuscleBodyMap))
              .muscleVolumes,
          expected,
        );
        await tester.tap(find.text('Stretched'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MuscleBodyMap>(find.byType(MuscleBodyMap))
              .muscleVolumes,
          expected,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('saved diagram is shared by compact and detailed maps', (
    tester,
  ) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.setUserGender(UserGender.female);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [BodyHeatmapWidget(), MuscleBodyMap()]),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SegmentedButton<BodyFigure>), findsNothing);
    expect(
      tester
          .widgetList<BodyHeatmapWidget>(find.byType(BodyHeatmapWidget))
          .where((widget) => widget.figure != null)
          .every((widget) => widget.figure == BodyFigure.female),
      isTrue,
    );
    await settings.setUserGender(UserGender.male);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<BodyHeatmapWidget>(find.byType(BodyHeatmapWidget))
          .where((widget) => widget.figure != null)
          .every((widget) => widget.figure == BodyFigure.male),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise phases update labels and blue/red gradients', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseMuscleMap(exercise: _exercise('bicep_curl')),
          ),
        ),
      ),
    );
    expect(find.text('Contracted · shortening under load'), findsOneWidget);
    expect(
      tester.widget<MuscleBodyMap>(find.byType(MuscleBodyMap)).heatColor,
      contractedMuscleColor,
    );
    await tester.tap(find.text('Stretched'));
    await tester.pumpAndSettle();
    expect(find.text('Stretched · lengthening under load'), findsOneWidget);
    final map = tester.widget<MuscleBodyMap>(find.byType(MuscleBodyMap));
    expect(map.heatColor, stretchedMuscleColor);
    expect(map.muscleVolumes, {'biceps': .95});
    expect(
      tester
          .widgetList<BodyHeatmapWidget>(find.byType(BodyHeatmapWidget))
          .every((widget) => widget.heatColor == stretchedMuscleColor),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'isometric and custom exercises show involvement without invented phases',
    (tester) async {
      for (final exercise in [
        _exercise('plank'),
        _exercise('bench_press').copyWith(isCustom: true),
      ]) {
        expect(ExerciseMuscleMotion.forExercise(exercise), isNull);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseMuscleMap(exercise: exercise),
              ),
            ),
          ),
        );
        expect(find.text('Stretched'), findsNothing);
        expect(find.text('Contracted'), findsNothing);
        expect(find.text('Target muscle involvement'), findsOneWidget);
      }
    },
  );

  test('hinge phase excludes stabilizing lower back', () {
    final exercise = _exercise('romanian_deadlift');
    expect(ExerciseMuscleMotion.forExercise(exercise)!.muscles, [
      'hamstrings',
      'glutes',
    ]);
  });

  testWidgets('onboarding allows gender to be skipped', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'RepForge',
      packageName: 'com.devasy.repforge',
      version: '2.1.6',
      buildNumber: '64',
      buildSignature: '',
    );
    final settings = SettingsProvider(MockStorageService());
    bool complete = false;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: WelcomePage(onComplete: () => complete = true),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Lifter');
    expect(
      tester.widget<GenderPicker>(find.byType(GenderPicker)).value,
      UserGender.preferNotToSay,
    );
    await tester.ensureVisible(find.text("Let's Go!"));
    await tester.tap(find.text("Let's Go!"));
    await tester.pumpAndSettle();
    expect(complete, isTrue);
    expect(settings.userName, 'Lifter');
    expect(settings.userGender, UserGender.preferNotToSay);
    expect(tester.takeException(), isNull);
  });
}
