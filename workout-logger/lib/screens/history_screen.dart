// History Screen - View past workout sessions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'edit_workout_session_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final sessions = provider.sessions;

    return Scaffold(
      appBar: AppBar(title: const Text('Workout History')),
      body: sessions.isEmpty
          ? _buildEmptyState(context)
          : _buildSessionList(context, sessions, provider),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'No Workout History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a workout to see it here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(
    BuildContext context,
    List<WorkoutSession> sessions,
    WorkoutProvider provider,
  ) {
    // Group sessions by month
    final groupedSessions = <String, List<WorkoutSession>>{};
    for (var session in sessions) {
      final monthKey = DateFormat('MMMM yyyy').format(session.date);
      groupedSessions.putIfAbsent(monthKey, () => []).add(session);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: groupedSessions.length,
      itemBuilder: (context, index) {
        final month = groupedSessions.keys.elementAt(index);
        final monthSessions = groupedSessions[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                month,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ...monthSessions.map(
              (session) => _SessionCard(session: session, provider: provider),
            ),
          ],
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutProvider provider;

  const _SessionCard({required this.session, required this.provider});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => _showSessionDetails(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(session.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    timeFormat.format(session.date),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _buildStat(
                    Icons.fitness_center,
                    '${session.exercises.length} exercises',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _buildStat(Icons.timer_outlined, '${session.duration} min'),
                  const SizedBox(width: AppSpacing.md),
                  _buildStat(
                    Icons.trending_up,
                    '${(session.totalVolume / 1000).toStringAsFixed(1)}k kg',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: session.exercises.take(4).map((log) {
                  final exerciseName = provider.getExerciseName(log.exerciseId);
                  return Chip(
                    label: Text(
                      exerciseName,
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              if (session.exercises.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${session.exercises.length - 4} more',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  void _showSessionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _SessionDetailsSheet(
          session: session,
          provider: provider,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _SessionDetailsSheet extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutProvider provider;
  final ScrollController scrollController;

  const _SessionDetailsSheet({
    required this.session,
    required this.provider,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Action Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Edit Button
            TextButton.icon(
              onPressed: () => _editSession(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            // Delete Button
            TextButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Header
        Text(
          dateFormat.format(session.date),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${timeFormat.format(session.date)} • ${session.duration} minutes',
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _StatBox(
                value: '${session.exercises.length}',
                label: 'Exercises',
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatBox(
                value:
                    '${session.exercises.fold<int>(0, (sum, e) => sum + e.sets.length)}',
                label: 'Total Sets',
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatBox(
                value: '${(session.totalVolume / 1000).toStringAsFixed(1)}k',
                label: 'Volume (kg)',
                color: AppTheme.success,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),

        // Exercises
        ...session.exercises.map(
          (log) => _ExerciseDetailCard(log: log, provider: provider),
        ),

        if (session.notes != null && session.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Notes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(session.notes!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  void _editSession(BuildContext context) {
    // Capture navigator before pop to avoid using deactivated context
    final navigator = Navigator.of(context);
    navigator.pop(); // Close the bottom sheet first
    navigator.push<bool>(
      MaterialPageRoute(
        builder: (context) => EditWorkoutSessionScreen(session: session),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Workout?'),
        content: Text(
          'Are you sure you want to delete this workout from ${DateFormat('MMMM d, yyyy').format(session.date)}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await provider.deleteWorkoutSession(session.id);
        if (context.mounted) {
          // Ideally we can trust navigator if it's still valid, but keep check for safety
          navigator.pop(); // Close the bottom sheet
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success),
                  SizedBox(width: 8),
                  Text('Workout deleted'),
                ],
              ),
              backgroundColor: AppTheme.cardColor,
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to delete workout session: $e');
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to delete workout. Please try again.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  final ExerciseLog log;
  final WorkoutProvider provider;

  const _ExerciseDetailCard({required this.log, required this.provider});

  @override
  Widget build(BuildContext context) {
    final exercise = provider.getExercise(log.exerciseId);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exercise?.name ?? 'Unknown Exercise',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${log.sets.length} sets',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...log.sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${set.weight} kg × ${set.reps} reps',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '${set.volume.toStringAsFixed(0)} kg',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (set.isDropset) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DROP',
                        style: TextStyle(
                          color: AppTheme.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ${log.totalVolume.toStringAsFixed(0)} kg',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
