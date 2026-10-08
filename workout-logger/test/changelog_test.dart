import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/changelog.dart';

void main() {
  test('parses categories, ignores Unreleased and sorts numeric versions', () {
    final entries = parseChangelog('''# Changelog
Introductory prose.
## [Unreleased]
### Features added
- Not published yet.
## [2.1.9]
### Fixes
- Earlier fix.
## [2.1.10]
### Features added
- New feature.
### Known limitations
- Offline fetching needs a connection.
''');
    expect(entries.map((e) => e.version), ['2.1.10', '2.1.9']);
    expect(entries.first.notes, contains('Features added\n- New feature.'));
    expect(entries.first.notes, contains('Known limitations'));
    expect(entries.first.changes.map((group) => group.title), [
      'Features added',
      'Known limitations',
    ]);
    expect(entries.first.changes.first.items, ['New feature.']);
    expect(entries.first.changeCount, 2);
    expect(entries.any((e) => e.notes.contains('Not published')), isFalse);
  });
  for (final invalid in [
    '',
    '## [2.1.6]\n',
    '## [2.1.6-beta]\n### Fixes\n- Fix.',
    '## [2.1.6] - 2026-10-08\n### Fixes\n- Fix.',
    '## [2.1.6]\n### Fixed\n- Fix.',
    '## [2.1.6]\n### Fixes\n',
    '## [2.1.6]\n- Orphan bullet.',
    '## [2.1.6]\n### Fixes\n- Fix.\n  Continuation.',
    '## [2.1.6]\n### Fixes\n- Fix.\n### Fixes\n- Duplicate.',
    '## [2.1.6]\n### Fixes\n- Fix.\n## [2.1.6]\n### Changes\n- Duplicate.',
  ]) {
    test('rejects malformed changelog: $invalid', () {
      expect(() => parseChangelog(invalid), throwsFormatException);
    });
  }
  test('repository changelog follows the app parsing contract', () {
    final entries = parseChangelog(File('../CHANGELOG.md').readAsStringSync());
    expect(entries.any((entry) => entry.version == '2.1.6'), isTrue);
  });
}
