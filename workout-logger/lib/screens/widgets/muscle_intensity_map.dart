import 'package:flutter/material.dart';

import '../../data/exercise_database.dart';
import '../../services/extended_exercise_library.dart';
import '../../theme/app_theme.dart';
import 'body_heatmap.dart';

enum _IntensityKind { resistance, stretch }

class MuscleIntensityMap extends StatefulWidget {
  const MuscleIntensityMap({super.key, required this.profile});
  final MuscleIntensityProfile profile;

  @override
  State<MuscleIntensityMap> createState() => _MuscleIntensityMapState();
}

class _MuscleIntensityMapState extends State<MuscleIntensityMap> {
  _IntensityKind? _selection;

  @override
  void didUpdateWidget(MuscleIntensityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.code != widget.profile.code) _selection = null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    if (profile.resistance.isEmpty && profile.stretch.isEmpty) {
      return const Text('No source muscle scores available for this exercise.');
    }
    final kind =
        _selection ??
        (profile.resistance.isEmpty
            ? _IntensityKind.stretch
            : _IntensityKind.resistance);
    final scores = kind == _IntensityKind.resistance
        ? profile.resistance
        : profile.stretch;
    final color = kind == _IntensityKind.resistance
        ? AppColors.warning
        : AppColors.cyan;
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SourceReference(
          profile: profile,
          attribution: kind == _IntensityKind.resistance
              ? profile.resistanceAttribution
              : profile.stretchAttribution,
        ),
        const SizedBox(height: AppSpacing.md),
        _IntensitySelector(
          profile: profile,
          selected: kind,
          onChanged: (value) => setState(() => _selection = value),
        ),
        const SizedBox(height: AppSpacing.md),
        MuscleBodyMap(
          muscleVolumes: {for (final e in scores.entries) e.key: e.value / 10},
          heatColor: color,
          showControls: false,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final entry in entries)
          _ScoreRow(
            name: MuscleGroups.names[entry.key] ?? entry.key,
            score: entry.value,
            color: color,
          ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Source intensity · 1–10. These are reference scores, not measured activation percentages. Stretch is separate from resistance.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'The body diagram groups some regions; the list retains each muscle score.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _SourceReference extends StatelessWidget {
  const _SourceReference({required this.profile, required this.attribution});
  final MuscleIntensityProfile profile;
  final String attribution;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(attribution, style: const TextStyle(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Reference: ${profile.name}',
        style: const TextStyle(color: AppColors.textSoft),
      ),
    ],
  );
}

class _IntensitySelector extends StatelessWidget {
  const _IntensitySelector({
    required this.profile,
    required this.selected,
    required this.onChanged,
  });
  final MuscleIntensityProfile profile;
  final _IntensityKind selected;
  final ValueChanged<_IntensityKind> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<_IntensityKind>(
    segments: [
      ButtonSegment(
        value: _IntensityKind.resistance,
        label: const Text('Resistance'),
        enabled: profile.resistance.isNotEmpty,
      ),
      ButtonSegment(
        value: _IntensityKind.stretch,
        label: const Text('Stretch'),
        enabled: profile.stretch.isNotEmpty,
      ),
    ],
    selected: {selected},
    onSelectionChanged: (value) => onChanged(value.single),
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.name,
    required this.score,
    required this.color,
  });
  final String name;
  final num score;
  String get scoreLabel => score == score.roundToDouble()
      ? score.toInt().toString()
      : score.toStringAsFixed(1);
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name, intensity $scoreLabel out of 10',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: const TextStyle(color: AppColors.textSoft),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: LinearProgressIndicator(
              value: score / 10,
              color: color,
              backgroundColor: AppColors.glass2,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$scoreLabel/10',
            style: TextStyle(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}
