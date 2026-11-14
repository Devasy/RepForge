import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/extended_exercise_library.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';

class ExtendedLibraryDownload extends StatefulWidget {
  const ExtendedLibraryDownload({
    super.key,
    this.download = ExtendedExerciseLibrary.download,
  });
  final Future<String> Function() download;

  @override
  State<ExtendedLibraryDownload> createState() =>
      _ExtendedLibraryDownloadState();
}

class _ExtendedLibraryDownloadState extends State<ExtendedLibraryDownload> {
  bool _loading = false;
  String? _error;

  Future<void> _download() async {
    final provider = context.read<WorkoutProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await widget.download();
      await provider.loadExtendedLibrary(json);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load the library. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = context.watch<WorkoutProvider>().hasExtendedLibrary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _loading || loaded ? null : _download,
            icon: Icon(
              loaded ? Icons.offline_pin_outlined : Icons.download_rounded,
            ),
            label: Text(
              _loading
                  ? 'Downloading library…'
                  : loaded
                  ? 'Extended library available offline'
                  : 'Download extended library',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}
