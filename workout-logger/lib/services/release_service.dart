import 'dart:convert';
import 'package:http/http.dart' as http;

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
  const AppRelease(this.version, this.notes, this.url);
  final String version;
  final String notes;
  final String url;
}

/// Shared cache keeps profile visits from repeatedly polling GitHub.
class ReleaseService {
  ReleaseService({http.Client? client}) : _client = client ?? http.Client();
  static final shared = ReleaseService();
  final http.Client _client;
  List<AppRelease>? _cache;
  DateTime? _checkedAt;
  Future<List<AppRelease>>? _pending;

  Future<List<AppRelease>> releases({bool refresh = false}) {
    if (!refresh &&
        _cache != null &&
        DateTime.now().difference(_checkedAt!) < const Duration(hours: 6)) {
      return Future.value(_cache!);
    }
    return _pending ??= _fetch().whenComplete(() => _pending = null);
  }

  Future<List<AppRelease>> _fetch() async {
    final releases = <AppRelease>[];
    // Paginate rather than silently dropping intermediate upgrades.
    for (var page = 1; ; page++) {
      final response = await _client
          .get(
            Uri.https('api.github.com', '/repos/Devasy/RepForge/releases', {
              'per_page': '100',
              'page': '$page',
            }),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Release information is unavailable. Try again later.');
      }
      final rows = jsonDecode(response.body) as List;
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final tag = row['tag_name'] as String;
        if (row['draft'] == true ||
            row['prerelease'] == true ||
            compareAppVersions(tag, '0.0.0') == null) {
          continue;
        }
        releases.add(
          AppRelease(
            tag.replaceFirst(RegExp(r'^v'), ''),
            row['body'] as String? ?? '',
            row['html_url'] as String,
          ),
        );
      }
      if (rows.length < 100) break;
    }
    releases.sort((a, b) => compareAppVersions(b.version, a.version)!);
    _cache = releases;
    _checkedAt = DateTime.now();
    return releases;
  }

  Future<List<AppRelease>> changesSince(
    String? previous,
    String current,
  ) async {
    final all = await releases();
    return all
        .where(
          (release) =>
              (compareAppVersions(release.version, current) ?? 1) <= 0 &&
              (previous == null ||
                  (compareAppVersions(release.version, previous) ?? -1) > 0),
        )
        .toList();
  }

  Future<AppRelease?> updateFor(String current, {bool refresh = false}) async {
    final all = await releases(refresh: refresh);
    return all
        .where(
          (release) => (compareAppVersions(release.version, current) ?? -1) > 0,
        )
        .firstOrNull;
  }
}
