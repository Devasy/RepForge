import 'package:flutter/foundation.dart';

/// Captures every [debugPrint] call into a fixed-size circular buffer.
/// Wire up once in main() via [DebugLogBuffer.attach].
class DebugLogBuffer extends ChangeNotifier {
  DebugLogBuffer._();
  static final instance = DebugLogBuffer._();

  static const _maxLines = 500;
  final List<String> _lines = [];

  List<String> get lines => List.unmodifiable(_lines);

  static void attach() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      original(message, wrapWidth: wrapWidth);
      instance._append(message ?? '');
    };
  }

  void _append(String line) {
    final ts = DateTime.now();
    final stamp =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    _lines.add('[$stamp] $line');
    if (_lines.length > _maxLines) _lines.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
