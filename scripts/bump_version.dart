import 'dart:io';

/// Script to automatically bump version in pubspec.yaml
/// Increments patch version and build number
/// Usage: dart scripts/bump_version.dart
void main() async {
  final pubspecFile = File('workout-logger/pubspec.yaml');

  if (!await pubspecFile.exists()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  final content = await pubspecFile.readAsString();
  final lines = content.split('\n');

  String? newVersion;
  final updatedLines = <String>[];

  for (var line in lines) {
    if (line.startsWith('version:')) {
      // Extract current version (format: version: 1.0.2+3)
      final versionMatch = RegExp(
        r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)',
      ).firstMatch(line);

      if (versionMatch == null) {
        print('Error: Could not parse version from: $line');
        exit(1);
      }

      final major = int.parse(versionMatch.group(1)!);
      final minor = int.parse(versionMatch.group(2)!);
      final patch = int.parse(versionMatch.group(3)!);
      final build = int.parse(versionMatch.group(4)!);

      // Increment patch and build
      final newPatch = patch + 1;
      final newBuild = build + 1;

      newVersion = '$major.$minor.$newPatch+$newBuild';
      updatedLines.add('version: $newVersion');

      print(
        'Bumping version: ${versionMatch.group(1)}.${versionMatch.group(2)}.${versionMatch.group(3)}+${versionMatch.group(4)} → $newVersion',
      );
    } else {
      updatedLines.add(line);
    }
  }

  if (newVersion == null) {
    print('Error: Version line not found in pubspec.yaml');
    exit(1);
  }

  // Write updated content back to file
  await pubspecFile.writeAsString(updatedLines.join('\n'));

  // Output new version for GitHub Actions to use
  print('NEW_VERSION=$newVersion');

  // Also write to GitHub Actions output if running in CI
  final githubOutput = Platform.environment['GITHUB_OUTPUT'];
  if (githubOutput != null) {
    final outputFile = File(githubOutput);
    await outputFile.writeAsString(
      'version=$newVersion\n',
      mode: FileMode.append,
    );
  }

  exit(0);
}
