// Program Detail Screen
//
// Shows a full training program: phase timeline, week list with deload badges,
// and per-day exercise details (sets, rep range, rest, tempo, weight%, notes).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show FontFeature;

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';

class ProgramDetailScreen extends StatefulWidget {
  final TrainingProgram program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  late TrainingProgram _program;
  int? _expandedWeekIndex;

  @override
  void initState() {
    super.initState();
    _program = widget.program;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_program.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export', child: Text('Export JSON')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_program.phases.isNotEmpty)
            SliverToBoxAdapter(child: _buildPhaseTimeline()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'WEEKS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildWeekTile(index),
              childCount: _program.weeks.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final deloadCount = _program.weeks.where((w) => w.isDeload).length;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_program.description != null) ...[
            Text(
              _program.description!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              _statChip(
                Icons.calendar_today,
                '${_program.totalWeeks} weeks',
                AppTheme.primaryColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              _statChip(
                Icons.bolt,
                '${_program.phases.length} phases',
                AppTheme.secondaryColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              if (deloadCount > 0)
                _statChip(
                  Icons.battery_charging_full,
                  '$deloadCount deload${deloadCount > 1 ? 's' : ''}',
                  Colors.amber,
                ),
            ],
          ),
          if (_program.author != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'by ${_program.author}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
          if (_program.isImported) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.download, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Imported',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase Timeline ────────────────────────────────────────────────────

  static const List<Color> _phaseColors = [
    AppTheme.primaryColor,
    AppTheme.secondaryColor,
    Colors.orange,
    Colors.pink,
    Colors.green,
  ];

  Widget _buildPhaseTimeline() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PHASES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Visual timeline bar
          SizedBox(
            height: 8,
            child: Row(
              children: _program.phases.asMap().entries.map((entry) {
                final phase = entry.value;
                final fraction =
                    (phase.endWeek - phase.startWeek + 1) / _program.totalWeeks;
                final color =
                    _phaseColors[entry.key % _phaseColors.length];
                return Expanded(
                  flex: ((fraction * 100).round()).clamp(1, 100),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: _program.phases.asMap().entries.map((entry) {
              final phase = entry.value;
              final color = _phaseColors[entry.key % _phaseColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${phase.name} (W${phase.startWeek}–${phase.endWeek})',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Week Tile ────────────────────────────────────────────────────────

  Widget _buildWeekTile(int index) {
    final week = _program.weeks[index];
    final isExpanded = _expandedWeekIndex == index;
    final phase = _program.phaseForWeek(week.weekNumber);
    final phaseIdx = phase == null
        ? 0
        : _program.phases.indexWhere((p) => p.id == phase.id);
    final phaseColor = phaseIdx >= 0
        ? _phaseColors[phaseIdx % _phaseColors.length]
        : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: week.isDeload
            ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedWeekIndex = isExpanded ? null : index;
            }),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: phaseColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'W${week.weekNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: phaseColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (week.isDeload) ...[
                              const Icon(
                                Icons.battery_charging_full,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'DELOAD  ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                            if (phase != null)
                              Text(
                                phase.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: phaseColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${week.days.length} day${week.days.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (week.isDeload)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Text(
                        '${((week.deloadIntensityFactor) * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(
              height: 1,
              color: AppTheme.surfaceColor,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
            ...week.days.map(
              (day) => _buildDaySection(day, week),
            ),
            if (week.notes != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        week.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Day Section ─────────────────────────────────────────────────────

  Widget _buildDaySection(ProgramDay day, ProgramWeek week) {
    final provider = context.read<WorkoutProvider>();

    // Group exercises by superset group
    final supersetGroups = <String?, List<ProgramExerciseSlot>>{};
    for (final slot in day.exercises) {
      final key = slot.supersetGroupId;
      supersetGroups.putIfAbsent(key, () => []).add(slot);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  day.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (day.dayOfWeek != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _dayName(day.dayOfWeek!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Render standalone exercises and superset groups
          ...supersetGroups.entries.map((entry) {
            final slots = entry.value;
            final isSuperset = entry.key != null;
            if (isSuperset) {
              return _buildSupersetGroup(slots, provider, week);
            }
            return Column(
              children: slots
                  .map((slot) => _buildExerciseRow(slot, provider, week))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSupersetGroup(
    List<ProgramExerciseSlot> slots,
    WorkoutProvider provider,
    ProgramWeek week,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppTheme.secondaryColor.withOpacity(0.6),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: 2),
            child: Text(
              'SUPERSET',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ...slots.map(
            (slot) => _buildExerciseRow(slot, provider, week, indent: true),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
    ProgramExerciseSlot slot,
    WorkoutProvider provider,
    ProgramWeek week, {
    bool indent = false,
  }) {
    final exercise = provider.getExercise(slot.exerciseId);
    final name = exercise?.name ?? slot.exerciseId;

    // Apply deload adjustments for display
    final displaySets =
        week.isDeload ? (slot.sets - week.deloadSetReduction).clamp(1, 99) : slot.sets;
    final displayIntensity = week.isDeload ? week.deloadIntensityFactor : 1.0;

    final repRange = slot.minReps == slot.maxReps
        ? '${slot.minReps}'
        : '${slot.minReps}–${slot.maxReps}';

    return Padding(
      padding: EdgeInsets.only(
        left: indent ? AppSpacing.md : 0,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sets × Reps badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '$displaySets × $repRange',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 2,
                  children: [
                    _infoChip(
                      Icons.timer_outlined,
                      '${slot.restSeconds}s rest',
                    ),
                    if (slot.tempo != null)
                      _infoChip(Icons.speed, slot.tempo!),
                    if (slot.weightPercentage != null)
                      _infoChip(
                        Icons.fitness_center,
                        week.isDeload
                            ? '${(slot.weightPercentage! * displayIntensity).toStringAsFixed(0)}%'
                            : '${slot.weightPercentage!.toStringAsFixed(0)}%',
                      ),
                  ],
                ),
                if (slot.notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      slot.notes!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppTheme.textMuted),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'export':
        _exportProgram();
      case 'delete':
        _confirmDelete();
    }
  }

  void _exportProgram() {
    final provider = context.read<WorkoutProvider>();
    final json = provider.programManager.exportToJson(_program);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Program'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copied to clipboard')),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Program?'),
        content: Text('Delete "${_program.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<WorkoutProvider>();
              await provider.programManager.deleteProgram(_program.id);
              if (mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // go back to list
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Utils ────────────────────────────────────────────────────────────

  static const _dayNames = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String _dayName(int dow) => dow >= 1 && dow <= 7 ? _dayNames[dow] : '';
}
