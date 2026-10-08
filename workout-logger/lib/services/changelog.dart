import 'dart:convert';
import '../models/app_release.dart';

/// CHANGELOG.md is a protocol as well as a developer-readable document.
/// Only version headings, known category headings and single-line bullets are
/// permitted inside entries. Reject malformed files instead of showing partial
/// or incorrectly attributed notes. Unreleased entries never reach the app.
List<AppRelease> parseChangelog(String markdown) {
  final releases = <AppRelease>[];
  final versions = <String>{};
  const categories = {
    'Features added',
    'Fixes',
    'Changes',
    'Removed',
    'Known limitations',
  };
  final heading = RegExp(r'^## \[(Unreleased|[0-9]+\.[0-9]+\.[0-9]+)\]$');
  String? version;
  String? category;
  final sections = <String, List<String>>{};
  void finish() {
    if (version == null || version == 'Unreleased') return;
    if (sections.isEmpty || sections.values.any((items) => items.isEmpty)) {
      throw FormatException(
        'Changelog $version must contain nonempty categories.',
      );
    }
    releases.add(
      AppRelease(
        version,
        sections.entries
            .map((entry) => '${entry.key}\n${entry.value.join('\n')}')
            .join('\n\n'),
        'https://github.com/Devasy/RepForge/releases/tag/v$version',
      ),
    );
  }

  for (final line in const LineSplitter().convert(markdown)) {
    if (line.trim().isEmpty) continue;
    final match = heading.firstMatch(line);
    if (match != null && match.end == line.length) {
      finish();
      version = match.group(1)!;
      if (!versions.add(version)) {
        throw FormatException('Duplicate changelog version: $version');
      }
      category = null;
      sections.clear();
    } else if (line.startsWith('## ')) {
      throw FormatException('Invalid changelog version heading: $line');
    } else if (version == null) {
      // The document title and introductory prose precede the first entry.
      continue;
    } else if (line.startsWith('### ')) {
      category = line.substring(4);
      if (!categories.contains(category) || sections.containsKey(category)) {
        throw FormatException(
          'Invalid or duplicate changelog category: $category',
        );
      }
      sections[category] = [];
    } else if (line.startsWith('- ') &&
        line.substring(2).trim().isNotEmpty &&
        category != null) {
      sections[category]!.add(line);
    } else {
      throw FormatException('Expected a category or single-line bullet: $line');
    }
  }
  finish();
  if (versions.isEmpty) {
    throw const FormatException('No changelog entries found.');
  }
  releases.sort((a, b) => compareAppVersions(b.version, a.version)!);
  return releases;
}
