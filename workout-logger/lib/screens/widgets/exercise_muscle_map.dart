import 'package:flutter/material.dart';

import '../../data/exercise_database.dart';
import '../../data/exercise_muscle_motion.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'body_heatmap.dart';

enum MusclePhase { stretched, contracted }

const stretchedMuscleColor = Color(0xFF60A5FA);
const contractedMuscleColor = Color(0xFFFB7185);

/// Educational phase illustration, not a live muscle-state measurement.
class ExerciseMuscleMap extends StatefulWidget {
  const ExerciseMuscleMap({super.key, required this.exercise});
  final Exercise exercise;
  @override
  State<ExerciseMuscleMap> createState() => _ExerciseMuscleMapState();
}

class _ExerciseMuscleMapState extends State<ExerciseMuscleMap> {
  MusclePhase _phase = MusclePhase.contracted;

  @override
  Widget build(BuildContext context) {
    final motion = ExerciseMuscleMotion.forExercise(widget.exercise);
    final stretched = _phase == MusclePhase.stretched;
    final color = motion == null
        ? AppColors.primary
        : stretched
        ? stretchedMuscleColor
        : contractedMuscleColor;
    final activations = <String, double>{};
    for (final activation in widget.exercise.muscleActivations) {
      if (motion != null &&
          !motion.muscles.contains(activation.muscleGroupId)) {
        continue;
      }
      final value = (activation.activationPercentage / 100).clamp(0.0, 1.0);
      if (value > (activations[activation.muscleGroupId] ?? 0)) {
        activations[activation.muscleGroupId] = value;
      }
    }
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (motion != null) ...[
            Center(
              child: SegmentedButton<MusclePhase>(
                segments: const [
                  ButtonSegment(
                    value: MusclePhase.stretched,
                    label: Text('Stretched'),
                  ),
                  ButtonSegment(
                    value: MusclePhase.contracted,
                    label: Text('Contracted'),
                  ),
                ],
                selected: {_phase},
                onSelectionChanged: (value) =>
                    setState(() => _phase = value.single),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                stretched
                    ? 'Stretched · lengthening under load'
                    : 'Contracted · shortening under load',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stretched ? motion.stretched : motion.contracted,
              style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
            ),
          ] else
            const Text(
              'Target muscle involvement',
              style: TextStyle(
                color: AppColors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          MuscleBodyMap(
            muscleVolumes: activations,
            heatColor: color,
            showControls: false,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final entry in activations.entries)
                Text(
                  '${MuscleGroups.names[entry.key] ?? entry.key} ${(entry.value * 100).round()}%',
                  style: TextStyle(color: color, fontSize: 12),
                ),
            ],
          ),
          if (activations.isEmpty)
            const Text(
              'No target muscle information available.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Less',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              for (final intensity in [.25, .5, .75, 1.0])
                Container(
                  width: 20,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: color.withValues(alpha: .25 + .75 * intensity),
                ),
              const Text(
                'More involvement',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            motion == null
                ? 'Phase illustration is unavailable for this exercise. Shades show catalogue target involvement.'
                : 'Illustrative phases for standard technique. Shades show catalogue target involvement, not measured stretch or force. Muscles can actively contract while lengthening.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
