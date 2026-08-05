import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/sleep_hr_models.dart';
import 'package:repforge/genui/a2ui_component.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/interfaces/storage_service_interface.dart';
import 'package:repforge/services/managers/health_history_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/ml_service.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class FakeStorageService implements IStorageService {
  final Map<String, String> _settings = {};
  final Map<String, PersonalRecord> _prs = {};

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> saveSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<List<PersonalRecord>> getAllPersonalRecords() async => _prs.values.toList();

  @override
  Future<PersonalRecord?> getPersonalRecord(String exerciseId) async => _prs[exerciseId];

  @override
  Future<void> savePersonalRecord(PersonalRecord record) async {
    _prs[record.exerciseId] = record;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHealthConnectService implements IHealthConnectService {
  @override
  Future<Set<HealthReadType>> grantedReadTypes() async => {
    HealthReadType.sleep,
    HealthReadType.heartRate,
    HealthReadType.restingHeartRate,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHealthHistoryManager extends HealthHistoryManager {
  FakeHealthHistoryManager(super.hc, super.storage);

  @override
  Future<SleepHrSnapshot?> sleepNight(DateTime morning) async {
    return SleepHrSnapshot(
      sleepStart: morning.subtract(const Duration(hours: 8)),
      sleepEnd: morning,
      p5Bpm: 52 + (morning.day % 4),
      p95Bpm: 70,
      segments: [
        SleepHrSegment(
          windowStart: morning.subtract(const Duration(hours: 7)),
          minBpm: 50,
          maxBpm: 65,
          avgBpm: 55.0,
          stage: 'deep',
        ),
        SleepHrSegment(
          windowStart: morning.subtract(const Duration(hours: 5)),
          minBpm: 52,
          maxBpm: 68,
          avgBpm: 58.0,
          stage: 'light',
        ),
      ],
      stageStats: [],
    );
  }
}

class FakeWorkoutProvider extends WorkoutProvider {
  FakeWorkoutProvider(super.storage)
      : super(
          mlService: MLService(),
          programManager: ProgramManager(storage),
        );
}

void main() {
  group('Pullups Volume Calculation', () {
    test('standard exercise volume defaults to weight * reps', () {
      final set = WorkoutSet(weight: 80.0, reps: 8);
      expect(set.calculateVolume(userBodyWeight: 75.0, isAssistedBW: false), 640.0);
    });

    test('assisted pullups volume uses (BW - assist + extra) * reps', () {
      // 75 kg bodyweight, 15 kg assist weight, 8 reps
      // Effective load = 75 - 15 = 60 kg -> 60 * 8 = 480 kg volume
      final set = WorkoutSet(weight: 15.0, reps: 8, assistWeight: 15.0);
      expect(set.calculateVolume(userBodyWeight: 75.0, isAssistedBW: true), 480.0);
    });

    test('weighted pullups with assist=0 and extraWeight', () {
      // 75 kg bodyweight, 0 kg assist, +10 kg extra, 5 reps
      // Effective load = 75 - 0 + 10 = 85 kg -> 85 * 5 = 425 kg volume
      final set = WorkoutSet(weight: 0.0, reps: 5, assistWeight: 0.0, extraWeight: 10.0);
      expect(set.calculateVolume(userBodyWeight: 75.0, isAssistedBW: true), 425.0);
    });
  });

  group('MLService - Past 3 Sessions Trend & Deload Protection', () {
    final mlService = MLService();

    test('recommends double progression based on last session when normal', () {
      final s0 = [WorkoutSet(weight: 50.0, reps: 10)];
      final recs = mlService.recommendSets(lastSession: s0, maxReps: 12);
      expect(recs.first.weight, 50.0);
      expect(recs.first.reps, 11);
    });

    test('recovers correctly from deload week using pre-deload baseline', () {
      // Session 1 (pre-deload): 60kg x 10
      final s1 = [WorkoutSet(weight: 60.0, reps: 10)];
      // Session 0 (deload week): 40kg x 8 (significant drop in load)
      final s0 = [WorkoutSet(weight: 40.0, reps: 8)];

      final recs = mlService.recommendSets(
        lastSession: s0,
        pastSessions: [s0, s1],
        maxReps: 12,
      );

      // Should anchor on pre-deload 60kg baseline instead of 40kg deload
      expect(recs.first.weight, 60.0);
      expect(recs.first.reps, 10);
      expect(recs.first.reasoning, contains('Resuming training after deload'));
    });
  });

  group('PRManager - Handle Variations Scoping', () {
    late FakeStorageService fakeStorage;
    late PRManager prManager;

    setUp(() {
      fakeStorage = FakeStorageService();
      prManager = PRManager(fakeStorage);
    });

    test('tracks PRs separately for Rope vs Bar handles', () async {
      await prManager.load();

      final ropeSession = WorkoutSession(
        id: 's1',
        date: DateTime.now(),
        exercises: [
          ExerciseLog(
            exerciseId: 'tricep_pushdown',
            handle: 'Rope',
            sets: [WorkoutSet(weight: 30.0, reps: 10, handle: 'Rope')],
          ),
        ],
        duration: 30,
      );

      final barSession = WorkoutSession(
        id: 's2',
        date: DateTime.now(),
        exercises: [
          ExerciseLog(
            exerciseId: 'tricep_pushdown',
            handle: 'Bar',
            sets: [WorkoutSet(weight: 40.0, reps: 10, handle: 'Bar')],
          ),
        ],
        duration: 30,
      );

      await prManager.checkAndUpdatePRs(ropeSession);
      await prManager.checkAndUpdatePRs(barSession);

      final ropePR = prManager.getRecord('tricep_pushdown', handle: 'Rope');
      final barPR = prManager.getRecord('tricep_pushdown', handle: 'Bar');

      expect(ropePR?.bestWeight, 30.0);
      expect(barPR?.bestWeight, 40.0);
    });
  });

  group('CoachToolService - Sleeping HR Analytics Tool', () {
    late FakeStorageService storage;
    late FakeWorkoutProvider wp;
    late FakeHealthConnectService hc;
    late FakeHealthHistoryManager hh;
    late PRManager pr;
    late CoachToolService coachToolService;

    setUp(() {
      storage = FakeStorageService();
      wp = FakeWorkoutProvider(storage);
      hc = FakeHealthConnectService();
      hh = FakeHealthHistoryManager(hc, storage);
      pr = PRManager(storage);
      coachToolService = CoachToolService(wp, pr, hh);
    });

    test('get_sleeping_hr_analytics computes p5, p25, mean, stdev, variance, and GenUI props', () async {
      final call = FunctionCall('get_sleeping_hr_analytics', {'days': 14});
      final res = await coachToolService.handleCall(call);

      expect(res.containsKey('error'), isFalse);
      expect(res['days_analyzed'], 14);
      expect(res['valid_nights_count'], 14);

      final summary = res['overall_summary'] as Map<String, dynamic>;
      expect(summary.containsKey('mean_p5_sleeping_hr'), isTrue);
      expect(summary.containsKey('stdev_p5_sleeping_hr'), isTrue);
      expect(summary.containsKey('variance_p5_sleeping_hr'), isTrue);
      expect(summary.containsKey('trend_direction'), isTrue);

      final genuiChart = res['genui_chart_props'] as Map<String, dynamic>;
      expect(genuiChart['component'], 'DynamicChart');
      final props = genuiChart['props'] as Map<String, dynamic>;
      expect(props['type'], 'line');
      expect((props['series'] as List).length, 3); // P5, P25, Mean
    });
  });

  group('GenUI Component Resilience Tests', () {
    test('successfully parses GenUI JSON payload with numeric StatCard value and custom trend', () {
      const rawJson = '{"component":"GridContainer","props":{"columns":2,"children":[{"component":"DynamicChart","props":{"type":"line","title":"Sleeping Heart Rate (Last 14 Days)","labels":["7/20","7/21","7/22","7/23","7/24","7/25","7/26","7/27","7/28","7/29","7/30","7/31","8/1","8/2"],"series":[{"name":"P5 Sleeping HR","values":[51,56,64,63,56,54,50,53,52,54,53,56,54,55]},{"name":"P25 HR","values":[55.1,59.6,70.1,68,59.5,57.2,53.1,56.7,55.7,58.2,55.5,59.9,57.2,58.1]},{"name":"Mean HR","values":[59.6,62,74.2,72.5,63.9,60.2,56.3,58.9,59.8,61,62.8,63,60.9,60.2]}]}},{"component":"GridContainer","props":{"columns":2,"children":[{"component":"StatCard","props":{"title":"Mean P5 Sleeping HR","value":55.1,"subtitle":"14-day average floor","trend":"improving"}},{"component":"StatCard","props":{"title":"P5 StdDev (σ)","value":3.9,"subtitle":"Low variation","trend":"neutral"}},{"component":"StatCard","props":{"title":"P5 Variance (σ²)","value":14.9,"subtitle":"Nightly stability","trend":"neutral"}},{"component":"StatCard","props":{"title":"Linear Trend","value":"-0.3 bpm/day","subtitle":"Improving recovery floor","trend":"up"}}]}}]}}';

      final comp = A2UiComponent.tryParse(rawJson);
      expect(comp, isNotNull);
      expect(comp!.component, 'GridContainer');
      expect(comp.children.length, 2);
    });

    test('successfully parses GenUI JSON payload wrapped in Markdown code fences', () {
      const codeFenceJson = '''
```json
{
  "component": "GridContainer",
  "props": {
    "columns": 2,
    "children": [
      {
        "component": "StatCard",
        "props": {
          "title": "Mean P5 Floor",
          "value": 55.1,
          "trend": "up"
        }
      }
    ]
  }
}
```
''';

      final comp = A2UiComponent.tryParse(codeFenceJson);
      expect(comp, isNotNull);
      expect(comp!.component, 'GridContainer');
    });
  });
}
