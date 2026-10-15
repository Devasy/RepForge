import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/screens/exercise_guide_screen.dart';
import 'package:repforge/services/exercise_guide_cache.dart';
import 'package:repforge/theme/app_theme.dart';

import 'test_utils/animation_fonts.dart';

class _FixtureGuideCache extends ExerciseGuideCache {
  @override
  Future<bool> isDownloaded(String exerciseId) async => true;

  @override
  Future<File> fileFor(String exerciseId, int index) async =>
      File('test/fixtures/exercise_guides/squat_$index.jpg');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAnimationFonts);
  testWidgets(
    'full guide displays real reference photos and movement controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cache = _FixtureGuideCache();
      addTearDown(cache.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open guide'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExerciseGuideScreen(
                      exercise: ExerciseDatabase.getAll().firstWhere(
                        (e) => e.id == 'squat',
                      ),
                      cache: cache,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.text('Open guide'));
        await Future.wait([
          for (var i = 0; i < 2; i++)
            precacheImage(FileImage(await cache.fileFor('squat', i)), context),
        ]);
      });
      await tester.tap(find.text('Open guide'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) {
        expect(raw.image, isNotNull);
      }
      expect(find.text('Exercise guide'), findsOneWidget);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(.4);
      await tester.pump();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'goldens/${Platform.operatingSystem}/exercise_guide_screen.png',
        ),
      );
      await tester.tap(find.text('Technique instructions'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This exercise is best performed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
