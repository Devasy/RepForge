import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/workout_hr_models.dart';
import 'package:repforge/screens/widgets/workout_hr_section.dart';
import 'package:repforge/services/managers/health_history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/stub_health_connect_service.dart';
import '../../test_utils/test_fixtures.dart';
import '../../test_utils/test_harness.dart';

class StubHealthHistoryManager extends HealthHistoryManager {
  StubHealthHistoryManager(this.stubAnalysis)
      : super(const StubHcService(), MockStorageService());

  final WorkoutHrAnalysis? stubAnalysis;

  @override
  Future<WorkoutHrAnalysis?> workoutHr(WorkoutSession session) async {
    return stubAnalysis;
  }
}

void main() {
  testWidgets('Renders WorkoutHrSection with heart rate analysis stats', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await provider.init();

    final now = DateTime(2026, 5, 10, 14, 30);
    final analysis = WorkoutHrAnalysis(
      start: now,
      end: now.add(const Duration(minutes: 45)),
      avgBpm: 110,
      peakBpm: 150,
      minBpm: 60,
      curve: [
        HrCurvePoint(time: now, bpm: 70.0),
        HrCurvePoint(time: now.add(const Duration(minutes: 15)), bpm: 140.0),
      ],
      rests: [
        RestRecovery(
          afterSet: 1,
          restStart: now.add(const Duration(minutes: 5)),
          durationSec: 90,
          peakBpm: 135,
          troughBpm: 110,
          recoveryBpm: 25,
          recovered: true,
        ),
      ],
      exercises: [
        ExerciseHrSpan(
          exerciseId: 'bench_press',
          start: now.add(const Duration(minutes: 2)),
          end: now.add(const Duration(minutes: 10)),
          setCount: 3,
        ),
      ],
      hasRestAnalysis: true,
    );

    final customManager = StubHealthHistoryManager(analysis);

    await tester.pumpWidget(TestHarness.wrap(
      WorkoutHrSection(session: session, provider: provider),
      storage: storage,
      healthHistoryManager: customManager,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(WorkoutHrSection), findsOneWidget);
  });
}
