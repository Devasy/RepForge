// Widget tests for the refactored AnalyticsScreen tabs:
//   • Overview  — volume trend range toggle (4W / 12W / All)
//   • Targets   — summary header counts, on-track / stalled status words
//   • Records   — summary header, All / This month / By exercise filter,
//                 Recent / Heaviest sort toggle

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/analytics_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

Widget _wrap({
  required WorkoutProvider workoutProvider,
  required PRManager prManager,
  SettingsProvider? settings,
}) {
  final sp = settings ?? SettingsProvider(MockStorageService());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: sp),
      ChangeNotifierProvider<PRManager>.value(value: prManager),
      ChangeNotifierProvider<GeminiAiService>.value(value: GeminiAiService()),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: const MaterialApp(home: AnalyticsScreen()),
  );
}

Future<WorkoutProvider> _makeProvider(MockStorageService storage) async {
  final p = WorkoutProvider(
    storage,
    mlService: MockMLService(),
    programManager: ProgramManager(storage),
  );
  await p.init();
  return p;
}

Future<PRManager> _makePRManager(MockStorageService storage) async {
  final m = PRManager(storage);
  await m.load();
  return m;
}

WorkoutSession _session({
  required String id,
  required DateTime date,
  String exerciseId = 'bench_press',
  double weight = 80.0,
  int reps = 10,
}) =>
    WorkoutSession(
      id: id,
      date: date,
      duration: 30,
      exercises: [
        ExerciseLog(
          exerciseId: exerciseId,
          sets: [WorkoutSet(weight: weight, reps: reps)],
        ),
      ],
    );

/// Switch to tab [index] (0=Overview, 1=Exercises, 2=Targets, 3=Records).
Future<void> _switchTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

// ── Overview tab ──────────────────────────────────────────────────────────────

void main() {
  group('AnalyticsScreen – Overview tab', () {
    late MockStorageService storage;
    late WorkoutProvider provider;
    late PRManager prManager;

    setUp(() async {
      storage = MockStorageService();
      provider = await _makeProvider(storage);
      prManager = await _makePRManager(storage);
    });

    testWidgets('shows empty chart when no sessions', (tester) async {
      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();

      // Overview is the first visible tab.
      expect(find.text('Volume Trend'), findsOneWidget);
      // Both Volume Trend and Muscle Focus cards show "No data yet" when empty.
      expect(find.text('No data yet'), findsWidgets);
    });

    testWidgets('range toggle buttons 4W, 12W and All are visible',
        (tester) async {
      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();

      expect(find.text('4W'), findsOneWidget);
      expect(find.text('12W'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('tapping 4W does not throw and keeps 4W visible',
        (tester) async {
      storage.addMockSession(_session(id: 's1', date: DateTime.now()));
      provider = await _makeProvider(storage);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('4W'));
      await tester.pumpAndSettle();
      expect(find.text('4W'), findsOneWidget);
    });

    testWidgets('tapping All does not throw', (tester) async {
      storage.addMockSession(_session(id: 's1', date: DateTime.now()));
      provider = await _makeProvider(storage);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('Muscle Focus card is shown on the Overview tab',
        (tester) async {
      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Muscle Focus'), findsOneWidget);
    });

    testWidgets('Workout Frequency grid uses "This wk" label', (tester) async {
      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();

      expect(find.text('This wk'), findsOneWidget);
    });
  });

  // ── Targets tab ─────────────────────────────────────────────────────────────

  group('AnalyticsScreen – Targets tab', () {
    late MockStorageService storage;
    late WorkoutProvider provider;
    late PRManager prManager;

    setUp(() async {
      storage = MockStorageService();
      provider = await _makeProvider(storage);
      prManager = await _makePRManager(storage);
    });

    testWidgets('shows empty state when no targets', (tester) async {
      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Targets');

      expect(find.text('No Targets Set'), findsOneWidget);
    });

    testWidgets('summary header shows "N active" count', (tester) async {
      storage.addMockTarget(Target(
        id: 't1',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100.0,
        currentValue: 80.0,
      ));
      provider = await _makeProvider(storage);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Targets');

      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('shows "stalled" chip when no ETA is set', (tester) async {
      // A target with no estimatedCompletionDate is stalled.
      storage.addMockTarget(Target(
        id: 't1',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100.0,
        currentValue: 60.0,
        // estimatedCompletionDate left null → stalled
      ));
      provider = await _makeProvider(storage);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Targets');

      expect(find.text('Stalled'), findsOneWidget);
    });

    testWidgets('shows "On track" chip when ETA is in the future', (tester) async {
      storage.addMockTarget(Target(
        id: 't1',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100.0,
        currentValue: 80.0,
        estimatedCompletionDate: DateTime.now().add(const Duration(days: 30)),
      ));
      provider = await _makeProvider(storage);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Targets');

      expect(find.text('On track'), findsOneWidget);
    });

    testWidgets('shows "stalled" chip when ETA is in the past', (tester) async {
      storage.addMockTarget(Target(
        id: 't1',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100.0,
        currentValue: 60.0,
        estimatedCompletionDate:
            DateTime.now().subtract(const Duration(days: 1)),
      ));
      provider = await _makeProvider(storage);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Targets');

      expect(find.text('Stalled'), findsOneWidget);
    });

    testWidgets('completed targets show in summary', (tester) async {
      storage.addMockTarget(Target(
        id: 't1',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100.0,
        currentValue: 100.0,
        isCompleted: true,
      ));
      provider = await _makeProvider(storage);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Targets');

      // 1 completed → "1 done" chip; active count is 0 which shows "0 active"
      expect(find.text('1 done'), findsOneWidget);
    });
  });

  // ── Records tab ──────────────────────────────────────────────────────────────

  group('AnalyticsScreen – Records tab', () {
    late MockStorageService storage;
    late WorkoutProvider provider;
    late PRManager prManager;

    setUp(() async {
      storage = MockStorageService();
      provider = await _makeProvider(storage);
      prManager = await _makePRManager(storage);
    });

    testWidgets('shows empty state when no PRs exist', (tester) async {
      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      expect(find.text('No records yet'), findsOneWidget);
      expect(
          find.text('Finish a workout to set your first PRs'), findsOneWidget);
    });

    testWidgets('summary shows total PR count after seeding records',
        (tester) async {
      final session = _session(id: 's1', date: DateTime.now(), weight: 100.0);
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      expect(find.text('1 PRs'), findsOneWidget);
    });

    testWidgets('newest PR hero card is shown', (tester) async {
      final session = _session(id: 's1', date: DateTime.now(), weight: 100.0);
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      expect(find.text('Latest PR'), findsOneWidget);
    });

    testWidgets('filter chips All, This month, By exercise are visible',
        (tester) async {
      final session = _session(id: 's1', date: DateTime.now());
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      expect(find.text('All'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('By exercise'), findsOneWidget);
    });

    testWidgets('tapping "This month" filter does not throw', (tester) async {
      final session = _session(id: 's1', date: DateTime.now());
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      expect(find.text('This month'), findsOneWidget);
    });

    testWidgets('tapping "By exercise" filter does not throw', (tester) async {
      final session = _session(id: 's1', date: DateTime.now());
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      await tester.tap(find.text('By exercise'));
      await tester.pumpAndSettle();
      expect(find.text('By exercise'), findsOneWidget);
    });

    testWidgets('sort toggle shows Recent and Heaviest labels', (tester) async {
      final session = _session(id: 's1', date: DateTime.now());
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      // Default sort label
      expect(find.text('Recent'), findsOneWidget);
    });

    testWidgets('tapping sort toggle switches label to Heaviest', (tester) async {
      final session = _session(id: 's1', date: DateTime.now());
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      expect(find.text('Heaviest'), findsOneWidget);
    });

    testWidgets('tapping sort toggle twice returns to Recent', (tester) async {
      final session = _session(id: 's1', date: DateTime.now());
      await prManager.checkAndUpdatePRs(session);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heaviest'));
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
    });

    testWidgets('"This month" filter hides old PRs', (tester) async {
      // One PR from last year, one from today.
      final old = _session(
        id: 's_old',
        date: DateTime(2020, 1, 1),
        exerciseId: 'bench_press',
        weight: 50.0,
      );
      final recent = _session(
        id: 's_new',
        date: DateTime.now(),
        exerciseId: 'squat',
        weight: 120.0,
      );

      // Add a custom exercise for squat so it resolves properly.
      storage.addMockCustomExercise(Exercise(
        id: 'squat',
        name: 'Squat Custom',
        category: 'compound',
        isCustom: true,
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'quads', activationPercentage: 100),
        ],
      ));

      await prManager.checkAndUpdatePRs(old);
      await prManager.checkAndUpdatePRs(recent);

      await tester.pumpWidget(_wrap(
        workoutProvider: provider,
        prManager: prManager,
      ));
      await tester.pumpAndSettle();
      await _switchTab(tester, 'Records');

      // Both PRs shown under "All".
      expect(find.text('2 PRs'), findsOneWidget);

      // Filter to This month — only the recent one remains.
      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();

      expect(find.text('1 this month'), findsOneWidget);
    });
  });
}
