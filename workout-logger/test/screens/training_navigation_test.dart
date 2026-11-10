import 'package:repforge/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/home_screen.dart';
import 'package:repforge/screens/routines_screen.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_harness.dart';
import '../test_utils/program_tool_fixture.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Geist')
      ..addFont(rootBundle.load('assets/fonts/Geist-Variable.ttf'));
    await fonts.load();
  });
  late MockStorageService storage;
  late WorkoutProvider provider;
  setUp(() async {
    storage = MockStorageService();
    provider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    await storage.saveRoutine(
      Routine(
        id: 'routine',
        name: 'Quick strength',
        exerciseIds: ['bench_press'],
      ),
    );
    storage.addMockSession(
      WorkoutSession(
        id: 'completed-week-one',
        date: DateTime.now().subtract(const Duration(days: 7)),
        duration: 30,
        programId: 'followed',
        programDayId: 'day-1',
        programWeekNumber: 1,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [WorkoutSet(weight: 40, reps: 8)],
          ),
        ],
      ),
    );
    await provider.init();
    addTearDown(provider.dispose);
    final program = TrainingProgram.fromJson({
      ...programToolFixture(),
      'id': 'followed',
      'phases': [],
    });
    await provider.programManager.saveProgram(program);
    await provider.programManager.followProgram(program.id);
  });

  testWidgets(
    'Training shows routines and programs side by side and starts next day',
    (tester) async {
      await TestHarness.prepareTester(tester, size: const Size(390, 844));
      await tester.pumpWidget(
        TestHarness.wrap(
          Theme(data: AppTheme.darkTheme, child: const HomeScreen()),
          storage: storage,
          workoutProvider: provider,
          viewportSize: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.layers_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Training'), findsWidgets);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Browse Programs'), findsNothing);
      final program = find.byKey(const ValueKey('training-program-followed'));
      final routine = find.byKey(const ValueKey('training-routine-routine'));
      expect(program, findsOneWidget);
      expect(routine, findsOneWidget);
      expect(
        tester.getTopLeft(program).dy,
        closeTo(tester.getTopLeft(routine).dy, 1),
      );
      expect(
        tester.getTopLeft(program).dx,
        lessThan(tester.getTopLeft(routine).dx),
      );
      await tester.ensureVisible(find.text('Start next workout'));
      await tester.tap(find.text('Start next workout'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutFlowScreen), findsOneWidget);
      expect(provider.activeProgramId, 'followed');
      expect(provider.activeProgramDay?.id, 'day-1');
      expect(provider.activeProgramWeek?.weekNumber, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Training resumes active program without replacing its logged sets',
    (tester) async {
      final plan = provider.programManager.getProgramById('followed')!;
      provider.startWorkout(
        programId: plan.id,
        programWeek: plan.weeks.last,
        programDay: plan.weeks.last.days.first,
        exerciseIds: ['bench_press'],
      );
      provider.addSet(WorkoutSet(weight: 45, reps: 8));
      await tester.pumpWidget(
        TestHarness.wrap(
          Theme(data: AppTheme.darkTheme, child: const RoutinesScreen()),
          storage: storage,
          workoutProvider: provider,
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Resume workout'),
          matching: find.byType(FilledButton),
        ),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(
        find.byType(WorkoutFlowScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(provider.activeProgramWeek?.weekNumber, 2);
      expect(provider.currentExerciseLogs.single.sets.single.weight, 45);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty programs offer editing guidance instead of claiming completion',
    (tester) async {
      final empty = TrainingProgram(
        id: 'empty',
        name: 'Empty plan',
        totalWeeks: 1,
        phases: [],
        weeks: [
          ProgramWeek(
            weekNumber: 1,
            days: [
              ProgramDay(id: 'empty-day', name: 'Empty day', exercises: []),
            ],
          ),
        ],
      );
      await provider.programManager.saveProgram(empty);
      await provider.programManager.followProgram(empty.id);
      await tester.pumpWidget(
        TestHarness.wrap(
          Theme(data: AppTheme.darkTheme, child: const RoutinesScreen()),
          storage: storage,
          workoutProvider: provider,
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('training-program-empty'));
      expect(
        find.descendant(
          of: card,
          matching: find.text('Add exercises to get started.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('View program')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('All workouts completed.'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text stacks mixed cards and retains secondary creation choices',
    (tester) async {
      await TestHarness.prepareTester(tester, size: const Size(320, 800));
      await tester.pumpWidget(
        TestHarness.wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Theme(
              data: AppTheme.darkTheme,
              child: const RoutinesScreen(),
            ),
          ),
          storage: storage,
          workoutProvider: provider,
          viewportSize: const Size(320, 800),
        ),
      );
      await tester.pumpAndSettle();
      final program = find.byKey(const ValueKey('training-program-followed'));
      final routine = find.byKey(const ValueKey('training-routine-routine'));
      expect(program, findsOneWidget);
      await tester.scrollUntilVisible(routine, 200);
      expect(tester.getTopLeft(program).dx, tester.getTopLeft(routine).dx);
      expect(
        tester.getTopLeft(program).dy,
        lessThan(tester.getTopLeft(routine).dy),
      );
      await tester.scrollUntilVisible(find.text('New'), -300);
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('New routine'), findsOneWidget);
      expect(find.text('New program'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
