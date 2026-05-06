// routines_screen.dart — Routines + Programs tabs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'programs/programs_screen.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/rf_cards.dart';
import 'widgets/routine_creator.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _RoutinesHeader(),
              Expanded(
                child: TabBarView(
                  children: [
                    _RoutinesTab(),
                    const ProgramsScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header with title + tab bar ───────────────────────────────────────────────
class _RoutinesHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Routines',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'My Routines'),
              Tab(text: 'Programs'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Routines Tab ──────────────────────────────────────────────────────────────
class _RoutinesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final routines = provider.routines;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: routines.isEmpty
          ? RFEmptyState(
              icon: Icons.list_alt_rounded,
              title: 'No Routines Yet',
              subtitle: 'Create a routine to organize your workouts',
              action: GlowButton(
                label: 'Create Routine',
                icon: Icons.add_rounded,
                onPressed: () => _openCreate(context),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                100,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: routines.length,
              itemBuilder: (_, i) => RoutineCard(
                routine: routines[i],
                getExerciseName: provider.getExerciseName,
                onStart: () => startRoutineWorkoutFlow(context, routines[i]),
                onEdit: () => _openEdit(context, routines[i]),
                onDelete: () => _confirmDelete(context, routines[i], provider),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context),
        backgroundColor: AppColors.primary,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRoutineScreen()),
    );
  }

  void _openEdit(BuildContext context, Routine routine) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateRoutineScreen(routine: routine)),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Routine routine,
    WorkoutProvider provider,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Delete Routine?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Delete "${routine.name}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSoft),
            ),
          ),
          TextButton(
            onPressed: () {
              provider.deleteRoutine(routine.id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
