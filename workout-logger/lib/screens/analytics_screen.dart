// Analytics Screen - Visualize progress with charts

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import '../data/exercise_database.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Exercises'),
            Tab(text: 'Targets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _ExercisesTab(),
          _TargetsTab(),
        ],
      ),
    );
  }
}

// ==================== Overview Tab ====================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVolumeChart(context, provider),
          const SizedBox(height: AppSpacing.lg),
          _buildMuscleVolumeChart(context, provider),
          const SizedBox(height: AppSpacing.lg),
          _buildWorkoutFrequency(context, provider),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(BuildContext context, WorkoutProvider provider) {
    final sessions = provider.sessions.take(14).toList().reversed.toList();
    
    if (sessions.isEmpty) {
      return _buildEmptyChart(context, 'Volume Progression');
    }

    final spots = sessions.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalVolume / 1000);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Volume Progression (kg)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Last ${sessions.length} workouts',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.surfaceColor,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sessions.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('d/M').format(sessions[index].date),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toStringAsFixed(0)}k',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: AppTheme.primaryColor,
                        strokeWidth: 2,
                        strokeColor: AppTheme.cardColor,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.3),
                          AppTheme.primaryColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleVolumeChart(BuildContext context, WorkoutProvider provider) {
    final volumeByMuscle = provider.getWeeklyVolumeByMuscle();
    
    if (volumeByMuscle.isEmpty) {
      return _buildEmptyChart(context, 'Weekly Muscle Volume');
    }

    // Sort by volume and take top 8
    final sorted = volumeByMuscle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxVolume = top.first.value;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Muscle Volume',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ...top.map((entry) {
            final muscleName = MuscleGroups.names[entry.key] ?? entry.key;
            final color = AppTheme.getMuscleColor(entry.key);
            final percentage = entry.value / maxVolume;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        muscleName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${(entry.value / 1000).toStringAsFixed(1)}k kg',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppTheme.surfaceColor,
                    valueColor: AlwaysStoppedAnimation(color),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWorkoutFrequency(BuildContext context, WorkoutProvider provider) {
    // Calculate workouts per week for last 4 weeks
    final now = DateTime.now();
    final weeks = <int, int>{};
    
    for (int i = 0; i < 4; i++) {
      weeks[i] = 0;
    }

    for (var session in provider.sessions) {
      final weeksAgo = now.difference(session.date).inDays ~/ 7;
      if (weeksAgo < 4) {
        weeks[weeksAgo] = (weeks[weeksAgo] ?? 0) + 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Frequency',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weeks.entries.map((entry) {
              final label = entry.key == 0 
                  ? 'This Week' 
                  : '${entry.key} week${entry.key > 1 ? 's' : ''} ago';
              return Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(
                        entry.value > 0 ? 0.2 + (entry.value * 0.15) : 0.1
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: entry.value > 0 
                              ? AppTheme.primaryColor 
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.key == 0 ? 'This' : '-${entry.key}w',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
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

  Widget _buildEmptyChart(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Icon(
            Icons.show_chart,
            size: 48,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No data yet',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const Text(
            'Complete workouts to see your progress',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ==================== Exercises Tab ====================

class _ExercisesTab extends StatefulWidget {
  const _ExercisesTab();

  @override
  State<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<_ExercisesTab> {
  String? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    
    // Get exercises that have been performed
    final performedExercises = <String>{};
    for (var session in provider.sessions) {
      for (var log in session.exercises) {
        performedExercises.add(log.exerciseId);
      }
    }

    if (performedExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No Exercise Data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete workouts to track exercises',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Exercise selector
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DropdownButtonFormField<String>(
            value: _selectedExerciseId,
            decoration: const InputDecoration(
              labelText: 'Select Exercise',
              prefixIcon: Icon(Icons.fitness_center),
            ),
            items: performedExercises.map((id) {
              final name = provider.getExerciseName(id);
              return DropdownMenuItem(value: id, child: Text(name));
            }).toList(),
            onChanged: (value) => setState(() => _selectedExerciseId = value),
          ),
        ),
        
        // Exercise stats
        if (_selectedExerciseId != null)
          Expanded(
            child: _ExerciseProgressView(
              exerciseId: _selectedExerciseId!,
              provider: provider,
            ),
          ),
      ],
    );
  }
}

class _ExerciseProgressView extends StatelessWidget {
  final String exerciseId;
  final WorkoutProvider provider;

  const _ExerciseProgressView({
    required this.exerciseId,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final progression = provider.getVolumeProgression(exerciseId);
    final growthModel = provider.getGrowthModel(exerciseId);
    final exercise = provider.getExercise(exerciseId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Growth rate card
          if (growthModel != null)
            _buildGrowthCard(context, growthModel),
          
          const SizedBox(height: AppSpacing.md),
          
          // Volume chart
          _buildVolumeChart(context, progression),
          
          const SizedBox(height: AppSpacing.md),
          
          // Session history
          _buildSessionHistory(context, progression),
        ],
      ),
    );
  }

  Widget _buildGrowthCard(BuildContext context, GrowthModel model) {
    final isGrowing = model.slope > 0;
    final slopeFormatted = model.slope.abs().toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGrowing
              ? [AppTheme.success.withOpacity(0.2), AppTheme.success.withOpacity(0.1)]
              : [AppTheme.warning.withOpacity(0.2), AppTheme.warning.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            isGrowing ? Icons.trending_up : Icons.trending_down,
            color: isGrowing ? AppTheme.success : AppTheme.warning,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGrowing ? 'Growing!' : 'Plateau',
                  style: TextStyle(
                    color: isGrowing ? AppTheme.success : AppTheme.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  isGrowing
                      ? '+$slopeFormatted kg volume per session'
                      : 'Volume trend is flat or declining',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R² = ${(model.r2 * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                'Model Fit',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(
    BuildContext context,
    List<({DateTime date, double volume})> data,
  ) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Center(
          child: Text('No data', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.volume / 100);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Volume Progression',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.surfaceColor,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${(value * 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.secondaryColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.secondaryColor.withOpacity(0.3),
                          AppTheme.secondaryColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHistory(
    BuildContext context,
    List<({DateTime date, double volume})> data,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session History',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.take(10).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(entry.date),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  Text(
                    '${entry.volume.toStringAsFixed(0)} kg',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==================== Targets Tab ====================

class _TargetsTab extends StatelessWidget {
  const _TargetsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final targets = provider.targets;
    final activeTargets = targets.where((t) => !t.isCompleted).toList();
    final completedTargets = targets.where((t) => t.isCompleted).toList();

    return Scaffold(
      body: targets.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (activeTargets.isNotEmpty) ...[
                  Text(
                    'Active Targets',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...activeTargets.map((t) => _TargetCard(target: t, provider: provider)),
                ],
                if (completedTargets.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Completed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...completedTargets.map((t) => _TargetCard(target: t, provider: provider)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTargetDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Target'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No Targets Set',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Set a target to track your progress',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showCreateTargetDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _CreateTargetSheet(),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final Target target;
  final WorkoutProvider provider;

  const _TargetCard({
    required this.target,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseName = provider.getExerciseName(target.exerciseId);
    final progress = target.progressPercentage;
    final isCompleted = target.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.flag,
                  color: isCompleted ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exerciseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => provider.deleteTarget(target.id),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${target.targetType}: ${target.currentValue.toStringAsFixed(0)} / ${target.targetValue.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: AppTheme.surfaceColor,
              valueColor: AlwaysStoppedAnimation(
                isCompleted ? AppTheme.success : AppTheme.primaryColor,
              ),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isCompleted ? AppTheme.success : AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (target.estimatedCompletionDate != null && !isCompleted)
                  Text(
                    'Est: ${DateFormat('MMM d').format(target.estimatedCompletionDate!)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTargetSheet extends StatefulWidget {
  const _CreateTargetSheet();

  @override
  State<_CreateTargetSheet> createState() => _CreateTargetSheetState();
}

class _CreateTargetSheetState extends State<_CreateTargetSheet> {
  String? _selectedExerciseId;
  String _targetType = 'reps';
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ExerciseDatabase.getAll();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Target',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          DropdownButtonFormField<String>(
            value: _selectedExerciseId,
            decoration: const InputDecoration(
              labelText: 'Exercise',
            ),
            items: exercises.map((e) => DropdownMenuItem(
              value: e.id,
              child: Text(e.name),
            )).toList(),
            onChanged: (val) => setState(() => _selectedExerciseId = val),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          DropdownButtonFormField<String>(
            value: _targetType,
            decoration: const InputDecoration(
              labelText: 'Target Type',
            ),
            items: const [
              DropdownMenuItem(value: 'reps', child: Text('Max Reps')),
              DropdownMenuItem(value: 'weight', child: Text('Max Weight (kg)')),
              DropdownMenuItem(value: 'volume', child: Text('Total Volume (kg)')),
            ],
            onChanged: (val) => setState(() => _targetType = val!),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          TextField(
            controller: _valueController,
            decoration: const InputDecoration(
              labelText: 'Target Value',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createTarget,
              child: const Text('Create Target'),
            ),
          ),
        ],
      ),
    );
  }

  void _createTarget() async {
    if (_selectedExerciseId == null || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final value = double.tryParse(_valueController.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid target value')),
      );
      return;
    }

    await context.read<WorkoutProvider>().createTarget(
      exerciseId: _selectedExerciseId!,
      type: _targetType,
      targetValue: value,
    );

    if (mounted) Navigator.pop(context);
  }
}
