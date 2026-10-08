import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/release_service.dart';

void main() {
  test('compares numeric versions and rejects preview tags', () {
    expect(compareAppVersions('v2.1.10', '2.1.9'), greaterThan(0));
    expect(compareAppVersions('2.1.5+63', '2.1.5'), 0);
    expect(compareAppVersions('v2.2.0-beta', '2.1.5'), isNull);
  });
  test(
    'skipped upgrades include all intervening stable releases, bounded by installed version',
    () async {
      final service = ReleaseService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode([
              for (final version in ['2.1.9', '2.1.7', '2.1.6', '2.1.5'])
                {
                  'tag_name': 'v$version',
                  'body': 'Notes $version',
                  'html_url':
                      'https://github.com/Devasy/RepForge/releases/tag/v$version',
                },
              {'tag_name': 'v3.0.0', 'prerelease': true},
            ]),
            200,
          ),
        ),
      );
      expect(
        (await service.changesSince('2.1.5', '2.1.7')).map((r) => r.version),
        ['2.1.7', '2.1.6'],
      );
      expect((await service.updateFor('2.1.7'))!.version, '2.1.9');
    },
  );
  test('paginates and caches requests', () async {
    var calls = 0;
    final service = ReleaseService(
      client: MockClient((request) async {
        calls++;
        final page = request.url.queryParameters['page'];
        return http.Response(
          jsonEncode(
            page == '1'
                ? [
                    for (var i = 0; i < 100; i++)
                      {
                        'tag_name': 'v2.1.${i + 1}',
                        'html_url':
                            'https://github.com/Devasy/RepForge/releases',
                        'body': '',
                      },
                  ]
                : [
                    {
                      'tag_name': 'v2.0.0',
                      'html_url': 'https://github.com/Devasy/RepForge/releases',
                      'body': 'Old notes',
                    },
                  ],
          ),
          200,
        );
      }),
    );
    expect((await service.releases()).length, 101);
    await service.releases();
    expect(calls, 2);
  });
  test('offline or rate-limited errors remain retryable', () async {
    var calls = 0;
    final service = ReleaseService(
      client: MockClient(
        (_) async => http.Response('[]', ++calls == 1 ? 403 : 200),
      ),
    );
    await expectLater(service.releases(), throwsException);
    expect(await service.releases(), isEmpty);
  });
}
