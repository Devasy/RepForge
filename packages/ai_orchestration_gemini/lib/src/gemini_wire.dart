import 'package:ai_orchestration/ai_orchestration.dart';

List<JsonMap> geminiContents(List<ModelMessage> messages) {
  final contents = <JsonMap>[];
  final calls = <String, (String, String?)>{};
  for (final message in messages) {
    final parts = <Object?>[];
    if (message.role == 'tool') {
      final call = calls.remove(message.callId);
      if (call == null) {
        throw const OrchestrationException(
          'model_protocol',
          'Unpaired tool result.',
        );
      }
      parts.add({
        'functionResponse': {
          'name': call.$1,
          if (call.$2 != null) 'id': call.$2,
          'response': message.result,
        },
      });
    } else if (message.role == 'assistant') {
      final saved = message.providerData['gemini'];
      final metadata = saved == null ? null : jsonObject(saved);
      final nativeIds = metadata?['callIds'] == null
          ? null
          : jsonObject(metadata!['callIds']);
      for (final call in message.calls) {
        calls[call.id] = (
          call.name,
          nativeIds == null ? call.id : nativeIds[call.id] as String?,
        );
      }
      if (metadata?['parts'] case final List<Object?> rawParts) {
        parts.addAll(rawParts);
      } else {
        if (message.text.isNotEmpty) parts.add({'text': message.text});
        parts.addAll(
          message.calls.map(
            (call) => {
              'functionCall': {
                'id': call.id,
                'name': call.name,
                'args': call.arguments,
              },
            },
          ),
        );
      }
    } else {
      for (final attachment in message.attachments) {
        final mime = attachment['mimeType'];
        final data = attachment['data'];
        if (mime is! String || data is! String) {
          throw const OrchestrationException(
            'model_capability',
            'Gemini attachments require mimeType and base64 data.',
          );
        }
        parts.add({
          'inlineData': {'mimeType': mime, 'data': data},
        });
      }
      parts.add({
        'text': message.text.isEmpty && parts.isNotEmpty
            ? '[Attached image]'
            : message.text,
      });
    }
    final role = message.role == 'assistant' ? 'model' : 'user';
    if (contents.isNotEmpty && contents.last['role'] == role) {
      contents.last['parts'] = [
        ...contents.last['parts']! as List<Object?>,
        ...parts,
      ];
    } else {
      contents.add({'role': role, 'parts': parts});
    }
  }
  if (calls.isNotEmpty) {
    throw const OrchestrationException(
      'model_protocol',
      'Tool results are incomplete.',
    );
  }
  return contents;
}

JsonMap geminiSchema(JsonMap schema) => {
  for (final entry in schema.entries)
    if (entry.key != 'additionalProperties')
      entry.key: switch (entry.key) {
        'type' => (entry.value! as String).toUpperCase(),
        'properties' => jsonObject(
          entry.value,
        ).map((key, value) => MapEntry(key, geminiSchema(jsonObject(value)))),
        'items' => geminiSchema(jsonObject(entry.value)),
        _ => entry.value,
      },
};
