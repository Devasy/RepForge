import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/release_service.dart';

void main() {
  test('malformed release rows do not hide valid published updates', () async {
    final service = ReleaseService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            null,
            42,
            'bad row',
            {'tag_name': null, 'html_url': null},
            {'tag_name': 'v9.0.0', 'html_url': 42},
            {
              'tag_name': 'v8.0.0',
              'html_url': 'https://github.com/Devasy/RepForge/releases',
              'prerelease': true,
            },
            {
              'tag_name': 'v7.0.0',
              'html_url': 'https://github.com/Devasy/RepForge/releases',
              'draft': true,
            },
            {
              'tag_name': 'v2.1.6',
              'html_url':
                  'https://github.com/Devasy/RepForge/releases/tag/v2.1.6',
              'body': 42,
            },
          ]),
          200,
        ),
      ),
    );
    final release = await service.updateFor('2.1.5');
    expect(release!.version, '2.1.6');
    expect(release.notes, '');
  });
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
          (request) async => request.url.host == 'raw.githubusercontent.com'
              ? http.Response(
                  [
                    for (final version in ['2.1.9', '2.1.7', '2.1.6', '2.1.5'])
                      '## [$version]\n### Fixes\n- Notes $version',
                  ].join('\n'),
                  200,
                )
              : http.Response(
                  jsonEncode([
                    {
                      'tag_name': 'v2.1.9',
                      'body': 'Release notes',
                      'html_url':
                          'https://github.com/Devasy/RepForge/releases/tag/v2.1.9',
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
  test('changelog caching, refresh and concurrent request sharing', () async {
    var calls = 0;
    final service = ReleaseService(
      client: MockClient((request) async {
        calls++;
        expect(
          request.url.toString(),
          'https://raw.githubusercontent.com/Devasy/RepForge/main/CHANGELOG.md',
        );
        return http.Response('## [2.1.6]\n### Fixes\n- Fixed.', 200);
      }),
    );
    await Future.wait([service.changelog(), service.changelog()]);
    await service.changelog();
    expect(calls, 1);
    await service.changelog(refresh: true);
    expect(calls, 2);
  });
  test(
    'malformed changelog remains retryable and never caches partial entries',
    () async {
      var calls = 0;
      final service = ReleaseService(
        client: MockClient(
          (_) async => http.Response(
            ++calls == 1
                ? '## [2.1.6]\nBad entry'
                : '## [2.1.6]\n### Fixes\n- Fixed.',
            200,
          ),
        ),
      );
      await expectLater(
        service.changesSince('2.1.5', '2.1.6'),
        throwsFormatException,
      );
      expect(await service.changesSince('2.1.5', '2.1.6'), hasLength(1));
    },
  );
  test('authored future entry alone cannot trigger an update notice', () async {
    final service = ReleaseService(
      client: MockClient(
        (request) async => http.Response(
          request.url.host == 'raw.githubusercontent.com'
              ? '## [9.0.0]\n### Features added\n- Draft future release.'
              : '[]',
          200,
        ),
      ),
    );
    expect(await service.changelog(), hasLength(1));
    expect(await service.updateFor('2.1.5'), isNull);
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
