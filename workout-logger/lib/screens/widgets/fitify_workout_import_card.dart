import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/fitify_workout_import.dart';
import '../../services/interfaces/health_connect_service_interface.dart';
import '../../services/interfaces/workout_import_health_service.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import 'extended_library_download.dart';
import 'rf_widgets.dart';

class FitifyWorkoutImportCard extends StatefulWidget {
  const FitifyWorkoutImportCard({super.key, this.reader});
  final IWorkoutImportHealthService? reader;
  @override
  State<FitifyWorkoutImportCard> createState() =>
      _FitifyWorkoutImportCardState();
}

class _FitifyWorkoutImportCardState extends State<FitifyWorkoutImportCard> {
  late DateTimeRange _range;
  bool _busy = false;
  String? _error;
  List<FitifyImportEntry>? _entries;
  FitifyImportReport? _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 27)),
      end: today,
    );
  }

  Future<void> _chooseDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Fitify workout dates',
    );
    if (range != null && mounted) {
      setState(() {
        _range = range;
        _entries = null;
        _report = null;
        _error = null;
      });
    }
  }

  Future<void> _preview() async {
    final provider = context.read<WorkoutProvider>();
    final candidate = widget.reader ?? context.read<IHealthConnectService>();
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
      _entries = null;
    });
    try {
      if (candidate is! IWorkoutImportHealthService) {
        throw StateError('Workout import is unavailable on this platform.');
      }
      final needsHistory = _range.start.isBefore(
        DateTime.now().subtract(const Duration(days: 29)),
      );
      final access = await candidate.requestWorkoutImportAccess(
        includeHistory: needsHistory,
      );
      if (!access.exerciseGranted) {
        throw StateError(
          'Allow RepForge to read Exercise in Health Connect, then try again.',
        );
      }
      if (needsHistory && !access.historyGranted) {
        throw StateError(
          'Older history access is unavailable or was not granted. Choose dates within the last four weeks, or allow history access in Health Connect.',
        );
      }
      final records = await candidate.readFitifyWorkouts(
        _range.start,
        _range.end.add(const Duration(days: 1)),
      );
      final entries = provider.previewFitifyWorkouts(records);
      if (mounted) setState(() => _entries = entries);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Could not read workouts. Check Health Connect access and retry; no workouts were imported.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final provider = context.read<WorkoutProvider>();
    final records = _entries!
        .where((entry) => entry.canImport)
        .map((entry) => entry.record)
        .toList();
    setState(() => _busy = true);
    try {
      final report = await provider.importFitifyWorkouts(records);
      for (final entry in _entries!.where((entry) => !entry.canImport)) {
        if (entry.action == FitifyImportAction.current) {
          report.current++;
        } else {
          report.issues.add(
            '${entry.record.title ?? 'Fitify workout'}: ${entry.message}',
          );
        }
      }
      if (mounted) {
        setState(() {
          _report = report;
          _entries = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The import stopped. Read workouts again to check saved sessions and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<WorkoutProvider>();
    final entries = _entries;
    final ready = entries?.where((e) => e.canImport).length ?? 0;
    final current =
        entries?.where((e) => e.action == FitifyImportAction.current).length ??
        0;
    final issues =
        entries
            ?.where(
              (e) => !e.canImport && e.action != FitifyImportAction.current,
            )
            .toList() ??
        [];
    final format = DateFormat('d MMM yyyy');
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import Fitify workouts',
            style: TextStyle(
              fontFamily: 'Geist',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bring exercises, reps and hold durations from FitifySync in Health Connect into your history and muscle recovery.',
            style: TextStyle(color: AppColors.textSoft),
          ),
          const SizedBox(height: 8),
          const Text(
            'Run sync in the updated FitifySync app first. Timings are reconstructed; missing weights stay unknown.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (!context.read<WorkoutProvider>().hasExtendedLibrary)
            const ExtendedLibraryDownload(),
          TextButton.icon(
            onPressed: _busy ? null : _chooseDates,
            icon: const Icon(Icons.date_range),
            label: Text(
              '${format.format(_range.start)} – ${format.format(_range.end)}',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _preview,
            icon: const Icon(Icons.preview_outlined),
            label: Text(_busy ? 'Working…' : 'Read workouts'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (entries != null) ...[
            const SizedBox(height: 8),
            Text(
              entries.isEmpty
                  ? 'No FitifySync workouts found for these dates.'
                  : '$ready ready to import · $current already current · ${issues.length} need attention',
            ),
            if (ready > 0)
              FilledButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.download_done),
                label: Text('Import $ready workouts'),
              ),
            if (entries.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Review workouts'),
                children: [
                  for (final entry in entries.take(100))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.record.title ?? 'Fitify workout'),
                      subtitle: Text(
                        '${format.format(entry.record.start.toLocal())} · ${switch (entry.action) {
                          FitifyImportAction.add => 'New workout',
                          FitifyImportAction.update => 'Source update',
                          FitifyImportAction.current => 'Already current',
                          _ => entry.message ?? 'Needs attention',
                        }}',
                      ),
                      leading: Icon(
                        entry.canImport
                            ? Icons.check_circle_outline
                            : entry.action == FitifyImportAction.current
                            ? Icons.done_all
                            : Icons.info_outline,
                      ),
                    ),
                  if (entries.length > 100)
                    const Text(
                      'Showing the first 100 workouts. Choose a shorter range to review the rest.',
                    ),
                ],
              ),
          ],
          if (_report case final report?) ...[
            const SizedBox(height: 8),
            Text(report.summary),
            if (report.issues.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Workouts needing attention'),
                children: [
                  for (final issue in report.issues)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(issue),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
