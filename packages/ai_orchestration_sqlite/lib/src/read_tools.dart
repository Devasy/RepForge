import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// App-approved schema descriptions; this never introspects all user tables.
class SchemaCatalogTool implements AgentTool {
  final JsonMap catalog;
  SchemaCatalogTool(JsonMap catalog) : catalog = jsonObject(catalog);
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'describe_schema',
    description:
        'Describe the application-approved relations, fields, units and query tools.',
    arguments: ValueSchema.object(),
    replaySafe: true,
  );
  @override
  ToolOutcome execute(ToolContext context) => ToolSuccess(catalog);
}

/// Fixed application SQL with bound model values; no free-form SQL is accepted.
class NamedSqlReadTool implements AgentTool {
  final Database _database;
  @override
  final ToolDefinition definition;
  final String _sql;
  final List<String> _parameterNames;
  final int maxRows;
  final int maxResultBytes;
  NamedSqlReadTool._(
    this._database, {
    required this.definition,
    required String sql,
    required List<String> parameterNames,
    required this.maxRows,
    required this.maxResultBytes,
  }) : _sql = sql,
       _parameterNames = List.unmodifiable(parameterNames);

  /// Returns the tool and its owned dedicated read-only connection.
  static Future<NamedSqlReadTool> open({
    required DatabaseFactory factory,
    required String databasePath,
    required ToolDefinition definition,
    required String sql,
    List<String> parameterNames = const [],
    int maxRows = 200,
    int maxResultBytes = 65536,
  }) async {
    if (definition.effect != ToolEffect.read ||
        maxRows < 1 ||
        maxRows > 500 ||
        maxResultBytes < 1) {
      throw ArgumentError(
        'Read tools require read effect and bounded result limits.',
      );
    }
    var query = sql.trim();
    if (query.endsWith(';')) {
      query = query.substring(0, query.length - 1).trimRight();
    }
    if (query.contains(';') ||
        !RegExp(r'^(SELECT|WITH)\b', caseSensitive: false).hasMatch(query)) {
      throw ArgumentError('Provide one trusted SELECT query.');
    }
    final properties = jsonObject(
      definition.arguments.definition['properties'] ?? {},
    );
    if (parameterNames.toSet().length != parameterNames.length ||
        parameterNames.any((name) => !properties.containsKey(name))) {
      throw ArgumentError(
        'SQL parameters must have distinct declared argument names.',
      );
    }
    final database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    return NamedSqlReadTool._(
      database,
      definition: definition,
      sql: query,
      parameterNames: parameterNames,
      maxRows: maxRows,
      maxResultBytes: maxResultBytes,
    );
  }

  Future<void> close() => _database.close();

  @override
  Future<ToolOutcome> execute(ToolContext context) async {
    context.cancellation.check();
    definition.arguments.validate(context.call.arguments);
    final parameters = _parameterNames.map((name) {
      final value = context.call.arguments[name];
      if (value is Map || value is List || value is bool) {
        throw const OrchestrationException(
          'sql_parameter',
          'SQL parameters must be scalar strings, numbers or null.',
        );
      }
      return value;
    }).toList();
    final result = await _database.rawQuery(
      'SELECT * FROM (\n$_sql\n) LIMIT ?',
      [...parameters, maxRows + 1],
    );
    context.cancellation.check();
    final rows = <JsonMap>[];
    var bytes = 2;
    var truncated = result.length > maxRows;
    for (final row in result.take(maxRows)) {
      final safe = row.map(
        (key, value) => MapEntry(
          key,
          value is List<int>
              ? <String, Object?>{
                  'encoding': 'base64',
                  'data': base64Encode(value),
                }
              : value,
        ),
      );
      final size =
          utf8.encode(jsonEncode(safe)).length + (rows.isEmpty ? 0 : 1);
      if (bytes + size > maxResultBytes) {
        truncated = true;
        break;
      }
      rows.add(jsonObject(safe));
      bytes += size;
    }
    return ToolSuccess({
      'query': definition.name,
      'rows': rows,
      'row_count': rows.length,
      'truncated': truncated,
      'supports_statement_cancellation': false,
    });
  }
}
