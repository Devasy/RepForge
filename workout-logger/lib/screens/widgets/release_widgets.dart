import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/release_service.dart';
import '../../theme/app_theme.dart';
import 'rf_accordion.dart';

class ReleaseNotes extends StatefulWidget {
  const ReleaseNotes({
    super.key,
    required this.current,
    this.previous,
    this.service,
  });
  final String current;
  final String? previous;
  final ReleaseService? service;
  @override
  State<ReleaseNotes> createState() => _ReleaseNotesState();
}

class _ReleaseNotesState extends State<ReleaseNotes> {
  late Future<List<AppRelease>> _notes;
  @override
  void initState() {
    super.initState();
    _notes = (widget.service ?? ReleaseService.shared).changesSince(
      widget.previous,
      widget.current,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AppRelease>>(
    future: _notes,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text(
              'Release notes are temporarily unavailable. Try again later.',
            ),
            TextButton(
              onPressed: () => setState(() {
                _notes = (widget.service ?? ReleaseService.shared).changesSince(
                  widget.previous,
                  widget.current,
                );
              }),
              child: const Text('Retry'),
            ),
          ],
        );
      }
      final notes = snapshot.data ?? [];
      if (notes.isEmpty) {
        return const Text(
          'No changelog entries are available for this upgrade yet.',
        );
      }
      return ReleaseNotesView(releases: notes);
    },
  );
}

/// One renderer for upgrade notes, release history and available-update notes.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({super.key, required this.releases});
  final List<AppRelease> releases;

  static String _countLabel(int count) =>
      '$count ${count == 1 ? 'change' : 'changes'}';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < releases.length; index++)
        RFAccordion(
          key: ValueKey('release-${releases[index].version}'),
          title: 'v${releases[index].version}',
          subtitle: releases[index].changes.isEmpty
              ? null
              : _countLabel(releases[index].changeCount),
          initiallyExpanded: index == 0,
          children: [
            for (final group in releases[index].changes)
              RFAccordion(
                key: ValueKey(
                  'release-${releases[index].version}-${group.title}',
                ),
                title: group.title,
                subtitle: _countLabel(group.items.length),
                children: [
                  for (var item = 0; item < group.items.length; item++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          '• ${group.items[item]}',
                          key: ValueKey(
                            'change-${releases[index].version}-${group.title}-$item',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (releases[index].changes.isEmpty)
              SelectableText(
                releases[index].notes.isEmpty
                    ? 'No release notes were published for this version.'
                    : releases[index].notes,
              ),
          ],
        ),
    ],
  );
}

class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key, required this.current, this.service});
  final String current;
  final ReleaseService? service;
  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  late Future<AppRelease?> _update;
  @override
  void initState() {
    super.initState();
    _check();
  }

  void _check({bool refresh = false}) {
    _update = (widget.service ?? ReleaseService.shared).updateFor(
      widget.current,
      refresh: refresh,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppRelease?>(
    future: _update,
    builder: (context, snapshot) {
      final release = snapshot.data;
      return ListTile(
        leading: Icon(
          release == null ? Icons.system_update : Icons.new_releases,
          color: release == null ? null : Colors.amber,
        ),
        title: Text(
          release == null
              ? 'Check for updates'
              : 'Update available: v${release.version}',
        ),
        subtitle: Text(
          snapshot.hasError
              ? 'Could not check. Tap to retry.'
              : release == null
              ? 'Checks published stable GitHub releases'
              : 'Install through your usual distribution channel',
        ),
        trailing: release == null ? null : const Badge(label: Text('New')),
        onTap: () async {
          if (release == null) {
            setState(() => _check(refresh: true));
            return;
          }
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('RepForge v${release.version}'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReleaseNotes(
                      current: release.version,
                      previous: widget.current,
                      service: widget.service,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Use the same store or signing source as your existing installation.',
                    ),
                    SelectableText(release.url),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: release.url));
                  },
                  child: const Text('Copy release link'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
