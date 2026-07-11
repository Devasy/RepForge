// agent_interrupt.dart — Typed interrupts for human-in-the-loop flows.
//
// When a graph node needs human input (e.g. the model calls ask_user_questions),
// it returns InterruptRun(interrupt) instead of NextNode. The runtime suspends
// the run and emits AgentInterrupted. Later, runtime.resume() provides the
// user's response and the graph continues.

import '../../../models/models.dart';

/// Sealed base for all interrupt types.
sealed class AgentInterrupt {
  const AgentInterrupt();
}

/// The model wants to ask the user 1–3 clarifying questions before proceeding.
/// The UI renders a question form; answers are fed back via runtime.resume().
class AwaitUserQuestions extends AgentInterrupt {
  final PendingQuestions payload;
  const AwaitUserQuestions(this.payload);

  @override
  String toString() => 'AwaitUserQuestions(${payload.questions.length} questions)';
}

// Future interrupt types:
// class AwaitConfirmation extends AgentInterrupt { ... }
// class AwaitFileUpload extends AgentInterrupt { ... }
