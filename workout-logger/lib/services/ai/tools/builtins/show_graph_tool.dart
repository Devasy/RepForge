// show_graph_tool.dart — UI tool for inline chart visualization.
//
// When the model calls show_graph, this tool produces a ChartArtifact
// that the UI renders inline in the chat.

import '../../runtime/agent_artifact.dart';
import '../agent_tool.dart';
import '../tool_metadata.dart';
import '../tool_result.dart';
import '../tool_spec.dart';

class ShowGraphTool implements AgentTool {
  @override
  String get id => 'show_graph';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Show graph',
        kind: ToolKind.ui,
        readOnly: true,
        outputKind: AgentArtifactKind.chart,
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'show_graph',
        description:
            'Display a chart/graph inline in the conversation. Pass the '
            'chart type (line, bar, pie), a title, and the data series. '
            'Use after fetching performance data to visualize trends.',
        parameters: {
          'chart_type': ToolParam.string(
            description: 'Chart type: "line", "bar", or "pie".',
          ),
          'title': ToolParam.string(
            description: 'Chart title, e.g. "Bench Press Progress".',
          ),
          'x_labels': ToolParam.array(
            items: ToolParam.string(),
            description: 'X-axis labels (dates, categories, etc.).',
            nullable: true,
          ),
          'series': ToolParam.array(
            items: ToolParam.object(
              properties: {
                'name': ToolParam.string(description: 'Series name.'),
                'values': ToolParam.array(
                  items: ToolParam.number(),
                  description: 'Data values for this series.',
                ),
              },
              requiredProperties: ['name', 'values'],
            ),
            description: 'One or more data series to plot.',
          ),
        },
        required: ['chart_type', 'title', 'series'],
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final chartType = (ctx.args['chart_type'] as String?) ?? 'line';
    final title = (ctx.args['title'] as String?) ?? 'Chart';

    final spec = Map<String, Object?>.from(ctx.args);

    return ToolResult(
      data: {'chart_spec': spec},
      artifacts: [
        ChartArtifact(
          chartType: chartType,
          title: title,
          spec: spec,
        ),
      ],
    );
  }
}
