// exercise_library_screen.dart — Browse and search the exercise library

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import '../data/exercise_database.dart';
import 'add_custom_exercise_screen.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/rf_cards.dart';
import 'widgets/exercise_details_sheet.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  String? _muscleFilter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final all = provider.allExercises;
    final customCount = all.where((e) => e.isCustom).length;

    final filtered = all.where((e) {
      final matchQ = _query.isEmpty ||
          e.name.toLowerCase().contains(_query.toLowerCase());
      final matchM = _muscleFilter == null ||
          e.muscleActivations.any((m) => m.muscleGroupId == _muscleFilter);
      return matchQ && matchM;
    }).toList()
      ..sort((a, b) {
        if (a.isCustom && !b.isCustom) return -1;
        if (!a.isCustom && b.isCustom) return 1;
        return a.name.compareTo(b.name);
      });

    final grouped = <String, List<Exercise>>{};
    for (final ex in filtered) {
      grouped.putIfAbsent(ex.primaryMuscle, () => []).add(ex);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(customCount: customCount),
            _SearchBar(
              query: _query,
              onChanged: (v) => setState(() => _query = v),
            ),
            _MuscleFilterChips(
              selected: _muscleFilter,
              onSelected: (id) => setState(() => _muscleFilter = id),
            ),
            Expanded(
              child: grouped.isEmpty
                  ? RFEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No exercises found',
                      subtitle: 'Try a different search or filter',
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        100,
                      ),
                      itemCount: grouped.length,
                      itemBuilder: (_, i) {
                        final muscleId = grouped.keys.elementAt(i);
                        final exercises = grouped[muscleId]!;
                        return _MuscleGroup(
                          muscleId: muscleId,
                          exercises: exercises,
                          onTap: (ex) => _openDetails(context, ex, provider),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: AppBreakpoints.navBarClearance),
        child: FloatingActionButton(
          onPressed: () => Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddCustomExerciseScreen()),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }

  void _openDetails(
    BuildContext context,
    Exercise exercise,
    WorkoutProvider provider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => ExerciseDetailsSheet(
        exercise: exercise,
        provider: provider,
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.customCount});
  final int customCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const Text(
            'Exercises',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (customCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$customCount custom',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.query, required this.onChanged});
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search exercises…',
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
            suffixIcon: query.isNotEmpty
                ? GestureDetector(
                    onTap: () => onChanged(''),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

// ── Muscle filter chips ────────────────────────────────────────────────────────
class _MuscleFilterChips extends StatelessWidget {
  const _MuscleFilterChips({required this.selected, required this.onSelected});
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          _Chip(
            label: 'All',
            isSelected: selected == null,
            color: AppColors.primary,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 6),
          ...MuscleGroups.names.entries.map((e) {
            final color = AppColors.muscle(e.key);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip(
                label: e.value,
                isSelected: selected == e.key,
                color: color,
                onTap: () => onSelected(selected == e.key ? null : e.key),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Muscle group section ───────────────────────────────────────────────────────
class _MuscleGroup extends StatelessWidget {
  const _MuscleGroup({
    required this.muscleId,
    required this.exercises,
    required this.onTap,
  });
  final String muscleId;
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.muscle(muscleId);
    final name = MuscleGroups.names[muscleId] ?? muscleId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${exercises.length}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ...exercises.map(
          (ex) => ExerciseCard(
            exercise: ex,
            onTap: () => onTap(ex),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

// ── Exercise Selector Screen (used by workout flow for quick start) ────────────
class ExerciseSelectorScreen extends StatefulWidget {
  const ExerciseSelectorScreen({
    super.key,
    this.selectionMode = false,
    this.onExercisesSelected,
  });

  final bool selectionMode;
  final void Function(List<String>)? onExercisesSelected;

  @override
  State<ExerciseSelectorScreen> createState() =>
      _ExerciseSelectorScreenState();
}

class _ExerciseSelectorScreenState extends State<ExerciseSelectorScreen> {
  final Set<String> _selectedIds = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = context.watch<WorkoutProvider>().allExercises;
    final filtered = all
        .where(
          (e) => _query.isEmpty ||
              e.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final grouped = <String, List<Exercise>>{};
    for (final ex in filtered) {
      grouped.putIfAbsent(ex.primaryMuscle, () => []).add(ex);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search exercises…',
                hintStyle:
                    TextStyle(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        if (widget.selectionMode && _selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedIds.clear()),
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: grouped.length,
            itemBuilder: (_, i) {
              final muscleId = grouped.keys.elementAt(i);
              final exercises = grouped[muscleId]!;
              final name = MuscleGroups.names[muscleId] ?? muscleId;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: RFSectionHeader(name),
                  ),
                  ...exercises.map((ex) {
                    final sel = _selectedIds.contains(ex.id);
                    return ExerciseCard(
                      exercise: ex,
                      selected: sel,
                      onTap: () => setState(() {
                        if (sel) {
                          _selectedIds.remove(ex.id);
                        } else {
                          _selectedIds.add(ex.id);
                        }
                      }),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        if (widget.selectionMode)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: GlowButton(
              label: 'Start with ${_selectedIds.length} exercises',
              icon: Icons.play_arrow_rounded,
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () =>
                      widget.onExercisesSelected?.call(_selectedIds.toList()),
              fullWidth: true,
            ),
          ),
      ],
    );
  }
}
