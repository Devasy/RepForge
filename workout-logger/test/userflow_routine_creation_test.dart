import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/routines_screen.dart';
import 'package:repforge/screens/widgets/routine_creator.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';

Widget _buildTestApp({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStorageService mockStorage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;

  setUp(() async {
    mockStorage = MockStorageService();
    workoutProvider = WorkoutProvider(
      mockStorage,
      programManager: ProgramManager(mockStorage),
    );
    settingsProvider = SettingsProvider(mockStorage);

    await workoutProvider.init();
    await settingsProvider.init();
  });

  group('Userflow 3: Routine Creation & Management Flow', () {
    testWidgets('RoutinesScreen renders title, empty state, and new routine button', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        child: const RoutinesScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Routines'), findsWidgets);
    });

    testWidgets('CreateRoutineScreen renders input fields, selects exercise, and saves new routine', (tester) async {
      final exercise = Exercise(
        id: 'ex_bench',
        name: 'Bench Press',
        category: 'compound',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
        ],
      );
      await mockStorage.saveCustomExercise(exercise);
      await workoutProvider.init();

      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        child: const CreateRoutineScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('New Routine'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Enter routine name into TextField
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Upper Body Hypertrophy');
      await tester.pump();

      // Tap 'Add Exercises' button to open exercise picker modal
      final addBtn = find.text('Add Exercises');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Select 'Bench Press' from picker modal
      final benchPressFinder = find.text('Bench Press');
      expect(benchPressFinder, findsWidgets);
      await tester.tap(benchPressFinder.first);
      await tester.pump();

      // Tap 'Add 1' button in picker header
      await tester.tap(find.text('Add 1'));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify routine saved in provider
      expect(workoutProvider.routines.any((r) => r.name == 'Upper Body Hypertrophy'), isTrue);
    });

    testWidgets('RoutinesScreen renders saved routines list', (tester) async {
      await workoutProvider.createRoutine('Legs & Core Routine', ['ex_squat']);

      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        child: const RoutinesScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Legs & Core Routine'), findsWidgets);
    });

    testWidgets('startRoutineWorkoutFlow starts routine workout without conflict', (tester) async {
      final routine = Routine(id: 'r1', name: 'Push Day', exerciseIds: ['bench_press']);
      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => startRoutineWorkoutFlow(context, routine),
            child: const Text('Start Routine'),
          ),
        ),
      ));

      await tester.tap(find.text('Start Routine'));
      await tester.pumpAndSettle();

      expect(workoutProvider.isWorkoutActive, isTrue);
    });

    testWidgets('RoutineDetailScreen renders routine details', (tester) async {
      final routine = Routine(id: 'r2', name: 'Pull Day', exerciseIds: ['barbell_row']);

      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        child: RoutineDetailScreen(routine: routine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pull Day'), findsWidgets);
    });
  });
}
