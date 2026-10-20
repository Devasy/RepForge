import 'dart:async';
import 'package:flutter/foundation.dart';

class DebugLogBuffer extends ChangeNotifier {
  DebugLogBuffer._();
  static final instance = DebugLogBuffer._();
  static const _maxLines = 500;
  final List<String> _lines = [];
  final Set<String> _secrets = {};
  bool _notificationPending = false;
  static DebugPrintCallback? _interceptor;

  List<String> get lines => List.unmodifiable(_lines);
  void protect(String secret) {
    if (secret.trim().isNotEmpty) {
      _secrets.add(secret);
      for (var i = 0; i < _lines.length; i++) {
        _lines[i] = _redact(_lines[i]);
      }
    }
  }

  static void attach() {
    if (identical(debugPrint, _interceptor)) return;
    final original = debugPrint;
    _interceptor = (String? message, {int? wrapWidth}) {
      original(message, wrapWidth: wrapWidth);
      if (message != null) instance.write(message);
    };
    debugPrint = _interceptor!;
  }

  String _redact(String message) {
    for (final secret in _secrets) {
      message = message.replaceAll(secret, '[redacted]');
    }
    return message
        .replaceAll(RegExp(r'AIza[\w-]{20,}'), '[redacted]')
        .replaceAllMapped(
          RegExp(r'([?&]key=)[^\s&]+', caseSensitive: false),
          (match) => '${match[1]}[redacted]',
        );
  }

  void write(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    for (final line in _redact(message).split('\n')) {
      _lines.add(
        '[$stamp] ${line.length > 2048 ? '${line.substring(0, 2048)}…' : line}',
      );
    }
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
    _notify();
  }

  void _notify() {
    if (_notificationPending) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      notifyListeners();
    });
  }

  void clear() {
    _lines.clear();
    _notify();
  }
}
