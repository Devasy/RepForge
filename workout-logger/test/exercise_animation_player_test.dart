import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/exercise_animations.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/screens/widgets/exercise_animation_player.dart';
import 'package:repforge/screens/widgets/exercise_movement_painter.dart';
import 'package:repforge/theme/app_theme.dart';
import 'test_utils/animation_fonts.dart';

final exercises = ExerciseDatabase.getAll();

Widget player(String id, {bool reducedMotion = false, double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseAnimationPlayer(
              exercise: exercises.firstWhere((e) => e.id == id),
            ),
          ),
        ),
      ),
    );

ExerciseMovementPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('exercise-movement-canvas')),
            )
            .painter!
        as ExerciseMovementPainter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAnimationFonts);
  test(
    'every built-in exercise has an explicit animation; custom IDs never inherit one',
    () {
      expect(
        exerciseAnimations.keys.toSet(),
        exercises.map((e) => e.id).toSet(),
      );
      for (final exercise in exercises) {
        expect(
          ExerciseAnimation.forExercise(exercise),
          isNotNull,
          reason: exercise.id,
        );
        expect(
          ExerciseAnimation.forExercise(exercise.copyWith(isCustom: true)),
          isNull,
        );
      }
    },
  );

  test(
    'every movement produces finite, in-frame joints across a repetition',
    () {
      for (final entry in exerciseAnimations.entries) {
        for (var step = 0; step <= 20; step++) {
          final pose = ExercisePose.at(entry.value, step / 20);
          for (final point in [
            pose.head,
            pose.shoulder,
            pose.hip,
            pose.knee,
            pose.ankle,
            pose.elbow,
            pose.hand,
            pose.otherHand,
            pose.otherElbow,
          ]) {
            if (point == null) continue;
            expect(
              point.dx.isFinite && point.dy.isFinite,
              isTrue,
              reason: entry.key,
            );
            expect(
              point.dx,
              inInclusiveRange(30, 330),
              reason: '${entry.key} x',
            );
            expect(
              point.dy,
              inInclusiveRange(0, 225),
              reason: '${entry.key} y',
            );
          }
        }
      }
    },
  );

  testWidgets('starts paused, plays, pauses, and restarts without autoplay', (
    tester,
  ) async {
    await tester.pumpWidget(player('squat'));
    final start = painter(tester).amount;
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).amount, start);
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).amount, greaterThan(start));
    await tester.tap(find.text('Pause'));
    await tester.pump();
    final paused = painter(tester).amount;
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).amount, paused);
    await tester.tap(find.byTooltip('Restart movement'));
    await tester.pump();
    expect(painter(tester).amount, 0);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('scrubbing pauses playback and exposes the return cue', (
    tester,
  ) async {
    await tester.pumpWidget(player('bicep_curl'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeStart!(.75);
    slider.onChanged!(.75);
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
    expect(find.text('Lower with control'), findsOneWidget);
    expect(painter(tester).amount, closeTo(.5, .001));
  });

  testWidgets('speed changes affect playback duration', (tester) async {
    await tester.pumpWidget(player('squat'));
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.5× speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(.25, .02));
    await tester.tap(find.text('Pause'));
    await tester.pump();
  });

  testWidgets('backgrounding pauses and returning does not resume', (
    tester,
  ) async {
    await tester.pumpWidget(player('bench_press'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('scrolling the guide out of view pauses playback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ExerciseAnimationPlayer(exercise: exercises.first),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Play'));
    await tester.pump();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(800);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Play'), findsOneWidget);
    final position = painter(tester).amount;
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).amount, position);
  });

  testWidgets('covering the guide with another route pauses playback', (
    tester,
  ) async {
    await tester.pumpWidget(player('squat'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    final navigator = Navigator.of(
      tester.element(find.byType(ExerciseAnimationPlayer)),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Another screen')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets(
    'reduced motion disables playback while preserving manual inspection',
    (tester) async {
      await tester.pumpWidget(player('squat', reducedMotion: true));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      tester.widget<Slider>(find.byType(Slider)).onChanged!(.5);
      await tester.pump();
      expect(painter(tester).amount, 1);
      expect(find.textContaining('Motion is off'), findsOneWidget);
    },
  );

  testWidgets('changing exercises resets position and playback', (
    tester,
  ) async {
    await tester.pumpWidget(player('squat'));
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(player('bench_press'));
    expect(painter(tester).amount, 0);
    expect(painter(tester).animation.movement, ExerciseMovement.benchPress);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets(
    'plank is a static hold; unsupported exercises have no inferred animation',
    (tester) async {
      await tester.pumpWidget(player('plank'));
      expect(find.text('Hold position'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Play'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseAnimationPlayer(
            exercise: exercises.first.copyWith(id: 'unknown'),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('exercise-movement-canvas')),
        findsNothing,
      );
    },
  );

  testWidgets('narrow layout and large text remain usable', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      player('overhead_tricep_extension', textScale: 1.6),
    );
    await tester.ensureVisible(find.text('Play'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Pause'));
    await tester.pump();
  });

  testWidgets('player visual regression', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(player('squat'));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/exercise_animation_player.png'),
    );
  });
}
