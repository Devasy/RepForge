import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/programs/programs_screen.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/screens/programs/program_detail_screen.dart';
import 'package:repforge/screens/programs/program_designer_screen.dart';
import 'package:repforge/screens/programs/import_program_screen.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/test_harness.dart';

class _FailingProgramStorage extends MockStorageService {
  bool fail = false;
  @override
  Future<void> saveTrainingProgram(TrainingProgram program) async {
    if (fail) throw StateError('Unavailable');
    await super.saveTrainingProgram(program);
  }
}

void main() {
  late MockStorageService storage;
  late WorkoutProvider provider;
  late TrainingProgram program;
  setUp(() async {
    storage = MockStorageService();
    provider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    await provider.init();
    program = TrainingProgram(
      id: 'saved',
      name: 'My plan',
      totalWeeks: 2,
      phases: [],
      weeks: [
        ProgramWeek(
          weekNumber: 1,
          days: [
            ProgramDay(
              id: 'day',
              name: 'Strength day',
              exercises: [
                ProgramExerciseSlot(
                  exerciseId: 'bench_press',
                  sets: 3,
                  minReps: 8,
                  maxReps: 10,
                  restSeconds: 90,
                ),
              ],
            ),
          ],
        ),
        ProgramWeek(weekNumber: 2, days: []),
      ],
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    bool narrow = false,
  }) async {
    final size = narrow ? const Size(320, 640) : const Size(600, 900);
    await TestHarness.prepareTester(tester, size: size);
    await tester.pumpWidget(
      TestHarness.wrap(
        screen,
        storage: storage,
        workoutProvider: provider,
        viewportSize: size,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('detail follows manager changes without workout notifications', (
    tester,
  ) async {
    await provider.programManager.saveProgram(program);
    await pump(tester, ProgramDetailScreen(program: program));
    expect(find.text('Follow program'), findsOneWidget);
    await provider.programManager.followProgram(program.id);
    await tester.pumpAndSettle();
    expect(find.text('Follow program'), findsNothing);
    await provider.programManager.followProgram(null);
    await tester.pumpAndSettle();
    expect(find.text('Follow program'), findsOneWidget);
  });

  testWidgets('empty state has one action and labelled offline choices', (
    tester,
  ) async {
    await pump(tester, const ProgramsScreen(), narrow: true);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      find.text('Create a plan or import one to get started. AI is optional.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Create from scratch'), findsOneWidget);
    expect(find.text('Import JSON'), findsOneWidget);
    expect(find.text('Generate with AI'), findsOneWidget);
    await tester.tap(find.text('Create from scratch'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramDesignerScreen), findsOneWidget);
    expect(provider.programManager.programs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'import is discoverable and cancelling leaves saved programs intact',
    (tester) async {
      await provider.programManager.saveProgram(program);
      await pump(tester, const ProgramsScreen());
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import JSON'));
      await tester.pumpAndSettle();
      expect(find.byType(ImportProgramScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(provider.programManager.programs.single.id, program.id);
      expect(find.text('My plan'), findsOneWidget);
    },
  );

  testWidgets('daily flow follows program then starts next unfinished day', (
    tester,
  ) async {
    await provider.programManager.saveProgram(program);
    await pump(tester, const ProgramsScreen(), narrow: true);
    await tester.tap(find.text('My plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow program'));
    await tester.pumpAndSettle();
    expect(find.text('Next workout'), findsOneWidget);
    expect(find.text('Week 1 · Strength day'), findsOneWidget);
    await tester.tap(find.text('Start next workout'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.hasActiveWorkout, isTrue);
    expect(provider.activeProgramId, program.id);
    expect(provider.activeProgramDay?.id, 'day');
    expect(provider.activeProgramWeek?.weekNumber, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved plan shows real duration and variable training days', (
    tester,
  ) async {
    await provider.programManager.saveProgram(program);
    await pump(tester, const ProgramsScreen(), narrow: true);
    expect(find.text('2 weeks'), findsOneWidget);
    expect(find.text('0–1 days/week'), findsOneWidget);
    await tester.tap(find.text('My plan'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramDetailScreen), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit program'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramDesignerScreen), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Program Name *'),
      'Updated plan',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramDetailScreen), findsOneWidget);
    expect(find.text('Updated plan'), findsOneWidget);
    expect(provider.programManager.programs.single.id, program.id);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Updated plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed program edit stays open and retry preserves identity', (
    tester,
  ) async {
    final failing = _FailingProgramStorage();
    final wp = WorkoutProvider(
      failing,
      mlService: MockMLService(),
      programManager: ProgramManager(failing),
    );
    await wp.init();
    await wp.programManager.saveProgram(program);
    await TestHarness.prepareTester(tester, size: const Size(600, 900));
    await tester.pumpWidget(
      TestHarness.wrap(
        ProgramDetailScreen(program: program),
        storage: failing,
        workoutProvider: wp,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit program'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Program Name *'),
      'Changed',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    failing.fail = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save program. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(ProgramDesignerScreen), findsOneWidget);
    expect(wp.programManager.programs.single.name, 'My plan');
    failing.fail = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(wp.programManager.programs.single.id, program.id);
    expect(wp.programManager.programs.single.name, 'Changed');
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid repeated Start taps open one workout screen', (
    tester,
  ) async {
    await provider.programManager.saveProgram(program);
    await provider.programManager.followProgram(program.id);
    await pump(tester, const ProgramsScreen());
    final start = find.text('Start next workout');
    final button = tester.widget<FilledButton>(
      find.ancestor(of: start, matching: find.byType(FilledButton)),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutFlowScreen, skipOffstage: false), findsOneWidget);
    expect(provider.activeProgramDay?.id, 'day');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });
}
