import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches an `import`/`export` path that reaches into one of RepForge's
/// app-specific top-level directories, regardless of how many `../` hops
/// precede it (e.g. `'../theme/...'`, `'../../../theme/...'`) or whether it
/// is written as a `package:repforge/...` path.
final RegExp _forbiddenPathPattern = RegExp(
  r"""['"](?:(?:\.\./)+|package:repforge/)(theme|models|services|screens|data)/""",
);

/// Matches an `import` or `export` directive line, so we only flag genuine
/// dependency declarations and not, say, doc comments that happen to mention
/// a forbidden directory name.
final RegExp _directiveLine = RegExp(r'^(import|export)\s');

/// Matches an explicit cast to a common type, used to flag unchecked casts on
/// model-supplied data in component renderers.
final RegExp _castPattern =
    RegExp(r'\bas (String|num|int|double|List|Map|bool|Object|dynamic)\b');

void main() {
  test('lib/genui imports nothing app-specific', () {
    // The whole point of the refactor: this package must be liftable into
    // another app without dragging RepForge's models, theme or services along.
    final violations = <String>[];
    var scannedFileCount = 0;
    final dir = Directory('lib/genui');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scannedFileCount++;
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (!_directiveLine.hasMatch(trimmed)) continue;
        if (_forbiddenPathPattern.hasMatch(trimmed)) {
          violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    // Guards against a vacuous pass: if `lib/genui` were ever empty or
    // unreachable (wrong CWD, a path typo), the loop above would scan zero
    // files and `violations` would be trivially empty. The package has 20+
    // Dart files at time of writing; a sane floor below that still catches a
    // broken scan without being brittle to file-count churn.
    expect(scannedFileCount, greaterThan(15),
        reason: 'expected to scan a substantial number of lib/genui files, '
            'but only found $scannedFileCount — is the CWD wrong?');

    expect(violations, isEmpty,
        reason: 'genui must stay domain-free:\n${violations.join('\n')}');
  });

  test('forbidden-path regex catches the violation shapes it must', () {
    // Regression test for the guard itself: a depth-blind, literal
    // needle-list version of this check silently passed a real
    // `'../../../theme/app_theme.dart'` import from
    // lib/genui/src/components/ (three `../` hops) because only one- and
    // two-hop needles were listed. Pin down that every realistic depth and
    // form of a forbidden import is actually matched, using in-memory
    // strings rather than mutating real source files.
    const mustMatch = [
      "import '../theme/app_theme.dart';",
      "import '../../theme/app_theme.dart';",
      "import '../../../theme/app_theme.dart';",
      "import '../../../../models/models.dart';",
      "import 'package:repforge/theme/app_theme.dart';",
      "import 'package:repforge/models/models.dart';",
      "export 'package:repforge/services/workout_provider.dart';",
      "import '../screens/home_screen.dart';",
      "import '../../data/exercise_database.dart';",
      "import 'package:repforge/data/exercise_database.dart';",
    ];
    for (final line in mustMatch) {
      expect(_forbiddenPathPattern.hasMatch(line), isTrue,
          reason: 'expected forbidden-path regex to match: $line');
    }

    const mustNotMatch = [
      "import 'package:flutter/material.dart';",
      "import 'a2ui_registry.dart';",
      "import '../src/a2ui_parser.dart';",
      "import 'package:repforge/genui/a2ui.dart';",
    ];
    for (final line in mustNotMatch) {
      expect(_forbiddenPathPattern.hasMatch(line), isFalse,
          reason: 'expected forbidden-path regex NOT to match: $line');
    }
  });

  test('component renderers contain no casts on model-supplied data', () {
    final violations = <String>[];
    var scannedFileCount = 0;
    final dir = Directory('lib/genui/src/components');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scannedFileCount++;
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (_castPattern.hasMatch(lines[i])) {
          violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    // Same vacuous-pass guard as above: there are 8 component files at time
    // of writing, so a floor comfortably below that still catches a broken
    // scan (wrong CWD, empty/unreachable directory) without being brittle.
    expect(scannedFileCount, greaterThan(5),
        reason: 'expected to scan several component files, but only found '
            '$scannedFileCount — is the CWD wrong?');

    expect(violations, isEmpty,
        reason: 'use A2UiProps accessors, not casts:\n${violations.join('\n')}');
  });
}
