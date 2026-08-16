// ask_user_questions_tool.dart — Human-in-the-loop interrupt tool.
//
// When the model calls ask_user_questions, this tool produces an
// InterruptRun result that suspends the graph until the user responds.
// The tool itself doesn't block — the AwaitUserInputNode handles
// the actual interrupt.

import '../../../../models/models.dart';
import '../../runtime/agent_artifact.dart';
import '../agent_tool.dart';
import '../tool_metadata.dart';
import '../tool_result.dart';
import '../tool_spec.dart';

class AskUserQuestionsTool implements AgentTool {
  @override
  String get id => 'ask_user_questions';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Preparing questions',
        kind: ToolKind.interrupt,
        readOnly: true,
        outputKind: AgentArtifactKind.questionForm,
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'ask_user_questions',
        description:
            'Ask the user 1–3 clarifying questions before proceeding. '
            'Provide an optional preamble (short context sentence shown above the '
            'questions). Each question has 3–4 option chips; set multiSelect:true '
            'when the user should be able to pick multiple options. '
            'allowCustom is always treated as true.',
        parameters: {
          'preamble': ToolParam.string(
            description:
                'Optional. A short sentence shown above the questions, '
                'e.g. "Before I analyse your routine, I have a few quick '
                'questions."',
            nullable: true,
          ),
          'questions': ToolParam.array(
            items: ToolParam.object(
              properties: {
                'question': ToolParam.string(
                  description:
                      'The question text, e.g. "What is your primary goal?"',
                ),
                'options': ToolParam.array(
                  items: ToolParam.string(),
                  description:
                      '3–4 answer chips, e.g. ["Strength","Hypertrophy","Fat loss","Endurance"].',
                ),
                'multiSelect': ToolParam.boolean(
                  description:
                      'If true the user can select multiple chips. '
                      'Use for confirmation questions (e.g. "Which changes should I apply?").',
                  nullable: true,
                ),
              },
              requiredProperties: ['question', 'options'],
            ),
            description: '1–3 questions to display.',
          ),
        },
        required: ['questions'],
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    // Parse the questions payload from the model's arguments.
    final pending = PendingQuestions.fromJson(
      Map<String, dynamic>.from(ctx.args),
    );

    // Return the parsed questions as a QuestionFormArtifact.
    // The ExecuteToolsNode detects ToolKind.interrupt and transitions
    // to AwaitUserInputNode instead of back to model_step.
    return ToolResult(
      data: {'status': 'awaiting_user_response'},
      artifacts: [QuestionFormArtifact(pending)],
    );
  }
}
