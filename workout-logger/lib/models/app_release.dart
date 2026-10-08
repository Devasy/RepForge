/// Release tags use vMAJOR.MINOR.PATCH. Preview tags are deliberately excluded.
int? compareAppVersions(String a, String b) {
  List<int>? parse(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$',
    ).firstMatch(value);
    return match == null
        ? null
        : [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }

  final left = parse(a), right = parse(b);
  if (left == null || right == null) return null;
  for (var i = 0; i < 3; i++) {
    final result = left[i].compareTo(right[i]);
    if (result != 0) return result;
  }
  return 0;
}

class AppRelease {
  const AppRelease(
    this.version,
    this.notes,
    this.url, {
    this.changes = const [],
  });
  final String version;
  final String notes;
  final String url;
  final List<ReleaseChangeGroup> changes;
  int get changeCount =>
      changes.fold(0, (count, group) => count + group.items.length);
}

class ReleaseChangeGroup {
  const ReleaseChangeGroup(this.title, this.items);
  final String title;
  final List<String> items;
}
