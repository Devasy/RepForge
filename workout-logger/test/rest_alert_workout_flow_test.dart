import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/screens/widgets/rest_timer_view.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('background rest catches up on resume without a second alert', (
    tester,
  ) async {
    const channel = MethodChannel('repforge/rest_alert');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'requestPermission') return true;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final storage = MockStorageService();
    await storage.saveCustomExercise(
      Exercise(
        id: 'rest_test_bench',
        name: 'Rest Test Bench',
        category: 'compound',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
        ],
      ),
    );
    final workouts = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    final settings = SettingsProvider(storage);
    final records = PRManager(storage);
    await workouts.init();
    await settings.init();
    await records.load();
    workouts.startWorkout(exerciseIds: ['rest_test_bench']);

    var now = DateTime.now();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutProvider>.value(value: workouts),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<PRManager>.value(value: records),
        ],
        child: MaterialApp(home: WorkoutFlowScreen(clock: () => now)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pump();
    await tester.pump();
    expect(calls, contains('schedule'));
    expect(
      tester.widget<RestTimerView>(find.byType(RestTimerView)).remainingSeconds,
      90,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 91));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RestTimerView), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(RestTimerView), findsNothing);
    expect(find.text('Rest complete — time for your next set'), findsOneWidget);
    expect(calls, contains('cancel'));

    await tester.tap(find.text('Log set'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('−30s'));
      await tester.pump();
    }
    expect(find.byType(RestTimerView), findsNothing);
    await tester.tap(find.text('Log set'));
    await tester.pump();
    expect(tester.widget<RestTimerView>(find.byType(RestTimerView))
        .totalSeconds, 30);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
