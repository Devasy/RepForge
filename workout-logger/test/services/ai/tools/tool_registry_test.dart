import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/tools/agent_tool.dart';
import 'package:repforge/services/ai/tools/tool_executor.dart';
import 'package:repforge/services/ai/tools/tool_metadata.dart';
import 'package:repforge/services/ai/tools/tool_registry.dart';
import 'package:repforge/services/ai/tools/tool_result.dart';
import 'package:repforge/services/ai/tools/tool_spec.dart';
import 'package:repforge/services/ai/agent_event.dart';

class _FakeTool implements AgentTool {
  @override
  final String id;
  
  final String descriptionText;
  final bool shouldFail;

  _FakeTool(this.id, this.descriptionText, {this.shouldFail = false});

  @override
  ToolSpec get spec => ToolSpec(
        name: id,
        description: descriptionText,
        parameters: const {},
      );

  @override
  ToolMetadata get metadata => ToolMetadata(
        displayName: id,
        kind: ToolKind.query,
        readOnly: true,
        progressLabel: '$id...',
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    if (shouldFail) {
      return ToolResult(data: {'error': 'Test error'});
    }
    return ToolResult(data: {'result': 'Success for $id'});
  }
}

void main() {
  group('ToolRegistry', () {
    test('registers and retrieves tools', () {
      final tool1 = _FakeTool('tool_one', 'Desc 1');
      final tool2 = _FakeTool('tool_two', 'Desc 2');

      final registry = ToolRegistry([tool1, tool2]);

      expect(registry.find('tool_one'), equals(tool1));
      expect(registry.find('tool_two'), equals(tool2));
      expect(registry.find('tool_three'), isNull);

      final specs = registry.specs;
      expect(specs.length, 2);
      expect(specs[0].name, 'tool_one');
      expect(specs[1].name, 'tool_two');
    });

    test('empty registry has no tools', () {
      const registry = ToolRegistry.empty();
      expect(registry.find('any'), isNull);
      expect(registry.specs, isEmpty);
    });
  });

  group('ToolExecutor', () {
    test('executes tool successfully and emits events', () async {
      final tool = _FakeTool('fake_tool', 'Desc');
      final registry = ToolRegistry([tool]);
      final executor = ToolExecutor(registry);

      final events = <AgentEvent>[];
      final result = await executor.execute(
        'fake_tool',
        {'param': 'value'},
        callId: 'call123',
        emit: events.add,
      );

      // Verify result
      expect(result.data['result'], 'Success for fake_tool');
      expect(result.data.containsKey('error'), isFalse);

      // Verify events
      expect(events.length, 3);
      expect(events[0], isA<AgentToolActivity>());
      expect(events[1], isA<AgentStatusUpdate>());
      final status = events[1] as AgentStatusUpdate;
      expect(status.status, 'Fetching fake_tool...…'); // from tool metadata formatted desc + ellipsis
      expect(events[2], isA<AgentToolActivity>()); // end event
    });

    test('returns error for unknown tool', () async {
      const registry = ToolRegistry.empty();
      final executor = ToolExecutor(registry);

      final events = <AgentEvent>[];
      final result = await executor.execute(
        'unknown_tool',
        {},
        callId: 'call123',
        emit: events.add,
      );

      expect(result.data.containsKey('error'), isTrue);
      expect(result.data['error'], contains('Unknown tool'));
      expect(events, isEmpty);
    });

    test('handles tool execution failure', () async {
      final tool = _FakeTool('failing_tool', 'Desc', shouldFail: true);
      final registry = ToolRegistry([tool]);
      final executor = ToolExecutor(registry);

      final events = <AgentEvent>[];
      final result = await executor.execute(
        'failing_tool',
        {},
        callId: 'call123',
        emit: events.add,
      );

      // The wrapper execute handles the result if ToolResult itself wasn't an exception,
      // but in _FakeTool we return an error payload explicitly.
      expect(result.data['error'], 'Test error');
    });
  });
}
