import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/health_connect_workout.dart';
import 'package:repforge/screens/widgets/fitify_workout_import_card.dart';
import 'package:repforge/services/interfaces/workout_import_health_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'fitify_workout_import_test.dart' show sourceWorkout;

class ImportReader implements IWorkoutImportHealthService {
  bool permitted = true, fail = false;
  int reads = 0;
  @override
  Future<WorkoutImportAccess> requestWorkoutImportAccess({
    bool includeHistory = false,
  }) async => WorkoutImportAccess(
    exerciseGranted: permitted,
    historyGranted: includeHistory,
  );
  @override
  Future<List<HealthConnectWorkout>> readFitifyWorkouts(
    DateTime start,
    DateTime end,
  ) async {
    reads++;
    if (fail) throw StateError('Read failed');
    return [sourceWorkout(), sourceWorkout(code: 'unknown_code')];
  }
}

void main() {
  late WorkoutProvider provider;
  late ImportReader reader;
  setUp(() async {
    final storage = MockStorageService();
    provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    reader = ImportReader();
  });
  tearDown(() => provider.dispose());
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FitifyWorkoutImportCard(reader: reader),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'preview reports unresolved workout and imports only complete resolved sessions',
    (tester) async {
      await show(tester);
      await tester.tap(find.text('Read workouts'));
      await tester.pumpAndSettle();
      expect(
        find.text('1 ready to import · 0 already current · 1 need attention'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Import 1 workouts'));
      await tester.tap(find.text('Import 1 workouts'));
      await tester.pumpAndSettle();
      expect(provider.sessions.length, 1);
      expect(
        find.text(
          '1 imported, 0 updated, 0 already current, 1 need attention.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'permission denial never reads or reports successful empty import',
    (tester) async {
      reader.permitted = false;
      await show(tester);
      await tester.tap(find.text('Read workouts'));
      await tester.pumpAndSettle();
      expect(reader.reads, 0);
      expect(provider.sessions, isEmpty);
      expect(
        find.textContaining('Allow RepForge to read Exercise'),
        findsOneWidget,
      );
      expect(find.textContaining('No FitifySync workouts found'), findsNothing);
    },
  );
  testWidgets('read failure remains retryable without history changes', (
    tester,
  ) async {
    reader.fail = true;
    await show(tester);
    await tester.tap(find.text('Read workouts'));
    await tester.pumpAndSettle();
    expect(find.text('Read failed'), findsOneWidget);
    expect(provider.sessions, isEmpty);
    reader.fail = false;
    await tester.tap(find.text('Read workouts'));
    await tester.pumpAndSettle();
    expect(find.text('Import 1 workouts'), findsOneWidget);
  });
}
