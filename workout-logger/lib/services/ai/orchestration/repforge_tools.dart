import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as sdk;

import '../coach_tool_service.dart';
import 'sdk_schema.dart';

ToolRegistry repforgeTools(
  CoachToolService service, {
  required bool optimizer,
}) {
  final declarations = [
    for (final tool in service.buildTools()) ...?tool.functionDeclarations,
    if (optimizer) CoachToolService.askUserQuestionsDeclaration,
  ];
  return ToolRegistry(
    declarations.map((declaration) => RepForgeTool(service, declaration)),
  );
}

class RepForgeTool implements AgentTool {
  final CoachToolService service;
  @override
  final ToolDefinition definition;
  static const writes = {
    'create_routine',
    'update_routine',
    'add_custom_exercise',
    'update_exercise',
  };

  RepForgeTool(this.service, sdk.FunctionDeclaration declaration)
    : definition = ToolDefinition(
        name: declaration.name,
        description: declaration.description,
        arguments: _arguments(declaration),
        effect: writes.contains(declaration.name)
            ? ToolEffect.write
            : ToolEffect.read,
      );

  static ValueSchema _arguments(sdk.FunctionDeclaration declaration) {
    final schema = sdkArgumentSchema(declaration);
    if (declaration.name == 'ask_user_questions') {
      final properties = jsonObject(schema['properties']);
      schema['properties'] = {
        ...properties,
        'questions': {
          ...jsonObject(properties['questions']),
          'minItems': 1,
          'maxItems': 3,
        },
      };
    }
    return ValueSchema(schema);
  }

  @override
  Future<ToolOutcome> execute(ToolContext context) async {
    context.cancellation.check();
    if (definition.name == 'ask_user_questions') {
      return ToolNeedsInput(
        InputRequest(
          kind: 'repforge_questions',
          payload: context.call.arguments,
          responseSchema: ValueSchema.object(
            properties: {
              'answers': ValueSchema({
                'type': 'array',
                'minItems': 1,
                'maxItems': 3,
                'items': ValueSchema.object(
                  properties: {
                    'question': ValueSchema.string(),
                    'selected': ValueSchema({
                      'type': 'array',
                      'items': {'type': 'string'},
                    }),
                    'custom': ValueSchema.string(),
                  },
                  required: ['question', 'selected'],
                ).definition,
              }),
            },
            required: ['answers'],
          ),
        ),
      );
    }
    return ToolSuccess(
      await service.handleCall(
        sdk.FunctionCall(definition.name, context.call.arguments),
      ),
    );
  }
}
