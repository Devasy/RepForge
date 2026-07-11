// agent_artifact.dart — Typed artifacts produced by tools and the runtime.
//
// Artifacts are structured outputs beyond plain text: charts, tables,
// question forms, etc. The UI renders each type with a specialized widget
// rather than trying to parse everything from a markdown string.

import '../../../models/models.dart';

/// Classification of artifact types.
enum AgentArtifactKind { text, chart, table, questionForm }

/// Sealed base for all typed artifacts the runtime can produce.
sealed class AgentArtifact {
  const AgentArtifact();
}

/// A markdown text block (for structured text that isn't chat).
class TextArtifact extends AgentArtifact {
  final String markdown;
  const TextArtifact(this.markdown);

  @override
  String toString() => 'TextArtifact(${markdown.length} chars)';
}

/// A chart/graph for inline visualization.
///
/// [spec] follows {type, title, labels/x, series} so a ChartRenderer
/// widget can consume it without knowing which tool produced it.
class ChartArtifact extends AgentArtifact {
  final String chartType; // 'line', 'bar', 'pie', etc.
  final String title;
  final Map<String, Object?> spec;

  const ChartArtifact({
    required this.chartType,
    required this.title,
    required this.spec,
  });

  @override
  String toString() => 'ChartArtifact($chartType, "$title")';
}

/// A structured data table for inline display.
class TableArtifact extends AgentArtifact {
  final String title;
  final List<String> columns;
  final List<List<Object?>> rows;

  const TableArtifact({
    required this.title,
    required this.columns,
    required this.rows,
  });

  @override
  String toString() => 'TableArtifact("$title", ${rows.length} rows)';
}

/// A question form that the user needs to answer.
class QuestionFormArtifact extends AgentArtifact {
  final PendingQuestions questions;
  const QuestionFormArtifact(this.questions);

  @override
  String toString() => 'QuestionFormArtifact(${questions.questions.length} questions)';
}
