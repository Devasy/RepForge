import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/workout_provider.dart';

/// Render the actual proposed tool arguments, not a separately generated summary.
class AgentChangeDetails extends StatelessWidget {
  final String tool;
  final Map<String, Object?> arguments;
  const AgentChangeDetails({
    super.key,
    required this.tool,
    required this.arguments,
  });
  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider?>();
    if (tool == 'follow_training_program') {
      final id = arguments['program_id'] as String?;
      final expected = arguments['expected_followed_program_id'] as String?;
      final target =
          provider?.programManager.getProgramById(id ?? '')?.name ??
          id ??
          'Unknown program';
      final prior =
          provider?.programManager.getProgramById(expected ?? '')?.name ??
          expected;
      return Text(
        'Follow $target.\n${prior == null ? 'No program is currently followed.' : 'Replace followed program: $prior.'}\nSaved plans, completed days and any in-progress workout are kept.',
      );
    }
    if (tool != 'create_training_program') {
      return Text(
        arguments.entries
            .where((e) => e.value != null)
            .map(
              (e) =>
                  '${e.key.replaceAll('_', ' ')}: ${e.value is List ? (e.value! as List).join(', ') : e.value}',
            )
            .join('\n'),
      );
    }
    TrainingProgram plan;
    try {
      final raw = Map<String, dynamic>.from(arguments['program'] as Map);
      plan = TrainingProgram.fromJson({
        ...raw,
        'id': 'preview',
        'phases': raw['phases'] ?? [],
      });
    } catch (_) {
      return const Text(
        'This program proposal is incomplete. Ask the coach to correct it before saving.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
        Text('${plan.totalWeeks} weeks · Save as a new program'),
        const Text('Your followed program will not change.'),
        if (plan.description != null) Text(plan.description!),
        for (final phase in plan.phases)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${phase.name} · Weeks ${phase.startWeek}–${phase.endWeek}${phase.notes == null ? '' : '\n${phase.notes}'}',
            ),
          ),
        for (final week in plan.weeks) ...[
          const SizedBox(height: 16),
          Text(
            'Week ${week.weekNumber}${week.isDeload ? ' · Deload' : ''}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (week.isDeload)
            Text(
              'Load factor: ${week.deloadIntensityFactor} · Reduce sets by ${week.deloadSetReduction}',
            ),
          if (week.notes != null) Text(week.notes!),
          for (final day in week.days) ...[
            const SizedBox(height: 8),
            Text(
              '${day.name}${day.dayOfWeek != null && day.dayOfWeek! >= 1 && day.dayOfWeek! <= 7 ? ' · ${const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day.dayOfWeek! - 1]}' : ''}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (day.notes != null) Text(day.notes!),
            for (final slot in day.exercises)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  [
                    provider?.getExerciseName(slot.exerciseId) ??
                        slot.exerciseId,
                    '${slot.sets} sets · ${slot.minReps == slot.maxReps ? slot.minReps : '${slot.minReps}–${slot.maxReps}'} reps · ${slot.restSeconds}s rest',
                    if (slot.tempo != null) 'Tempo: ${slot.tempo}',
                    if (slot.weightPercentage != null)
                      'Load percentage: ${slot.weightPercentage}%',
                    if (slot.supersetGroupId != null)
                      'Superset group: ${slot.supersetGroupId}',
                    if (slot.notes != null) slot.notes!,
                  ].join('\n'),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
