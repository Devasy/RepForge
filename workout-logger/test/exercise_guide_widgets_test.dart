import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/exercise_demonstration_section.dart';
import 'package:repforge/services/exercise_guide_cache.dart';

class _GuideCache extends ExerciseGuideCache {
  int downloads = 0;
  bool fail = false;

  @override
  Future<bool> isDownloaded(String exerciseId) async => false;

  @override
  Future<void> download(String exerciseId) async {
    downloads++;
    if (fail) throw StateError('Offline');
  }

  @override
  Future<void> downloadAll({
    void Function(int completed, int total)? onProgress,
  }) async {
    downloads++;
    if (fail) throw StateError('Offline');
    onProgress?.call(6, 6);
  }
}

void main() {
  const bench = Exercise(
    id: 'bench_press',
    name: 'Bench Press',
    muscleActivations: [],
    category: 'compound',
  );

  testWidgets('curated guide shows instructions and user-triggered download', (
    tester,
  ) async {
    final cache = _GuideCache();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseDemonstrationSection(exercise: bench, cache: cache),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('Reference variant: Barbell Bench Press'),
      findsOneWidget,
    );
    expect(find.text('Download photo guide'), findsOneWidget);
    expect(cache.downloads, 0);
    await tester.ensureVisible(find.text('Download photo guide'));
    await tester.tap(find.text('Download photo guide'));
    await tester.pumpAndSettle();
    expect(cache.downloads, 1);
  });

  testWidgets('guide failure reports retry and custom exercise has no guide', (
    tester,
  ) async {
    final cache = _GuideCache()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseDemonstrationSection(exercise: bench, cache: cache),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Download photo guide'));
    await tester.tap(find.text('Download photo guide'));
    await tester.pump();
    expect(find.textContaining('Could not download the guide'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseDemonstrationSection(
            exercise: bench.copyWith(isCustom: true),
            cache: cache,
          ),
        ),
      ),
    );
    expect(find.text('Download photo guide'), findsNothing);
  });
}
