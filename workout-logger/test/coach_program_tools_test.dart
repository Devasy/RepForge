import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/orchestration/repforge_tools.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/program_tool_fixture.dart';

class _SaveFailStorage extends MockStorageService {
  bool fail = false;
  @override
  Future<void> saveTrainingProgram(TrainingProgram program) async {
    if (fail) throw StateError('unavailable');
    await super.saveTrainingProgram(program);
  }
}

void main() {
  late _SaveFailStorage storage;
  late WorkoutProvider wp;
  late CoachToolService tools;
  setUp(() async {
    storage = _SaveFailStorage();
    wp = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    await wp.init();
    tools = CoachToolService(
      workoutProvider: wp,
      prManager: PRManager(storage),
    );
  });
  Future<Map<String, Object?>> create(Map<String, Object?> program) =>
      tools.handleCall(
        FunctionCall('create_training_program', {'program': program}),
      );
  test(
    'full program is saved once with exact prescriptions, without changing followed plan',
    () async {
      final result = await create(programToolFixture());
      expect(result['error'], isNull);
      final programs = wp.programManager.programs;
      expect(programs, hasLength(1));
      expect(wp.programManager.followedProgram, isNull);
      final slot = programs.single.weeks.first.days.first.exercises.single;
      expect(
        [slot.sets, slot.minReps, slot.maxReps, slot.restSeconds, slot.tempo],
        [3, 8, 10, 90, '2-1-1'],
      );
      final repeated = await create(programToolFixture());
      expect(repeated['program_id'], result['program_id']);
      expect(wp.programManager.programs, hasLength(1));
      await wp.programManager.saveProgram(
        programs.single.copyWith(name: 'User edited'),
      );
      expect((await create(programToolFixture()))['error'], isNotNull);
      expect(wp.programManager.programs.single.name, 'User edited');
    },
  );
  test(
    'read tools expose real exercises and existing followed program',
    () async {
      final result = await create(programToolFixture());
      await wp.programManager.followProgram(result['program_id']! as String);
      final plans = await tools.handleCall(
        FunctionCall('get_training_programs', {}),
      );
      expect(plans['followed_program_id'], result['program_id']);
      expect(plans['programs'], isNotEmpty);
      final exercises = await tools.handleCall(
        FunctionCall('get_program_exercises', {}),
      );
      expect(
        (exercises['exercises']! as List).any(
          (e) => (e as Map)['id'] == 'bench_press',
        ),
        isTrue,
      );
    },
  );
  test('invalid prescriptions and unknown exercises never save', () async {
    for (final invalid in ['unknown', 'reps', 'weeks']) {
      final data = programToolFixture();
      final weeks = data['weeks']! as List;
      final slot =
          ((weeks.first as Map)['days'] as List).first['exercises'][0] as Map;
      if (invalid == 'unknown') slot['exerciseId'] = 'invented';
      if (invalid == 'reps') slot['minReps'] = 20;
      if (invalid == 'weeks') data['totalWeeks'] = 3;
      expect((await create(data))['error'], isNotNull);
      expect(wp.programManager.programs, isEmpty);
    }
  });
  test('failed save leaves plans unchanged and can be retried', () async {
    storage.fail = true;
    expect((await create(programToolFixture()))['error'], isNotNull);
    expect(wp.programManager.programs, isEmpty);
    storage.fail = false;
    expect((await create(programToolFixture()))['error'], isNull);
    expect(wp.programManager.programs, hasLength(1));
  });
  test('following checks the exact prior choice before switching', () async {
    final first = (await create(programToolFixture()))['program_id']! as String;
    final secondData = programToolFixture()..['name'] = 'Other plan';
    final second = (await create(secondData))['program_id']! as String;
    final followed = await tools.handleCall(
      FunctionCall('follow_training_program', {
        'program_id': first,
        'expected_followed_program_id': null,
      }),
    );
    expect(followed['error'], isNull);
    final conflict = await tools.handleCall(
      FunctionCall('follow_training_program', {
        'program_id': second,
        'expected_followed_program_id': null,
      }),
    );
    expect(conflict['error'], isNotNull);
    expect(wp.programManager.followedProgram?.id, first);
    expect(
      (await tools.handleCall(
        FunctionCall('follow_training_program', {
          'program_id': second,
          'expected_followed_program_id': first,
        }),
      ))['error'],
      isNull,
    );
    expect(wp.programManager.followedProgram?.id, second);
  });
  test('program creation and following are approval-protected writes', () {
    expect(
      RepForgeTool.writes,
      containsAll(['create_training_program', 'follow_training_program']),
    );
  });
}
