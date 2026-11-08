import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../debug_log_buffer.dart';
import 'langfuse_config.dart';

class LangfuseService extends ChangeNotifier {
  LangfuseService({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    http.Client Function()? clientFactory,
  }) : _read = read ?? (() => const FlutterSecureStorage().read(key: _key)),
       _write =
           write ??
           ((value) =>
               const FlutterSecureStorage().write(key: _key, value: value)),
       _clientFactory = clientFactory ?? http.Client.new;
  static const _key = 'repforge.langfuse.developer.v1';
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final http.Client Function() _clientFactory;
  LangfuseConfig config = const LangfuseConfig();
  String status = 'Tracing is off';
  Future<void> _tail = Future.value();
  int _pending = 0, _revision = 0;
  bool _disposed = false;
  Future<void> load() async {
    try {
      final raw = await _read();
      if (raw != null) {
        config = LangfuseConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (config.enabled) config.validate();
        _protect(config);
      }
      status = config.enabled ? 'Ready to trace' : 'Tracing is off';
    } catch (_) {
      config = const LangfuseConfig();
      status = 'Could not load tracing settings';
    }
    _notify();
  }

  Future<void> save(LangfuseConfig next) async {
    if (next.enabled) next.validate();
    _protect(next);
    await _write(jsonEncode(next.toJson()));
    config = next;
    _revision++;
    status = next.enabled ? 'Ready to trace' : 'Tracing is off';
    _notify();
  }

  void _protect(LangfuseConfig value) {
    DebugLogBuffer.instance.protect(value.publicKey);
    DebugLogBuffer.instance.protect(value.secretKey);
    DebugLogBuffer.instance.protect(
      base64Encode(utf8.encode('${value.publicKey}:${value.secretKey}')),
    );
  }

  String sanitize(Object? value) {
    var text = DebugLogBuffer.instance.redact(jsonEncode(value));
    text = text.replaceAll(RegExp(r'(?:sk|pk)-lf-[\w-]+'), '[redacted]');
    return text.length > 24000
        ? jsonEncode({'truncated': true, 'preview': text.substring(0, 24000)})
        : text;
  }

  void record({
    required String traceId,
    required String sessionId,
    required String name,
    required String type,
    required DateTime started,
    String? spanId,
    String? parentSpanId,
    Object? input,
    Object? output,
    Map<String, Object?> metadata = const {},
    String? model,
    bool failed = false,
  }) {
    if (!kDebugMode || !config.enabled || _pending >= 32) return;
    final snapshot = config;
    final revision = _revision;
    final attributes = <String, Object?>{
      'langfuse.observation.type': type,
      'session.id': sessionId,
      'langfuse.trace.name': 'RepForge ${metadata['kind'] ?? 'agent'}',
      'langfuse.environment': 'development',
      'langfuse.observation.metadata': sanitize(metadata),
      if (type == 'generation')
        'langfuse.observation.usage_details': sanitize(
          _usage(metadata['usage']),
        ),
      'langfuse.observation.model.name': ?model,
      if (snapshot.captureContent)
        'langfuse.observation.input': sanitize(input),
      if (snapshot.captureContent)
        'langfuse.observation.output': sanitize(output),
      if (failed) 'langfuse.observation.level': 'ERROR',
    };
    final span = _span(
      traceId: traceId,
      name: name,
      started: started,
      attributes: attributes,
      failed: failed,
      spanId: spanId,
      parentSpanId: parentSpanId,
    );
    _pending++;
    _tail = _tail.then((_) async {
      try {
        if (revision != _revision || !config.enabled) return;
        await _send(snapshot, span);
        if (revision == _revision) status = 'Trace sent';
      } catch (_) {
        if (revision == _revision) {
          status = 'Trace export failed; chat is unaffected';
        }
      } finally {
        _pending--;
        _notify();
      }
    });
  }

  Map<String, num> _usage(Object? source) {
    if (source is! Map) return {};
    final prompt = source['promptTokenCount'];
    final cached = source['cachedContentTokenCount'];
    return {
      // Export disjoint input categories so cached tokens are priced once.
      if (prompt is num)
        'input': cached is num ? (prompt - cached).clamp(0, prompt) : prompt,
      if (cached is num) 'input_cached_tokens': cached,
      if (source['thoughtsTokenCount'] is num)
        'output_reasoning_tokens': source['thoughtsTokenCount'] as num,
      for (final entry in {
        'output': 'candidatesTokenCount',
        'total': 'totalTokenCount',
      }.entries)
        if (source[entry.value] is num) entry.key: source[entry.value] as num,
    };
  }

  Map<String, Object?> _span({
    required String traceId,
    required String name,
    required DateTime started,
    required Map<String, Object?> attributes,
    required bool failed,
    String? spanId,
    String? parentSpanId,
  }) => {
    'traceId': traceId,
    'spanId': spanId ?? const Uuid().v4().replaceAll('-', '').substring(0, 16),
    'parentSpanId': ?parentSpanId,
    'name': name,
    'kind': 1,
    'startTimeUnixNano': '${started.microsecondsSinceEpoch * 1000}',
    'endTimeUnixNano': '${DateTime.now().microsecondsSinceEpoch * 1000}',
    'status': {'code': failed ? 2 : 1},
    'attributes': [
      for (final entry in attributes.entries)
        {
          'key': entry.key,
          'value': {'stringValue': entry.value.toString()},
        },
    ],
  };
  Future<void> _send(LangfuseConfig settings, Map<String, Object?> span) async {
    final client = _clientFactory();
    try {
      final request = http.Request('POST', settings.endpoint)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${settings.publicKey}:${settings.secretKey}'))}',
          'Content-Type': 'application/json',
          'x-langfuse-ingestion-version': '4',
        })
        ..body = jsonEncode({
          'resourceSpans': [
            {
              'resource': {
                'attributes': [
                  {
                    'key': 'service.name',
                    'value': {'stringValue': 'repforge'},
                  },
                ],
              },
              'scopeSpans': [
                {
                  'scope': {'name': 'repforge.ai', 'version': '1'},
                  'spans': [span],
                },
              ],
            },
          ],
        });
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 8));
      final body = await response.stream.bytesToString().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Trace rejected');
      }
      if (body.trim().isNotEmpty) {
        final result = jsonDecode(body);
        if (result is Map && result['partialSuccess'] is Map) {
          final partial = result['partialSuccess'] as Map;
          if (int.tryParse('${partial['rejectedSpans'] ?? 0}') != 0) {
            throw StateError('Trace partially rejected');
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Future<void> testConnection(LangfuseConfig candidate) async {
    candidate.validate();
    _protect(candidate);
    await _send(
      candidate,
      _span(
        traceId: const Uuid().v4().replaceAll('-', ''),
        name: 'RepForge connection test',
        started: DateTime.now(),
        attributes: {'langfuse.observation.type': 'span'},
        failed: false,
      ),
    );
  }

  Future<void> flush() => _tail;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
