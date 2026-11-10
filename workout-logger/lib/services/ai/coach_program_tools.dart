import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../workout_provider.dart';

/// Program tools use the coach's existing conversation and approval workflow.
class CoachProgramTools {
  final WorkoutProvider provider;
  CoachProgramTools(this.provider);
  static const names = {
    'get_training_programs',
    'get_program_exercises',
    'create_training_program',
    'follow_training_program',
  };

  static final slotSchema = Schema.object(
    properties: {
      'exerciseId': Schema.string(
        description: 'Exact ID returned by get_program_exercises.',
      ),
      'sets': Schema.integer(),
      'minReps': Schema.integer(),
      'maxReps': Schema.integer(),
      'restSeconds': Schema.integer(),
      'tempo': Schema.string(nullable: true),
      'weightPercentage': Schema.number(nullable: true),
      'notes': Schema.string(nullable: true),
      'supersetGroupId': Schema.string(nullable: true),
    },
    requiredProperties: [
      'exerciseId',
      'sets',
      'minReps',
      'maxReps',
      'restSeconds',
    ],
  );
  static final daySchema = Schema.object(
    properties: {
      'id': Schema.string(
        description: 'Stable day ID, unique within this week.',
      ),
      'name': Schema.string(),
      'dayOfWeek': Schema.integer(
        description: '1=Monday through 7=Sunday; omit for unscheduled.',
        nullable: true,
      ),
      'notes': Schema.string(nullable: true),
      'exercises': Schema.array(items: slotSchema),
    },
    requiredProperties: ['id', 'name', 'exercises'],
  );
  static final weekSchema = Schema.object(
    properties: {
      'weekNumber': Schema.integer(),
      'isDeload': Schema.boolean(),
      'deloadIntensityFactor': Schema.number(),
      'deloadSetReduction': Schema.integer(),
      'phaseId': Schema.string(nullable: true),
      'notes': Schema.string(nullable: true),
      'days': Schema.array(items: daySchema),
    },
    requiredProperties: ['weekNumber', 'days'],
  );
  static final programSchema = Schema.object(
    properties: {
      'name': Schema.string(),
      'description': Schema.string(nullable: true),
      'totalWeeks': Schema.integer(),
      'weeks': Schema.array(items: weekSchema),
      'phases': Schema.array(
        items: Schema.object(
          properties: {
            'id': Schema.string(),
            'name': Schema.string(),
            'startWeek': Schema.integer(),
            'endWeek': Schema.integer(),
            'notes': Schema.string(nullable: true),
            'colorHex': Schema.string(nullable: true),
          },
          requiredProperties: ['id', 'name', 'startWeek', 'endWeek'],
        ),
      ),
    },
    requiredProperties: ['name', 'totalWeeks', 'weeks'],
  );

  static final declarations = [
    FunctionDeclaration(
      'get_training_programs',
      'Read saved training programs, and the currently followed program. Pass program_id to inspect its complete prescriptions. Use before proposing or switching a plan; reuse the conversation instead of asking the user to copy context.',
      Schema.object(properties: {'program_id': Schema.string(nullable: true)}),
    ),
    FunctionDeclaration(
      'get_program_exercises',
      'Read available exercise IDs, names and types for full training programs. Use exact IDs; never guess IDs or create duplicate exercises.',
      Schema.object(properties: {}),
    ),
    FunctionDeclaration(
      'create_training_program',
      'Propose a full program using the current conversation, goals, equipment and retrieved performance. App approval previews every week/day and prescription BEFORE saving one user-owned program. Includes sets, rep range, rest, tempo, load percentage and notes. This does not change the followed program. Repeating identical content returns the same saved program without overwriting edits. Use all numbered weeks (1..totalWeeks), 1..52 weeks, 1..7 days/week and 1..20 exercises/day. Sets 1..12, reps 1..100 with min<=max, rest 0..900 seconds. Do not claim it is saved before success.',
      Schema.object(
        properties: {'program': programSchema},
        requiredProperties: ['program'],
      ),
    ),
    FunctionDeclaration(
      'follow_training_program',
      'Propose following an existing saved program, separately approved by the user. Read get_training_programs first. Include its currently followed ID (or null) to prevent overwriting a choice changed since the proposal. Does not discard an in-progress workout or reset completed days.',
      Schema.object(
        properties: {
          'program_id': Schema.string(),
          'expected_followed_program_id': Schema.string(nullable: true),
        },
        requiredProperties: ['program_id', 'expected_followed_program_id'],
      ),
    ),
  ];

  Future<Map<String, Object?>> handleCall(FunctionCall call) async {
    final manager = provider.programManager;
    if (call.name == 'get_program_exercises') {
      return {
        'exercises': [
          for (final e in provider.allExercises)
            {
              'id': e.id,
              'name': e.name,
              'type': e.exerciseType.name,
              'primaryMuscle': e.primaryMuscle,
            },
        ],
      };
    }
    if (call.name == 'get_training_programs') {
      final id = call.args['program_id'];
      if (id != null) {
        final plan = id is String ? manager.getProgramById(id) : null;
        if (plan == null) {
          return {'error': 'Program not found. List saved programs again.'};
        }
        return {
          'followed_program_id': manager.followedProgram?.id,
          'program': plan.toJson(),
        };
      }
      return {
        'followed_program_id': manager.followedProgram?.id,
        'programs': [
          for (final p in manager.programs)
            {
              'id': p.id,
              'name': p.name,
              'description': p.description,
              'totalWeeks': p.totalWeeks,
              'trainingDays': p.totalDays,
            },
        ],
      };
    }
    if (call.name == 'follow_training_program') {
      if (!call.args.containsKey('expected_followed_program_id')) {
        return {
          'error':
              'Read the current followed program and include expected_followed_program_id.',
        };
      }
      final expected = call.args['expected_followed_program_id'];
      final id = call.args['program_id'];
      if (id is! String || manager.getProgramById(id) == null) {
        return {'error': 'Program not found. Read saved programs again.'};
      }
      if (manager.followedProgram?.id != expected) {
        return {
          'error':
              'The followed program changed since this proposal. Read saved programs and request approval again.',
        };
      }
      try {
        await manager.followProgram(id);
        return {'success': true, 'program_id': id, 'followed': true};
      } catch (_) {
        return {
          'error':
              'Could not follow program. No confirmed switch; please try again.',
        };
      }
    }
    TrainingProgram program;
    try {
      final raw = Map<String, dynamic>.from(call.args['program'] as Map);
      program = TrainingProgram.fromJson({
        ...raw,
        'id': 'pending',
        'phases': raw['phases'] ?? [],
        'author': 'AI Coach',
        'isImported': false,
      });
      _validate(program);
      // Content identity makes retries idempotent without changing user-owned edits.
      final content = program.toJson()
        ..remove('id')
        ..remove('createdAt');
      final id =
          'coach-${const Uuid().v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', jsonEncode(content))}';
      program = program.copyWith(id: id);
    } on FormatException catch (e) {
      return {'error': e.message};
    } catch (_) {
      return {
        'error':
            'Invalid program. Provide complete weeks, days and exercise prescriptions.',
      };
    }
    final existing = manager.getProgramById(program.id);
    if (existing != null) {
      final saved = existing.toJson()..remove('createdAt');
      final proposed = program.toJson()..remove('createdAt');
      if (jsonEncode(saved) != jsonEncode(proposed)) {
        return {
          'error':
              'This plan was already saved and edited. Existing edits were preserved; propose a distinctly named new plan.',
        };
      }
      return {
        'success': true,
        'program_id': existing.id,
        'name': existing.name,
        'already_saved': true,
        'followed': manager.followedProgram?.id == existing.id,
      };
    }
    try {
      await manager.saveProgram(program);
      return {
        'success': true,
        'program_id': program.id,
        'name': program.name,
        'followed': false,
      };
    } catch (_) {
      return {
        'error':
            'Could not save program. Existing programs are unchanged; please try again.',
      };
    }
  }

  void _validate(TrainingProgram p) {
    void check(bool condition, String message) {
      if (!condition) throw FormatException(message);
    }

    check(
      p.name.trim().isNotEmpty && p.name.length <= 120,
      'Program name must be 1..120 characters.',
    );
    check(
      p.totalWeeks >= 1 && p.totalWeeks <= 52 && p.weeks.length == p.totalWeeks,
      'Provide every week from 1 through totalWeeks (1..52).',
    );
    final numbers = <int>{};
    final phases = <String>{};
    for (final phase in p.phases) {
      check(
        phase.id.isNotEmpty &&
            phases.add(phase.id) &&
            phase.name.trim().isNotEmpty &&
            phase.startWeek >= 1 &&
            phase.endWeek >= phase.startWeek &&
            phase.endWeek <= p.totalWeeks,
        'Invalid or duplicate phase.',
      );
    }
    for (final week in p.weeks) {
      check(
        week.weekNumber >= 1 &&
            week.weekNumber <= p.totalWeeks &&
            numbers.add(week.weekNumber),
        'Week numbers must be unique and cover the complete program.',
      );
      check(
        week.phaseId == null || phases.contains(week.phaseId),
        'Unknown phase ID.',
      );
      check(
        week.deloadIntensityFactor.isFinite &&
            week.deloadIntensityFactor > 0 &&
            week.deloadIntensityFactor <= 1 &&
            week.deloadSetReduction >= 0 &&
            week.deloadSetReduction < 12,
        'Invalid deload prescription.',
      );
      check(
        week.days.isNotEmpty && week.days.length <= 7,
        'Each week needs 1..7 training days.',
      );
      final days = <String>{};
      for (final day in week.days) {
        check(
          day.id.isNotEmpty && days.add(day.id) && day.name.trim().isNotEmpty,
          'Day IDs must be unique within a week and names cannot be empty.',
        );
        check(
          day.dayOfWeek == null || (day.dayOfWeek! >= 1 && day.dayOfWeek! <= 7),
          'Weekday must be 1..7 or omitted.',
        );
        check(
          day.exercises.isNotEmpty && day.exercises.length <= 20,
          'Each day needs 1..20 exercises.',
        );
        for (final slot in day.exercises) {
          check(
            provider.getExercise(slot.exerciseId) != null,
            'Unknown exercise ID: ${slot.exerciseId}. Read get_program_exercises.',
          );
          check(
            slot.sets >= 1 &&
                slot.sets <= 12 &&
                slot.minReps >= 1 &&
                slot.maxReps >= slot.minReps &&
                slot.maxReps <= 100 &&
                slot.restSeconds >= 0 &&
                slot.restSeconds <= 900,
            'Invalid sets, rep range or rest duration.',
          );
          check(
            slot.weightPercentage == null ||
                (slot.weightPercentage!.isFinite &&
                    slot.weightPercentage! > 0 &&
                    slot.weightPercentage! <= 100),
            'Load percentage must be greater than 0 and at most 100.',
          );
        }
      }
    }
  }
}
