// History Screen — session timeline with lifetime banner

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/managers/history_manager.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'edit_workout_session_screen.dart';
import 'widgets/rf_widgets.dart';

// Teal color shared by the HC badge and sync status indicators.
const Color _hcColor = Color(0xFF00BFA5);

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch HistoryManager so the list rebuilds when hcSyncedAt changes.
    final historyManager = context.watch<HistoryManager>();
    final provider = context.read<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final sessions = historyManager.sessions;

    final hasUnsynced = settings.healthConnectEnabled &&
        sessions.any((s) => s.hcSyncedAt == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          if (hasUnsynced)
            IconButton(
              icon: const Icon(Icons.monitor_heart_outlined, color: _hcColor),
              tooltip: 'Sync all to Health Connect',
              onPressed: () {
                historyManager.syncAllUnsynced();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Syncing all unsynced workouts…'),
                    backgroundColor: AppTheme.cardColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
      body: sessions.isEmpty
          ? _buildEmptyState(context)
          : _buildSessionList(context, sessions, provider, historyManager),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, size: 56, color: AppColors.fg4),
          const SizedBox(height: 16),
          Text(
            'No Workout History',
            style: GoogleFonts.geist(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.fg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete a workout to see it here',
            style: GoogleFonts.geist(fontSize: 13, color: AppColors.fg3),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(
    BuildContext context,
    List<WorkoutSession> sessions,
    WorkoutProvider provider,
    HistoryManager historyManager,
  ) {
    // Lifetime stats for the banner
    final totalVolume =
        sessions.fold<double>(0, (s, w) => s + w.totalVolume);
    final totalSets = sessions.fold<int>(
      0,
      (s, w) => s + w.exercises.fold<int>(0, (a, e) => a + e.sets.length),
    );
    // Group sessions by month
    final groupedSessions = <String, List<WorkoutSession>>{};
    for (final session in sessions) {
      final key = DateFormat('MMMM yyyy').format(session.date);
      groupedSessions.putIfAbsent(key, () => []).add(session);
    }

    return CustomScrollView(
      slivers: [
        // ── Lifetime summary banner ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Row(
                children: [
                  _LifetimeStat(
                    label: 'SESSIONS',
                    value: '${sessions.length}',
                    color: AppColors.accent,
                  ),
                  _LifetimeDivider(),
                  _LifetimeStat(
                    label: 'TOTAL SETS',
                    value: '$totalSets',
                    color: AppColors.data,
                  ),
                  _LifetimeDivider(),
                  _LifetimeStat(
                    label: totalVolume >= 1000000 ? 'VOLUME (t)' : 'VOLUME (k)',
                    value: totalVolume >= 1000000
                        ? (totalVolume / 1000000).toStringAsFixed(1)
                        : (totalVolume / 1000).toStringAsFixed(1),
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Month-grouped session list ──
        for (final entry in groupedSessions.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    entry.key.toUpperCase(),
                    style: GoogleFonts.geist(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fg4,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value.length}',
                    style: GoogleFonts.geist(fontSize: 10, color: AppColors.fg4),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _SessionCard(
                  session: entry.value[i],
                  provider: provider,
                  historyManager: historyManager,
                ),
                childCount: entry.value.length,
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _LifetimeStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LifetimeStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.geistMono(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.04,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.fg4,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifetimeDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutProvider provider;
  final HistoryManager historyManager;

  const _SessionCard({
    required this.session,
    required this.provider,
    required this.historyManager,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isSynced = session.hcSyncedAt != null;
    final showSyncOption = !isSynced && settings.healthConnectEnabled;

    final dayStr = DateFormat('EEE').format(session.date).toUpperCase();
    final dateNum = DateFormat('d').format(session.date);
    final monthStr = DateFormat('MMM').format(session.date);
    final vol = session.totalVolume;
    final volStr = vol >= 1000
        ? '${(vol / 1000).toStringAsFixed(1)}k'
        : vol.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => _showSessionDetails(context),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date column
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(
                    dayStr,
                    style: GoogleFonts.geist(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fg4,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dateNum,
                    style: GoogleFonts.geistMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                      letterSpacing: -0.04,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    monthStr,
                    style: GoogleFonts.geist(fontSize: 9, color: AppColors.fg3),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 52,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '${session.exercises.length} exercises · ${session.duration} min',
                              style: GoogleFonts.geist(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.fg,
                              ),
                            ),
                            if (isSynced) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Synced to Health Connect',
                                child: Icon(Icons.monitor_heart,
                                    color: _hcColor, size: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Volume
                      Text(
                        '$volStr kg',
                        style: GoogleFonts.geistMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                          letterSpacing: -0.02,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      _SessionMenu(
                        session: session,
                        provider: provider,
                        historyManager: historyManager,
                        showSyncOption: showSyncOption,
                        onDetailRequested: () => _showSessionDetails(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Exercise pill tags
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      ...session.exercises.take(3).map((log) {
                        final name = provider.getExerciseName(log.exerciseId);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            name,
                            style: GoogleFonts.geist(
                                fontSize: 10, color: AppColors.fg3),
                          ),
                        );
                      }),
                      if (session.exercises.length > 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '+${session.exercises.length - 3}',
                            style: GoogleFonts.geist(
                                fontSize: 10, color: AppColors.fg4),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          historyManager: historyManager,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ── 3-button popup menu ────────────────────────────────────────────────────────

enum _SessionMenuAction { edit, syncHc, delete }

class _SessionMenu extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutProvider provider;
  final HistoryManager historyManager;
  final bool showSyncOption;
  final VoidCallback onDetailRequested;

  const _SessionMenu({
    required this.session,
    required this.provider,
    required this.historyManager,
    required this.showSyncOption,
    required this.onDetailRequested,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SessionMenuAction>(
      icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _SessionMenuAction.edit,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
            title: Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
          ),
        ),
        if (showSyncOption)
          const PopupMenuItem(
            value: _SessionMenuAction.syncHc,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.monitor_heart_outlined, color: _hcColor),
              title: Text(
                'Sync to Health Connect',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ),
        const PopupMenuItem(
          value: _SessionMenuAction.delete,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: AppTheme.error),
            title: Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, _SessionMenuAction action) {
    switch (action) {
      case _SessionMenuAction.edit:
        Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EditWorkoutSessionScreen(session: session),
          ),
        );
      case _SessionMenuAction.syncHc:
        historyManager.syncSession(session);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Syncing to Health Connect…'),
              ],
            ),
            backgroundColor: AppTheme.cardColor,
            duration: Duration(seconds: 2),
          ),
        );
      case _SessionMenuAction.delete:
        _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Workout?'),
        content: Text(
          'Are you sure you want to delete this workout from '
          '${DateFormat('MMMM d, yyyy').format(session.date)}? '
          'This action cannot be undone.',
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
      final messenger = ScaffoldMessenger.of(context);
      try {
        await provider.deleteWorkoutSession(session.id);
        if (context.mounted) {
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

// ── Detail bottom sheet ────────────────────────────────────────────────────────

class _SessionDetailsSheet extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutProvider provider;
  final HistoryManager historyManager;
  final ScrollController scrollController;

  const _SessionDetailsSheet({
    required this.session,
    required this.provider,
    required this.historyManager,
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(session.date),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${timeFormat.format(session.date)} • ${session.duration} minutes',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (session.hcSyncedAt != null)
              Tooltip(
                message:
                    'Synced to Health Connect\n${DateFormat('MMM d, h:mm a').format(session.hcSyncedAt!)}',
                child: const Icon(Icons.monitor_heart, color: _hcColor, size: 20),
              ),
          ],
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
    final navigator = Navigator.of(context);
    navigator.pop();
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
          navigator.pop();
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
