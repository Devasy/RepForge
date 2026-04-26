import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';

class WorkoutConflictDialog extends StatelessWidget {
  final DateTime workoutStartTime;

  const WorkoutConflictDialog({super.key, required this.workoutStartTime});

  String _formatStartTime() {
    final now = DateTime.now();
    final isToday =
        now.year == workoutStartTime.year &&
        now.month == workoutStartTime.month &&
        now.day == workoutStartTime.day;

    return isToday
        ? DateFormat('HH:mm').format(workoutStartTime)
        : DateFormat('MMM d HH:mm').format(workoutStartTime);
  }

  @override
  Widget build(BuildContext context) {
    final formattedStart = _formatStartTime();

    return AlertDialog(
      title: const Text('Workout already in progress'),
      content: Text('You have an unfinished workout from $formattedStart.'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(StartWorkoutConflictAction.resume),
          child: const Text('Resume'),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(StartWorkoutConflictAction.discardAndStart),
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: const Text('Discard & start new'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(StartWorkoutConflictAction.cancel),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

Future<StartWorkoutConflictAction?> showWorkoutConflictDialog(
  BuildContext context, {
  required DateTime workoutStartTime,
}) {
  return showDialog<StartWorkoutConflictAction>(
    context: context,
    builder: (context) =>
        WorkoutConflictDialog(workoutStartTime: workoutStartTime),
  );
}
