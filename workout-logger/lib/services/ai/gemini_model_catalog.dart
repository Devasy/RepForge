import 'dart:convert';
import 'package:http/http.dart' as http;

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
      for (final model
          in (data['models'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final id = (model['name'] as String).replaceFirst('models/', '');
        // Stable general-purpose Flash variants only. Excludes Live, TTS,
        // image, preview and experimental models requiring different APIs.
        if (!RegExp(r'^gemini-\d+\.\d+-flash(?:-lite)?$').hasMatch(id) ||
            !(model['supportedGenerationMethods'] as List? ?? []).contains(
              'generateContent',
            )) {
          continue;
        }
        models[id] = model['displayName'] as String? ?? id;
      }
      token = data['nextPageToken'] as String?;
    } while (token != null && token.isNotEmpty);
    final result = [
      for (final entry in models.entries) (entry.key, entry.value),
    ];
    result.sort((a, b) {
      List<int> version(String id) => RegExp(
        r'\d+',
      ).allMatches(id).map((m) => int.parse(m.group(0)!)).take(2).toList();
      final av = version(a.$1), bv = version(b.$1);
      final major = bv[0].compareTo(av[0]);
      return major != 0 ? major : bv[1].compareTo(av[1]);
    });
    return result;
  }
}
