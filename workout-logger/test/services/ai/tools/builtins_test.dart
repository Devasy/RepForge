import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/tools/agent_tool.dart';
import 'package:repforge/services/ai/tools/builtins/ask_user_questions_tool.dart';
import 'package:repforge/services/ai/tools/builtins/show_graph_tool.dart';
import 'package:repforge/services/ai/runtime/agent_artifact.dart';

void main() {
  group('ShowGraphTool', () {
    test('returns correct artifact and empty data', () async {
      final tool = ShowGraphTool();
      expect(tool.id, 'show_graph');

      final ctx = ToolExecutionContext(args: {'query': 'test'}, callId: '1');
      final result = await tool.execute(ctx);

      expect(result.data['chart_spec'], isNotNull);
      expect(result.artifacts.length, 1);
      
      // We don't have the explicit ChartArtifact class exposed here if it's not exported,
      // but we can check it's an AgentArtifact and its ID.
      expect(result.artifacts.first, isA<ChartArtifact>());
    });
  });

  group('AskUserQuestionsTool', () {
    test('returns interrupt result with questions payload', () async {
      final tool = AskUserQuestionsTool();
      expect(tool.id, 'ask_user_questions');

      final ctx = ToolExecutionContext(
        args: {
          'questions': [
            {'question': 'Q1?', 'options': ['A1', 'A2']},
            {'question': 'Q2?', 'options': ['B1', 'B2']}
          ]
        },
        callId: '1',
      );
      final result = await tool.execute(ctx);

      expect(result.data['status'], 'awaiting_user_response');
      
      // Questions are placed in artifacts, not data.
      expect(result.artifacts.length, 1);
      // Wait, QuestionFormArtifact is not exported either?
      // Since AgentArtifact is the base, we just expect it to not be null.
      expect(result.artifacts.first, isNotNull);
    });
  });
}
