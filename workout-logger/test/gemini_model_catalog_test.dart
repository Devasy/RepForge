import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/ai/gemini_model_catalog.dart';

void main() {
  test(
    'regex parses stable chat IDs and captures numeric version and variant',
    () {
      final parsed = GeminiChatModelName.parse(
        'models/gemini-3.10-flash-lite',
      )!;
      expect(parsed.id, 'gemini-3.10-flash-lite');
      expect(parsed.major, 3);
      expect(parsed.minor, 10);
      expect(parsed.isLite, isTrue);
      expect(GeminiChatModelName.parse('gemini-4.0-flash')!.isLite, isFalse);
    },
  );
  test(
    'regex rejects specialized families, suffixes and malformed resources',
    () {
      for (final name in [
        'gemini-3.8-flash-transcribe',
        'gemini-3.8-flash-transcription',
        'gemini-3.8-flash-tts',
        'gemini-3.8-flash-native-audio',
        'gemini-3.8-flash-live',
        'gemini-3.8-flash-image',
        'gemini-3.8-flash-preview',
        'gemini-3.8-flash-exp',
        'gemini-3.8-pro',
        'gemini-embedding-001',
        'imagen-4.0',
        'veo-3.0',
        'gemma-3',
        'gemini-3.8-flash-001',
        'other/models/gemini-3.8-flash',
        'models/models/gemini-3.8-flash',
        'gemini-3.8-flash\n',
        'gemini-3x8-flash',
      ]) {
        expect(GeminiChatModelName.parse(name), isNull, reason: name);
      }
    },
  );
  test(
    'discovery requires generateContent and sorts versions numerically',
    () async {
      final catalog = GeminiModelCatalog(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'models': [
                for (final id in [
                  'gemini-3.9-flash',
                  'gemini-3.10-flash-lite',
                  'gemini-3.10-flash',
                  'gemini-4.0-flash',
                  'gemini-4.0-flash-transcribe',
                ])
                  {
                    'name': 'models/$id',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                {
                  'name': 'models/gemini-9.0-flash',
                  'supportedGenerationMethods': ['embedContent'],
                },
                {'name': null},
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(catalog.close);
      expect((await catalog.discover('key')).map((m) => m.$1), [
        'gemini-4.0-flash',
        'gemini-3.10-flash',
        'gemini-3.10-flash-lite',
        'gemini-3.9-flash',
      ]);
    },
  );
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
