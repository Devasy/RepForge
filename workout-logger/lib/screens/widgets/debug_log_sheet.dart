import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/debug_log_buffer.dart';
import '../../theme/app_theme.dart';

class DebugLogSheet extends StatefulWidget {
  final String appVersion;
  const DebugLogSheet({super.key, this.appVersion = ''});
  @override
  State<DebugLogSheet> createState() => _DebugLogSheetState();
}

class _DebugLogSheetState extends State<DebugLogSheet> {
  bool _paused = false;
  bool _aiOnly = false;
  String? _copyStatus;
  Timer? _copyTimer;
  List<String> _snapshot = const [];
  List<String> get _visible =>
      (_paused ? _snapshot : DebugLogBuffer.instance.lines)
          .map(DebugLogBuffer.instance.redact)
          .where((line) => !_aiOnly || line.contains('[AI]'))
          .toList();

  Future<void> _copy() async {
    final lines = _visible;
    final report =
        'RepForge ${widget.appVersion} (${kDebugMode ? 'debug' : 'release'})\n'
        'Captured: ${DateTime.now().toIso8601String()}\n${lines.join('\n')}';
    var message = 'Logs copied';
    try {
      await Clipboard.setData(ClipboardData(text: report));
    } catch (_) {
      message = 'Could not copy logs. Please try again.';
    }
    if (!mounted) return;
    _copyTimer?.cancel();
    setState(() => _copyStatus = message);
    _copyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copyStatus = null);
    });
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .8,
    minChildSize: .4,
    maxChildSize: .95,
    expand: false,
    builder: (context, controller) => SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Debug Logs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close logs',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: DebugLogBuffer.instance,
              builder: (context, _) {
                final lines = _visible;
                return Column(
                  children: [
                    _LogToolbar(
                      aiOnly: _aiOnly,
                      paused: _paused,
                      count: lines.length,
                      copyStatus: _copyStatus,
                      onFilter: () => setState(() => _aiOnly = !_aiOnly),
                      onPause: () => setState(() {
                        _snapshot = DebugLogBuffer.instance.lines;
                        _paused = !_paused;
                      }),
                      onCopy: lines.isEmpty ? null : _copy,
                      onClear: () {
                        DebugLogBuffer.instance.clear();
                        setState(() => _snapshot = const []);
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _LogLines(controller: controller, lines: lines),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _LogToolbar extends StatelessWidget {
  final bool aiOnly;
  final bool paused;
  final int count;
  final String? copyStatus;
  final VoidCallback onFilter;
  final VoidCallback onPause;
  final VoidCallback? onCopy;
  final VoidCallback onClear;
  const _LogToolbar({
    required this.aiOnly,
    required this.paused,
    required this.count,
    this.copyStatus,
    required this.onFilter,
    required this.onPause,
    required this.onCopy,
    required this.onClear,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text(
                'AI only',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  color: AppColors.textSoft,
                ),
              ),
              selected: aiOnly,
              onSelected: (_) => onFilter(),
            ),
            TextButton(
              onPressed: onPause,
              child: Text(paused ? 'Resume' : 'Pause'),
            ),
            TextButton(
              onPressed: onCopy,
              child: Text(aiOnly ? 'Copy AI logs' : 'Copy All'),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            copyStatus ??
                '$count lines · ${paused ? 'Paused — new logs are still recorded' : 'Live · newest first'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ),
  );
}

class _LogLines extends StatelessWidget {
  final ScrollController controller;
  final List<String> lines;
  const _LogLines({required this.controller, required this.lines});
  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: controller,
    reverse: false,
    padding: const EdgeInsets.all(AppSpacing.md),
    itemCount: lines.isEmpty ? 1 : lines.length,
    itemBuilder: (context, index) {
      if (lines.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('No logs yet. Reproduce the issue, then return here.'),
        );
      }
      final line = lines[lines.length - 1 - index];
      final error = RegExp(
        'error|failed|exception|timeout',
        caseSensitive: false,
      ).hasMatch(line);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: SelectableText(
          line,
          style: TextStyle(
            fontFamily: 'GeistMono',
            fontSize: 12,
            color: error
                ? AppColors.error
                : line.contains('[AI]')
                ? AppColors.secondary
                : AppColors.textSoft,
          ),
        ),
      );
    },
  );
}
