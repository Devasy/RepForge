import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../workout_flow_screen.dart';
import '../widgets/workout_conflict_dialog.dart';

final _programWorkoutNavigation = Expando<bool>('program workout navigation');

Future<void> startProgramWorkout(
  BuildContext context, {
  required String programId,
  required ProgramDay day,
  required ProgramWeek week,
}) async {
  final provider = context.read<WorkoutProvider>();
  if (_programWorkoutNavigation[provider] == true) return;
  _programWorkoutNavigation[provider] = true;
  try {
    final sameWorkout =
        provider.hasActiveWorkout &&
        provider.activeProgramId == programId &&
        provider.activeProgramDay?.id == day.id &&
        provider.activeProgramWeek?.weekNumber == week.weekNumber;
    var conflict = StartWorkoutConflictAction.cancel;
    final started =
        sameWorkout ||
        await provider.startWorkoutSafely(
          programId: programId,
          programDay: day,
          programWeek: week,
          exerciseIds: day.exercises.map((slot) => slot.exerciseId).toList(),
          onConflict: () async {
            conflict =
                await showWorkoutConflictDialog(
                  context,
                  workoutStartTime: provider.workoutStartTime ?? DateTime.now(),
                ) ??
                StartWorkoutConflictAction.cancel;
            return conflict;
          },
        );
    if (!context.mounted ||
        (!started && conflict != StartWorkoutConflictAction.resume)) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutFlowScreen(
          programDay: provider.activeProgramDay,
          programWeek: provider.activeProgramWeek,
        ),
      ),
    );
  } finally {
    _programWorkoutNavigation[provider] = false;
  }
}
