import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/ai/gemini_model_catalog.dart';

void main() {
  test(
    'discovers stable Flash models across pages and excludes specialized models',
    () async {
      final catalog = GeminiModelCatalog(
        client: MockClient((request) async {
          expect(request.headers['x-goog-api-key'], 'test-key');
          final second = request.url.queryParameters.containsKey('pageToken');
          return http.Response(
            jsonEncode({
              'models': [
                for (final name
                    in second
                        ? ['gemini-3.7-flash']
                        : [
                            'gemini-3.8-flash',
                            'gemini-3.8-flash-tts',
                            'gemini-3.8-flash-preview',
                            'gemini-3.5-flash-lite',
                            'gemini-embedding-001',
                          ])
                  {
                    'name': 'models/$name',
                    'supportedGenerationMethods': ['generateContent'],
                  },
              ],
              if (!second) 'nextPageToken': 'next',
            }),
            200,
          );
        }),
      );
      expect((await catalog.discover('test-key')).map((entry) => entry.$1), [
        'gemini-3.8-flash',
        'gemini-3.7-flash',
        'gemini-3.5-flash-lite',
      ]);
    },
  );
  test('rejects missing key without a network request', () async {
    final catalog = GeminiModelCatalog(
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    await expectLater(catalog.discover(''), throwsException);
  });
}
