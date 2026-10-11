import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/exercise_media.dart';
import '../../services/exercise_media_store.dart';

class ExerciseMediaGallery extends StatelessWidget {
  const ExerciseMediaGallery({super.key, required this.media});
  final List<ExerciseMedia> media;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < media.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        ExerciseMediaPreview(media: media[i]),
      ],
    ],
  );
}

class ExerciseMediaPreview extends StatefulWidget {
  const ExerciseMediaPreview({super.key, required this.media});
  final ExerciseMedia media;
  @override
  State<ExerciseMediaPreview> createState() => _ExerciseMediaPreviewState();
}

class _ExerciseMediaPreviewState extends State<ExerciseMediaPreview> {
  late Future<File?> _file;
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ExerciseMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.fileName != widget.media.fileName) _load();
  }

  void _load() {
    _file = ExerciseMediaStore.instance
        .fileFor(widget.media)
        .then((f) async => await f.exists() ? f : null);
  }

  Future<void> _play(File file) async {
    if (!Platform.isAndroid) {
      _message('Video playback is supported on Android.');
      return;
    }
    setState(() => _playing = true);
    try {
      await const MethodChannel(
        'repforge/exercise_media',
      ).invokeMethod<void>('playVideo', {'path': file.path});
    } catch (_) {
      if (mounted) _message('Could not play this video. Try another MP4 file.');
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Widget _image(File file) => Image.file(
    file,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const Center(
      child: Text('Could not display this image. Replace it in Edit Exercise.'),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: _file,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final file = snapshot.data;
      if (file == null) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Media file unavailable. Replace or remove it in Edit Exercise.',
          ),
        );
      }
      if (widget.media.kind == ExerciseMediaKind.video) {
        return SizedBox(
          height: 130,
          child: Center(
            child: FilledButton.icon(
              onPressed: _playing ? null : () => _play(file),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(
                _playing
                    ? 'Playing…'
                    : 'Play demonstration (${((widget.media.durationMs ?? 0) / 1000).ceil()}s)',
              ),
            ),
          ),
        );
      }
      return Semantics(
        label: 'Exercise demonstration. Tap to enlarge.',
        button: true,
        child: GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: InteractiveViewer(child: _image(file)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: _image(file),
          ),
        ),
      );
    },
  );
}
