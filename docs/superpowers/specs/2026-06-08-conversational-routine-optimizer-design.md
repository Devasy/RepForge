# Conversational Routine Optimizer — Design

**Date:** 2026-06-08
**Status:** Approved (pending spec review)

## Context

RepForge has an AI coach (streaming chat with a function-calling tool loop) and,
from a prior session, a **standalone one-shot routine optimizer**: tapping
"Optimize" on a routine card opened a bottom sheet that made a single
`generateOptimization()` JSON call and rendered accept/reject suggestion cards.

That one-shot sheet has three gaps we now want to close:

1. **No clarifying questions.** It guesses user intent (goal, frequency, which
   exercises to keep) instead of asking.
2. **No data gate.** It will "optimize" a routine that has never been logged.
3. **No conversation / history.** It is isolated from the coach's
   streaming + tool-call + persistence machinery and keeps no record.

This redesign replaces the one-shot sheet with a **dedicated conversational
optimizer screen** that reuses the coach's existing streaming tool-loop, adds an
interactive `ask_user_questions` tool (Claude-Code style: a question + 3–4
option chips + custom text input), gates on insufficient data, and persists each
optimization session to its own history "inbox" — separate from the coach chat.

## Goals

- Optimize a routine through a multi-turn, streaming conversation.
- Let the AI ask the user clarifying questions mid-stream and wait for answers.
- Block optimization when the routine has too little history (< 3 sessions).
- Persist optimization conversations in a **separate inbox**, never mixed with
  coach chats. Launching from a routine always starts a **new** conversation.
- Reuse existing infrastructure (`streamCoachReply`, `CoachToolService`,
  `ConversationManager`) — no new AI backend method.

## Non-Goals

- No new Hive box (the existing `conversations` box is reused, discriminated by
  a `kind` field).
- No changes to the coach screen's behavior or its conversation list.
- No streaming-pause/parsing of text "markers" — the SDK already separates
  `functionCalls` from text, so a tool call in flight is detectable directly.

## Architecture Overview

```
RoutineCard "Optimize" tap
        │  (gate: sessions for routine.id >= 3 ?)
        ▼
RoutineOptimizerScreen  ──watches──►  RoutineOptimizerViewModel
        │                                   │
        │ renders transcript +              │ orchestrates:
        │ inline RFQuestionCard             │  - new conversation (kind='optimizer')
        │                                   │  - streamCoachReply(systemPrompt, tools, onToolCall)
        │                                   │  - intercepts ask_user_questions → Completer
        │                                   ▼
        │                            IAiService.streamCoachReply  (EXISTING, unchanged)
        │                                   │  tool-call loop awaits onToolCall(call)
        │                                   ▼
        │                    onToolCall router:
        │                      ask_user_questions ─► VM (UI prompt, await Completer)
        │                      everything else     ─► CoachToolService.handleCall
        ▼
ConversationManager(kind='optimizer')  ──►  IStorageService (shared box, filtered)
```

## Components

### 1. Entry point & data gate (`routines_screen.dart`)

The existing "Optimize" button (`_RoutineCard`) changes its action:

- Compute `sessionCount = wp.sessions.where((s) => s.routineId == routine.id).length`.
- If `sessionCount < 3`: show a SnackBar / inline message:
  *"Not enough data yet — log '{routine.name}' at least 3 times so the coach has
  something to analyze."* Do not navigate.
- Else: `Navigator.push` to `RoutineOptimizerScreen(routine: routine)`.

Rationale for client-side gate: deterministic and cheap (no AI call wasted), and
the threshold (3) is a fixed product decision.

### 2. `ask_user_questions` tool (Claude-Code style)

A new `FunctionDeclaration` advertised to the model **only in the optimizer
flow** (added to the optimizer's tool list, not the coach's). Schema:

```jsonc
{
  "preamble": "string?  // optional short message shown above the questions",
  "questions": [
    {
      "question": "string",
      "options": ["string", ...],   // 3-4 suggested answers
      "multiSelect": true | false,  // AI chooses per question
      "allowCustom": true           // always allow free-text
    }
  ]
}
```

The model returns answers indirectly: the tool's **function response** is the
user's answers, e.g.
`{ "answers": [ { "question": "...", "selected": ["Hypertrophy"], "custom": null } ] }`.

This tool is **not** handled by `CoachToolService` (which has no UI). Instead the
ViewModel's `onToolCall` router intercepts `ask_user_questions` and routes all
other calls to `CoachToolService.handleCall`.

### 3. The pause/resume mechanism (the "simple Approach C")

`IAiService.streamCoachReply` already `await`s `onToolCall(call)` inside its
tool-loop. We exploit this directly:

- When `ask_user_questions` arrives, the VM:
  1. Parses the questions into a `PendingQuestions` value object.
  2. Sets `_pendingQuestions`, `notifyListeners()` → UI renders `RFQuestionCard`s.
  3. Creates a `Completer<Map<String,Object?>>` and **returns its `.future`**
     from `onToolCall`. The stream loop is now naturally suspended.
- When the user submits, the screen calls `vm.submitAnswers(...)`, which
  completes the Completer with the answers map. The loop resumes, feeds answers
  back to Gemini, and streaming continues.

While `isLoading` is true:
- If `_pendingQuestions != null` → render the question card (awaiting input).
- Else → render a small status row ("Analyzing your performance…") + live
  streaming text. (A tool call being in flight is simply: loading, no pending
  questions, no new text yet.)

No text-marker parsing is required.

### 4. `RFQuestionCard` (reusable widget, `rf_widgets.dart`)

A generic, app-wide widget so future flows (coach, onboarding) can reuse it:

```dart
RFQuestionCard({
  required QuestionSpec spec,          // question, options, multiSelect, allowCustom
  required ValueChanged<AnswerSpec> onSubmit,
})
```

- Renders the question text, option chips (single- or multi-select per `spec`),
  a "custom answer" text field when `allowCustom`, and a Submit button.
- Single-select: tapping a chip selects it (radio behavior).
- Multi-select: chips toggle; multiple can be active.
- Custom text, when non-empty, is included alongside (or instead of) chips.
- Pure UI — no provider/AI knowledge. Driven entirely by `spec` + `onSubmit`.

Data classes `QuestionSpec` / `AnswerSpec` live in `models.dart` (or a small
`ai_question.dart`), with `fromJson`/`toJson` for the tool payload.

### 5. `RoutineOptimizerViewModel` (rewritten from one-shot to conversational)

Replaces the old one-shot analyze/apply VM. Responsibilities mirror
`AiCoachViewModel`, scoped to optimization:

- Constructor injects `IAiService`, `CoachToolService`, and a
  `ConversationManager` instance **scoped to `kind='optimizer'`**, plus
  `WorkoutProvider` (for the seed prompt / gate context) and `SettingsProvider`.
- `startForRoutine(Routine)`: starts a fresh conversation and auto-sends the
  seed user message *"Optimize my '{name}' routine based on my past performance."*
- `sendMessage(text)`: same streaming/persist flow as the coach VM, but with:
  - an **optimization-focused system prompt** (instructs the model to ask
    clarifying questions via `ask_user_questions` when intent is unclear, to use
    the read tools to ground analysis, to propose reorder/replace/add changes,
    and to apply them via `update_routine` only after the user agrees);
  - `tools = _coachTools.buildTools() + [askUserQuestionsDeclaration]`;
  - `onToolCall = _routeToolCall` (intercepts `ask_user_questions`).
- `submitAnswers(AnswerSpec...)`: completes the pending Completer.
- Exposed state: `isLoading`, `streamingText`, `messages`, `conversations`
  (optimizer inbox), `activeConversationId`, `pendingQuestions`.

**History persistence note:** the interactive question card is ephemeral UI.
What gets persisted is plain text: the model's `preamble` (as a model message)
and the user's chosen answers (as a user message, e.g.
*"Goal: Hypertrophy · Frequency: 4×/week"*). This keeps conversations replayable
as ordinary text transcripts.

### 6. Separate optimizer inbox (`Conversation.kind` + scoped manager)

- Add `String kind` to `Conversation` (default `'coach'`; optimizer uses
  `'optimizer'`). Backward compatible: missing JSON field → `'coach'`.
- `ConversationManager` gains an optional `kind` filter (constructor param):
  `loadConversations()` filters `getAllConversations()` to that kind;
  `appendMessage` stamps the kind on new conversations. Each instance keeps its
  own `_active`, so coach and optimizer never collide.
- DI: register a second `ConversationManager(storage, kind: 'optimizer')` (or
  construct it inside the optimizer screen's provider scope). The coach's
  existing manager defaults to `kind: 'coach'`.
- The optimizer screen shows its own history list (the "inbox") + a "new
  optimization" affordance; launching from a routine always begins a new
  conversation.

### 7. Removed code

- `lib/screens/widgets/routine_optimization_sheet.dart` — deleted.
- `IAiService.generateOptimization` + its `GeminiAiService` implementation —
  deleted.
- Old one-shot body of `RoutineOptimizerViewModel` — rewritten.
- `RoutineOptimizationResult` / `RoutineSuggestion` / `SuggestionType` models —
  **retained only if** reused by the new prompt/tooling; otherwise deleted. (The
  conversational flow applies changes via `update_routine`, so these are likely
  removed.) Decision deferred to the implementation plan after confirming no
  other references.

## Data Flow (happy path)

1. User taps Optimize on "Push Day" (5 logged sessions → passes gate).
2. `RoutineOptimizerScreen` opens; VM starts a new `kind='optimizer'`
   conversation and sends the seed prompt.
3. Model streams: *"Let me check a few things first."* then calls
   `ask_user_questions` → stream suspends, card renders:
   - "Primary goal?" [Strength / Hypertrophy / Endurance] (single, +custom)
   - "Sessions per week for this routine?" [2 / 3 / 4 / 5] (single, +custom)
4. User answers → `submitAnswers` → loop resumes; answers persisted as a user
   message.
5. Model calls `get_routine_performance` / `get_exercise_performance` (status
   row shows "Analyzing…"), then streams its analysis + proposed changes.
6. Model calls `ask_user_questions` again to confirm which changes to apply
   (multiSelect over the proposed reorder/replace/add).
7. On confirmation, model calls `update_routine` (existing write tool) → routine
   saved. Model confirms in text. Conversation persisted in the optimizer inbox.

## Error Handling

- **Insufficient data:** gated before navigation (SnackBar/inline message).
- **AI not configured:** existing check — SnackBar "Add your Gemini API key…".
- **Stream/tool error:** caught in `sendMessage` (as in the coach VM); error
  appended as a model message; loop ends cleanly; `_pendingQuestions` cleared so
  the UI never gets stuck awaiting answers.
- **User abandons a pending question** (navigates back): the Completer is
  completed with an empty/declined answer on dispose so no Future leaks.
- **`update_routine` failure / unresolved exercise names:** the tool already
  returns an `error` map; the model surfaces it conversationally.

## Testing

- **Unit (`RoutineOptimizerViewModel`)** with a fake `IAiService`:
  - Seed prompt is sent on `startForRoutine`.
  - A scripted `ask_user_questions` call sets `pendingQuestions`; `submitAnswers`
    completes it and the loop resumes (assert tool response shape).
  - Abandoning while pending completes the Completer without leaking.
  - Error path appends a model error message and clears loading/pending.
- **Unit (`ConversationManager` kind scoping):** an `optimizer` manager only
  loads/saves `kind='optimizer'` conversations; legacy (no-kind) rows read as
  `coach` and are excluded.
- **Unit (gate):** `< 3` sessions blocks; `>= 3` proceeds.
- **Widget (`RFQuestionCard`):** single-select radio behavior, multi-select
  toggling, custom text inclusion, Submit emits correct `AnswerSpec`.
- Run `flutter analyze` and `flutter test` before completion.

## Open Items (resolve in plan)

- Final decision on retaining vs deleting `RoutineSuggestion` /
  `RoutineOptimizationResult` / `SuggestionType` (grep for references first).
- Exact DI wiring location for the `kind='optimizer'` `ConversationManager`
  (composition root in `main.dart` vs screen-scoped provider).
