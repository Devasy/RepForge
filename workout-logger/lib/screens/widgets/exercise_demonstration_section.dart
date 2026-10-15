import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/exercise_demonstrations.dart';
import '../../models/models.dart';
import '../../services/exercise_guide_cache.dart';
import '../../data/exercise_animations.dart';
import '../../theme/app_theme.dart';
import 'exercise_animation_player.dart';

class ExerciseDemonstrationSection extends StatefulWidget {
  const ExerciseDemonstrationSection({
    super.key,
    required this.exercise,
    this.cache,
  });
  final Exercise exercise;
  final ExerciseGuideCache? cache;

  @override
  State<ExerciseDemonstrationSection> createState() =>
      _ExerciseDemonstrationSectionState();
}

class _ExerciseDemonstrationSectionState
    extends State<ExerciseDemonstrationSection> {
  bool _downloading = false;
  late Future<bool> _downloaded;
  ExerciseGuideCache get _cache => widget.cache ?? ExerciseGuideCache.instance;

  @override
  void initState() {
    super.initState();
    _downloaded = _cache.isDownloaded(widget.exercise.id);
  }

  @override
  void didUpdateWidget(ExerciseDemonstrationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exercise.id != oldWidget.exercise.id ||
        widget.cache != oldWidget.cache) {
      _downloaded = _cache.isDownloaded(widget.exercise.id);
      _downloading = false;
    }
  }

  Future<void> _download() async {
    final exerciseId = widget.exercise.id;
    setState(() => _downloading = true);
    try {
      await _cache.download(exerciseId);
      if (mounted && widget.exercise.id == exerciseId) {
        _downloaded = _cache.isDownloaded(exerciseId);
      }
    } catch (_) {
      if (mounted && widget.exercise.id == exerciseId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not download the guide. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && widget.exercise.id == exerciseId) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.exercise.isCustom
        ? null
        : exerciseDemonstrations[widget.exercise.id];
    final animation = ExerciseAnimation.forExercise(widget.exercise);
    if (guide == null && animation == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'No movement illustration available for this exercise.',
          style: TextStyle(color: AppColors.textSoft),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (animation != null)
          ExerciseAnimationPlayer(exercise: widget.exercise),
        if (guide != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.glassBorderStrong),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo reference',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Reference variant: ${guide.title}',
                    style: const TextStyle(color: AppColors.textSoft),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FutureBuilder<bool>(
                    future: _downloaded,
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return Row(
                          children: [
                            for (
                              var index = 0;
                              index < guide.images.length;
                              index++
                            ) ...[
                              if (index > 0)
                                const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: FutureBuilder<File>(
                                      future: _cache.fileFor(
                                        widget.exercise.id,
                                        index,
                                      ),
                                      builder: (context, fileSnapshot) =>
                                          fileSnapshot.hasData
                                          ? Image.file(
                                              fileSnapshot.data!,
                                              fit: BoxFit.contain,
                                              semanticLabel:
                                                  '${guide.title}, reference photo ${index + 1}',
                                              errorBuilder: (_, _, _) =>
                                                  const Center(
                                                    child: Text(
                                                      'Photo could not be displayed.',
                                                    ),
                                                  ),
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }
                      return OutlinedButton.icon(
                        onPressed: _downloading ? null : _download,
                        icon: _downloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: Text(
                          _downloading
                              ? 'Downloading…'
                              : 'Download photo guide',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Photo guide: Free Exercise DB · Unlicense',
                    style: TextStyle(color: AppColors.textSoft, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('Technique instructions'),
                    children: [
                      for (var i = 0; i < guide.instructions.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            '${i + 1}. ${guide.instructions[i]}',
                            style: const TextStyle(color: AppColors.textSoft),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
