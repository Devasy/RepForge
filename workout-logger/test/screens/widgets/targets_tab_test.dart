import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/targets_tab.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders TargetsTab with empty targets state', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final provider = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await provider.init();

    await tester.pumpWidget(TestHarness.wrap(
      const TargetsTab(),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('No Targets Set'), findsOneWidget);
  });

  testWidgets('Renders TargetsTab with active targets list', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final target = Target(
      id: 'target_1',
      exerciseId: 'bench_press',
      targetType: 'weight',
      targetValue: 100.0,
      currentValue: 80.0,
    );
    await storage.saveTarget(target);

    final provider = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await provider.init();

    await tester.pumpWidget(TestHarness.wrap(
      const TargetsTab(),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('No Targets Set'), findsNothing);
  });
}
