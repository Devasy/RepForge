import 'dart:convert';
import 'package:http/http.dart' as http;

/// Allowlist grammar for stable general-purpose chat models. Unknown suffixes
/// are rejected, even if the API says the model supports generateContent.
class GeminiChatModelName {
  const GeminiChatModelName(this.id, this.major, this.minor, this.isLite);
  final String id;
  final int major;
  final int minor;
  final bool isLite;

  static final _pattern = RegExp(
    r'^(?:models/)?(gemini-([0-9]+)\.([0-9]+)-flash(-lite)?)$',
  );

  static GeminiChatModelName? parse(String name) {
    final match = _pattern.firstMatch(name);
    if (match == null || match.end != name.length) return null;
    return GeminiChatModelName(
      match.group(1)!,
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      match.group(4) != null,
    );
  }
}

/// Discovery populates the picker; it never silently changes a user's model.
class GeminiModelCatalog {
  GeminiModelCatalog({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void close() => _client.close();
  Future<List<(String, String)>> discover(String apiKey) async {
    if (apiKey.trim().isEmpty) throw Exception('Save a Gemini API key first.');
    final models = <String, String>{};
    String? token;
    do {
      final response = await _client
          .get(
            Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {
              'pageSize': '1000',
              'pageToken': ?token,
            }),
            headers: {'x-goog-api-key': apiKey.trim()},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception(
          'Could not fetch Gemini models. Check your key and connection.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = data['models'] ?? [];
      if (rows is! List) {
        throw const FormatException('Invalid Gemini model list.');
      }
      for (final model in rows) {
        if (model is! Map) continue;
        final name = model['name'];
        final parsed = name is String ? GeminiChatModelName.parse(name) : null;
        // Stable general-purpose Flash variants only. Excludes Live, TTS,
        // image, preview and experimental models requiring different APIs.
        final methods = model['supportedGenerationMethods'];
        if (parsed == null ||
            methods is! List ||
            !methods.contains('generateContent')) {
          continue;
        }
        final displayName = model['displayName'];
        models[parsed.id] = displayName is String ? displayName : parsed.id;
      }
      token = data['nextPageToken'] as String?;
    } while (token != null && token.isNotEmpty);
    final result = [
      for (final entry in models.entries) (entry.key, entry.value),
    ];
    result.sort((a, b) {
      final av = GeminiChatModelName.parse(a.$1)!;
      final bv = GeminiChatModelName.parse(b.$1)!;
      final major = bv.major.compareTo(av.major);
      if (major != 0) return major;
      final minor = bv.minor.compareTo(av.minor);
      if (minor != 0) return minor;
      // Prefer full Flash over Lite when both have the same version.
      return (av.isLite ? 1 : 0).compareTo(bv.isLite ? 1 : 0);
    });
    return result;
  }
}
