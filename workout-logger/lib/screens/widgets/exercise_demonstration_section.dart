import 'package:flutter/material.dart';

import '../../data/exercise_demonstrations.dart';
import '../../models/models.dart';
import '../../services/exercise_media_store.dart';
import '../../services/workout_provider.dart';
import 'exercise_media_gallery.dart';
import '../add_custom_exercise_screen.dart';

class ExerciseDemonstrationSection extends StatefulWidget {
  const ExerciseDemonstrationSection({
    super.key,
    required this.exercise,
    required this.provider,
  });
  final Exercise exercise;
  final WorkoutProvider provider;
  @override
  State<ExerciseDemonstrationSection> createState() =>
      _ExerciseDemonstrationSectionState();
}

class _ExerciseDemonstrationSectionState
    extends State<ExerciseDemonstrationSection> {
  bool _downloading = false;
  Future<void> _download(ExerciseDemonstration guide) async {
    setState(() => _downloading = true);
    var staged = <ExerciseMedia>[];
    try {
      final media = await ExerciseMediaStore.instance.downloadGuide(
        guide.images.map(Uri.parse).toList(),
        isReferenced: (name) => widget.provider.allExercises.any(
          (e) => e.media.any((m) => m.fileName == name),
        ),
      );
      staged = media;
      if (!mounted) return;
      final current =
          widget.provider.getExercise(widget.exercise.id) ?? widget.exercise;
      final combined = <String, ExerciseMedia>{
        for (final m in current.media) m.fileName: m,
        for (final m in media) m.fileName: m,
      }.values.toList();
      if (combined.length > ExerciseMediaStore.maxItems) {
        throw const FormatException(
          'Remove an attachment before downloading this guide.',
        );
      }
      await widget.provider.updateExercise(id: current.id, media: combined);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the guide. Check your connection and available media slots, then try again.',
            ),
          ),
        );
      }
    } finally {
      await ExerciseMediaStore.instance.discardUnreferenced(
        staged,
        (name) => widget.provider.allExercises.any(
          (e) => e.media.any((m) => m.fileName == name),
        ),
      );
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final exercise =
          widget.provider.getExercise(widget.exercise.id) ?? widget.exercise;
      final guide = exercise.isCustom
          ? null
          : exerciseDemonstrations[exercise.id];
      if (guide == null && exercise.media.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No demonstration added yet.'),
            TextButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add demonstration media'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AddCustomExerciseScreen(initialExercise: exercise),
                ),
              ),
            ),
          ],
        );
      }
      final downloaded =
          exercise.media.where((m) => m.source == 'free-exercise-db').length >=
          2;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demonstration',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (exercise.media.isNotEmpty)
            ExerciseMediaGallery(media: exercise.media),
          if (guide != null) ...[
            Text(
              'Reference variant: ${guide.title}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!downloaded) ...[
              const Text(
                'Download two reference photos for offline viewing. Images are fetched from GitHub only when you tap Download.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _downloading ? null : () => _download(guide),
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(
                  _downloading ? 'Downloading…' : 'Download photo guide',
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (var i = 0; i < guide.instructions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${i + 1}. ${guide.instructions[i]}'),
              ),
            const Text(
              'Photo guide: Free Exercise DB · Unlicense',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
        ],
      );
    },
  );
}
