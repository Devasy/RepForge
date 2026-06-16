// program_week_tile.dart — Collapsible week card for ProgramDetailScreen

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';

// Phase colors shared across programs UI
const List<Color> kProgramPhaseColors = [
  AppColors.primary,
  AppColors.secondary,
  Colors.orange,
  Colors.pink,
  Colors.green,
];

class ProgramWeekTile extends StatefulWidget {
  const ProgramWeekTile({
    super.key,
    required this.week,
    required this.weekIndex,
    required this.program,
    required this.provider,
    required this.onStartDay,
  });

  final ProgramWeek week;
  final int weekIndex;
  final TrainingProgram program;
  final WorkoutProvider provider;
  final void Function(ProgramDay, ProgramWeek) onStartDay;

  @override
  State<ProgramWeekTile> createState() => _ProgramWeekTileState();
}

class _ProgramWeekTileState extends State<ProgramWeekTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final week = widget.week;
    final phase = widget.program.phaseForWeek(week.weekNumber);
    final phaseIdx = phase == null
        ? 0
        : widget.program.phases.indexWhere((p) => p.id == phase.id);
    final phaseColor = phaseIdx >= 0
        ? kProgramPhaseColors[phaseIdx % kProgramPhaseColors.length]
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: week.isDeload
              ? Colors.amber.withValues(alpha: 0.4)
              : AppColors.glassBorder,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(week: week, phase: phase, phaseColor: phaseColor),
          if (_expanded) ...[
            Divider(color: AppColors.glassBorder, height: 1),
            ...week.days.map((day) => _buildDaySection(day, week)),
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
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        week.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSoft,
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

  Widget _buildHeader({
    required ProgramWeek week,
    required TrainingPhase? phase,
    required Color phaseColor,
  }) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: Text(
                'W${week.weekNumber}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
                          Icons.battery_charging_full_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'DELOAD  ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber,
                            fontWeight: FontWeight.w700,
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
                      color: AppColors.textSoft,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(ProgramDay day, ProgramWeek week) {
    final runs = <List<ProgramExerciseSlot>>[];
    String? currentRunKey;
    List<ProgramExerciseSlot> currentRun = [];
    for (final slot in day.exercises) {
      final key = slot.supersetGroupId;
      if (key == null) {
        if (currentRun.isNotEmpty) {
          runs.add(currentRun);
          currentRun = [];
          currentRunKey = null;
        }
        runs.add([slot]);
      } else if (key == currentRunKey) {
        currentRun.add(slot);
      } else {
        if (currentRun.isNotEmpty) runs.add(currentRun);
        currentRunKey = key;
        currentRun = [slot];
      }
    }
    if (currentRun.isNotEmpty) runs.add(currentRun);

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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  day.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (day.dayOfWeek != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _dayName(day.dayOfWeek!),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...runs.map((slots) {
            final isSuperset =
                slots.length > 1 || slots.first.supersetGroupId != null;
            if (isSuperset) {
              return _buildSupersetGroup(slots: slots, week: week);
            }
            return _buildExerciseRow(slot: slots.first, week: week);
          }),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => widget.onStartDay(day, week),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text('Start ${day.name}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildSupersetGroup({
    required List<ProgramExerciseSlot> slots,
    required ProgramWeek week,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.sm, bottom: 2),
            child: Text(
              'SUPERSET',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ...slots.map(
            (slot) => _buildExerciseRow(slot: slot, week: week, indent: true),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow({
    required ProgramExerciseSlot slot,
    required ProgramWeek week,
    bool indent = false,
  }) {
    final exercise = widget.provider.getExercise(slot.exerciseId);
    final name = exercise?.name ?? slot.exerciseId;
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              '$displaySets × $repRange',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
                    color: AppColors.textPrimary,
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
                    if (slot.tempo != null) _infoChip(Icons.speed, slot.tempo!),
                    if (slot.weightPercentage != null)
                      _infoChip(
                        Icons.fitness_center_rounded,
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
                        color: AppColors.textMuted,
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
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  static const _dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String _dayName(int dow) => dow >= 1 && dow <= 7 ? _dayNames[dow] : '';
}
