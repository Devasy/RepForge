// Agent Mirror Writer
//
// Keeps an on-disk JSON mirror of workout data in sync so the native Android
// AppFunction handlers can answer the OS agent's queries without a running
// Flutter engine. The mirror is rewritten (debounced) whenever workout data
// changes and once at startup.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'agent_data_service.dart';
import 'workout_provider.dart';

/// Serializes [AgentDataService.buildSnapshot] to a file the native layer reads.
class AgentMirrorWriter {
  /// File name within the application support directory.
  static const String fileName = 'agent_mirror.json';

  /// Coalesce bursts of data changes into a single write.
  static const Duration debounce = Duration(seconds: 2);

  final AgentDataService _dataService;
  final WorkoutProvider _provider;
  final Future<Directory> Function() _directoryResolver;

  Timer? _debounceTimer;
  bool _started = false;

  AgentMirrorWriter(
    this._dataService,
    this._provider, {
    Future<Directory> Function()? directoryResolver,
  }) : _directoryResolver =
            directoryResolver ?? getApplicationSupportDirectory;

  /// Begin mirroring: write an initial snapshot, then rewrite on every change.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _provider.addListener(_onDataChanged);
    await writeNow();
  }

  /// Stop mirroring and release the change listener.
  void dispose() {
    if (!_started) return;
    _provider.removeListener(_onDataChanged);
    _debounceTimer?.cancel();
    _started = false;
  }

  void _onDataChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, writeNow);
  }

  /// Absolute location of the mirror file.
  Future<File> mirrorFile() async {
    final dir = await _directoryResolver();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Serialize the current snapshot and write it to disk immediately.
  Future<void> writeNow() async {
    try {
      final snapshot = _dataService.buildSnapshot();
      final file = await mirrorFile();
      await file.writeAsString(jsonEncode(snapshot), flush: true);
    } catch (e) {
      debugPrint('AgentMirrorWriter: failed to write mirror — $e');
    }
  }
}
