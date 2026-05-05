// Workout Summary Screen — post-workout trophy view

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final WorkoutSession session;

  const WorkoutSummaryScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final totalSets = session.exercises.fold<int>(
      0,
      (sum, ex) => sum + ex.sets.length,
    );

    // Compute streak
    final sessions = provider.sessions;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final workoutDays = sessions
        .map((s) {
          final d = s.date;
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    int streak = 0;
    if (workoutDays.isNotEmpty) {
      DateTime expected = workoutDays.contains(todayDate)
          ? todayDate
          : todayDate.subtract(const Duration(days: 1));
      for (final day in workoutDays) {
        if (day == expected) {
          streak++;
          expected = expected.subtract(const Duration(days: 1));
        } else if (day.isBefore(expected)) {
          break;
        }
      }
    }

    // Collect muscle groups from this session
    final Map<String, double> muscleVolume = {};
    for (final log in session.exercises) {
      final exercise = provider.getExercise(log.exerciseId);
      if (exercise == null) continue;
      final vol = log.totalVolume;
      for (final activation in exercise.muscleActivations) {
        muscleVolume[activation.muscleGroupId] =
            (muscleVolume[activation.muscleGroupId] ?? 0) +
                vol * (activation.activationPercentage / 100.0);
      }
    }
    final topMuscles = (muscleVolume.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .map((e) => e.key)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  children: [
                    _buildTrophyHeader(session),
                    const SizedBox(height: 28),
                    _buildStatGrid(session, totalSets),
                    const SizedBox(height: 20),
                    if (topMuscles.isNotEmpty)
                      _buildMusclesCard(topMuscles),
                    if (topMuscles.isNotEmpty) const SizedBox(height: 20),
                    _buildStreakCard(streak),
                    const SizedBox(height: 32),
                    _buildDoneButton(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophyHeader(WorkoutSession session) {
    return Column(
      children: [
        // Gradient trophy icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'Workout Complete!',
          style: GoogleFonts.geist(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.fg,
            letterSpacing: -0.04,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Great work. Keep the momentum going.',
          style: GoogleFonts.geist(fontSize: 13, color: AppColors.fg3),
        ),
      ],
    );
  }

  Widget _buildStatGrid(WorkoutSession session, int totalSets) {
    final vol = session.totalVolume;
    final volStr = vol >= 1000
        ? '${(vol / 1000).toStringAsFixed(1)}k'
        : vol.toStringAsFixed(0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RFStatBox(
                label: 'Duration',
                value: '${session.duration}',
                unit: 'min',
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RFStatBox(
                label: 'Volume',
                value: volStr,
                unit: 'kg',
                color: AppColors.data,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RFStatBox(
                label: 'Total Sets',
                value: '$totalSets',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RFStatBox(
                label: 'Exercises',
                value: '${session.exercises.length}',
                color: AppColors.warn,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMusclesCard(List<String> muscles) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MUSCLES WORKED',
            style: GoogleFonts.geist(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.fg4,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: muscles.map((id) {
              final color = AppColors.getMuscleColor(id);
              return RFPillTag(label: _muscleName(id), color: color);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    return GlassCard(
      borderColor: streak > 0
          ? AppColors.warn.withValues(alpha: 0.35)
          : AppColors.border,
      ambientColor: streak > 0 ? AppColors.warn : null,
      ambientRadius: streak > 0 ? 60 : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            streak > 0
                ? Icons.local_fire_department_rounded
                : Icons.fitness_center_rounded,
            color: streak > 0 ? AppColors.warn : AppColors.fg4,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 1
                      ? '$streak day streak!'
                      : streak == 1
                          ? 'Streak started!'
                          : 'First workout!',
                  style: GoogleFonts.geist(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: streak > 0 ? AppColors.warn : AppColors.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak > 0
                      ? 'Come back tomorrow to keep it going'
                      : 'You started — that\'s what matters',
                  style: GoogleFonts.geist(fontSize: 12, color: AppColors.fg3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Center(
              child: Text(
                'DONE',
                style: GoogleFonts.geist(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _muscleName(String id) {
    const names = {
      'chest': 'Chest',
      'upper_chest': 'Upper Chest',
      'back': 'Back',
      'lats': 'Lats',
      'lower_back': 'Lower Back',
      'shoulders': 'Shoulders',
      'front_delts': 'Front Delts',
      'side_delts': 'Side Delts',
      'rear_delts': 'Rear Delts',
      'biceps': 'Biceps',
      'triceps': 'Triceps',
      'forearms': 'Forearms',
      'quads': 'Quads',
      'hamstrings': 'Hamstrings',
      'glutes': 'Glutes',
      'calves': 'Calves',
      'core': 'Core',
      'traps': 'Traps',
    };
    return names[id] ?? id;
  }
}
