import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/genui imports nothing app-specific', () {
    // The whole point of the refactor: this package must be liftable into
    // another app without dragging RepForge's models, theme or services along.
    const forbidden = [
      "'../theme/",
      "'../models/",
      "'../services/",
      "'../screens/",
      "'../../theme/",
      "'../../models/",
      "'../../services/",
      "'../../screens/",
      'package:repforge/theme',
      'package:repforge/models',
      'package:repforge/services',
      'package:repforge/screens',
    ];

    final violations = <String>[];
    final dir = Directory('lib/genui');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final line in source.split('\n')) {
        if (!line.trimLeft().startsWith('import ')) continue;
        for (final needle in forbidden) {
          if (line.contains(needle)) {
            violations.add('${entity.path}: ${line.trim()}');
          }
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'genui must stay domain-free:\n${violations.join('\n')}');
  });

  test('component renderers contain no casts on model-supplied data', () {
    final violations = <String>[];
    final dir = Directory('lib/genui/src/components');
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r"\bas (String|num|int|double|List|Map)\b")
            .hasMatch(lines[i])) {
          violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'use A2UiProps accessors, not casts:\n${violations.join('\n')}');
  });
}
