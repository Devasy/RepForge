// ai_coach_screen.dart — Conversational AI workout coach (View).
//
// This is a lean View: all orchestration (streaming, tool calls, persistence,
// system-prompt building) lives in AiCoachViewModel. The widget only renders
// state, forwards user intents, and holds UI-local controllers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../models/models.dart';
import '../genui/a2ui.dart';
import '../viewmodels/ai_coach_view_model.dart';
import '../services/ai/gemini_ai_service.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/rf_shell.dart';
import 'profile_screen.dart';

/// Bubbles stop short of the far edge; full-bleed ones read as banners.
const double _kBubbleMaxWidthFactor = 0.82;

/// Public entry point. Owns the screen-scoped [AiCoachViewModel].
class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key, this.seedPrompt});

  /// Optional question to auto-send on open (e.g. deep-linked from analytics).
  final String? seedPrompt;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AiCoachViewModel>(
      create: (ctx) => AiCoachViewModel(
        ai: ctx.read<GeminiAiService>(),
        coachTools: ctx.read<CoachToolService>(),
        conversations: ctx.read<ConversationManager>(),
        settings: ctx.read<SettingsProvider>(),
      )..loadConversations(),
      child: _AiCoachView(seedPrompt: seedPrompt),
    );
  }
}

class _AiCoachView extends StatefulWidget {
  const _AiCoachView({this.seedPrompt});
  final String? seedPrompt;

  @override
  State<_AiCoachView> createState() => _AiCoachViewState();
}

class _AiCoachViewState extends State<_AiCoachView> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  AiCoachViewModel? _vm;

  @override
  void initState() {
    super.initState();
    final seed = widget.seedPrompt?.trim();
    if (seed != null && seed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vm = context.read<AiCoachViewModel>();
        if (!vm.isConfigured) return;
        _controller.clear();
        vm.sendMessage(seed);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attach a scroll-follow listener once.
    final vm = context.read<AiCoachViewModel>();
    if (!identical(vm, _vm)) {
      _vm?.removeListener(_onVmChanged);
      _vm = vm..addListener(_onVmChanged);
    }
  }

  void _onVmChanged() => _scrollToBottom();

  @override
  void dispose() {
    _vm?.removeListener(_onVmChanged);
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    context.read<AiCoachViewModel>().sendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: AppDurations.moderate,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AiCoachViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AmbientGlow(),
          // No wrapping SafeArea: header takes the top inset, input bar the bottom.
          Column(
            children: [
              _buildHeader(context, vm),
              Expanded(
                child: vm.isConfigured
                    ? _buildChatArea(vm)
                    : _buildNoKeyState(context),
              ),
              if (vm.isConfigured) _buildInputBar(vm),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AiCoachViewModel vm) {
    return RFScreenHeader(
      title: 'AI Coach',
      subtitle: 'Powered by Gemini',
      badgeIcon: Icons.auto_awesome_rounded,
      onBack: () => Navigator.pop(context),
      actions: [
        if (vm.isConfigured) ...[
          RFIconButton(
            icon: Icons.history_rounded,
            tooltip: 'Past conversations',
            onTap: () => _openHistory(context, vm),
          ),
          RFIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New chat',
            onTap: vm.newConversation,
          ),
        ],
      ],
    );
  }

  Future<void> _openHistory(BuildContext context, AiCoachViewModel vm) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _ConversationsSheet(vm: vm),
    );
  }

  Widget _buildChatArea(AiCoachViewModel vm) {
    final messages = vm.messages;
    final hasContent = messages.isNotEmpty || vm.isLoading;
    if (!hasContent) return _buildWelcome();

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      // Extra bottom room so the last turn settles clear of the input bar.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: messages.length + (vm.isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == messages.length) {
          return _StreamingBubble(
            text: vm.streamingText,
            toolCalls: vm.streamingToolCalls,
          );
        }
        return _MessageBubble(message: messages[i]);
      },
    );
  }

  Widget _buildWelcome() {
    final name = context.read<SettingsProvider>().userName;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RFGradientBadge(
              icon: Icons.auto_awesome_rounded,
              size: 72,
              radius: AppRadius.xl,
              glow: 0.45,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              name != null && name.isNotEmpty
                  ? 'Hey $name 👋'
                  : 'Your AI Coach',
              style: TextStyle(
                fontFamily: 'Geist',
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ask me anything — what to train today, how to break a plateau, reading your progress, anything.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Geist',
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final s in const [
                  'What should I train today?',
                  'How\'s my recovery?',
                  'Am I progressing on bench?',
                  'Suggest a deload week',
                ])
                  RFOptionChip(
                    label: s,
                    onTap: () {
                      _controller.text = s;
                      _send();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoKeyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RFEmptyState(
              icon: Icons.key_rounded,
              title: 'API Key Required',
              subtitle:
                  'Add your Gemini API key in\nProfile → AI Features to start chatting',
            ),
            const SizedBox(height: AppSpacing.lg),
            GlowButton(
              label: 'Go to Profile',
              icon: Icons.person_rounded,
              fullWidth: false,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(AiCoachViewModel vm) {
    return RFBottomBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: AppColors.glass2,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.glassBorderStrong),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: AppColors.primary,
                decoration: const InputDecoration(
                  hintText: 'Ask your coach…',
                  hintStyle: TextStyle(
                    fontFamily: 'Geist',
                    color: AppColors.textFaint,
                    fontSize: 14,
                  ),
                  // The container draws the only frame; the theme otherwise nests
                  // a filled 12-radius box and focus ring inside this 18-radius pill.
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Keystrokes rebuild only this button, not the whole transcript.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (_, value, _) => _SendButton(
              loading: vm.isLoading,
              enabled: value.text.trim().isNotEmpty,
              onTap: _send,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Send button ──────────────────────────────────────────────────────────────

/// Three distinguishable states: sending, ready, and nothing-to-send.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return Semantics(
      button: true,
      enabled: active,
      label: loading ? 'Sending' : 'Send message',
      // InkWell, not a bare GestureDetector: the button needs to sit in the
      // focus traversal order and activate from the keyboard. Enter already
      // sends from the text field, so this is about reaching the control
      // itself, not about the action being unavailable.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: active ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          focusColor: AppColors.primaryGlow(0.35),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: active ? AppColors.primaryGradient : null,
              color: active ? null : AppColors.glass2,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: active ? null : Border.all(color: AppColors.glassBorder),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.primaryGlow(0.4),
                        blurRadius: 12,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: active ? Colors.white : AppColors.textFaint,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Conversations history sheet ───────────────────────────────────────────────

class _ConversationsSheet extends StatelessWidget {
  const _ConversationsSheet({required this.vm});
  final AiCoachViewModel vm;

  @override
  Widget build(BuildContext context) {
    // Rebuild when the conversation list changes (delete, new message).
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final conversations = vm.conversations;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Conversations',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        vm.newConversation();
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New chat',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      'No saved conversations yet.',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final c = conversations[i];
                        final isActive = c.id == vm.activeConversationId;
                        return _ConversationTile(
                          conversation: c,
                          isActive: isActive,
                          onTap: () {
                            vm.selectConversation(c.id);
                            Navigator.pop(context);
                          },
                          onDelete: () => vm.deleteConversation(c.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.glass3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.textMuted,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                conversation.title.isEmpty ? 'New chat' : conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Geist',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textFaint,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return _Turn(
      isUser: isUser,
      toolCalls: isUser ? const [] : (message.toolCalls ?? const []),
      child: isUser
          ? Text(
              message.text,
              style: const TextStyle(
                fontFamily: 'Geist',
                color: Colors.white,
                fontSize: 14,
                height: 1.55,
              ),
            )
          : CoachMessageContent(text: message.text),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text, this.toolCalls = const []});
  final String text;
  final List<String> toolCalls;

  @override
  Widget build(BuildContext context) {
    return _Turn(
      isUser: false,
      toolCalls: toolCalls,
      toolCallsActive: true,
      // An empty stream is still a bubble — the dots need somewhere to sit.
      forceBubble: text.isEmpty,
      child: text.isEmpty
          ? const RFLoadingDots()
          : CoachMessageContent(text: text, streaming: true),
    );
  }
}

// ── Turn layout ──────────────────────────────────────────────────────────────

/// One turn: avatar, tool-call chips, and content — bubbled for prose, bare
/// for a dashboard, whose own cards would otherwise sit in a second frame.
class _Turn extends StatelessWidget {
  const _Turn({
    required this.isUser,
    required this.child,
    this.toolCalls = const [],
    this.toolCallsActive = false,
    this.forceBubble = false,
  });

  final bool isUser;
  final Widget child;
  final List<String> toolCalls;
  final bool toolCallsActive;
  final bool forceBubble;

  @override
  Widget build(BuildContext context) {
    // A dashboard takes the full column; prose takes a bubble.
    final isDashboard =
        !forceBubble &&
        !isUser &&
        child is CoachMessageContent &&
        CoachMessageContent.rendersAsDashboard(
          (child as CoachMessageContent).text,
        );

    final content = isDashboard
        ? child
        : Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              gradient: isUser ? AppColors.primaryGradient : null,
              color: isUser ? null : AppColors.glass2,
              // The square corner marks the speaker's side.
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.lg),
                topRight: const Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(isUser ? AppRadius.lg : 4),
                bottomRight: Radius.circular(isUser ? 4 : AppRadius.lg),
              ),
              border: isUser ? null : Border.all(color: AppColors.glassBorder),
              boxShadow: isUser
                  ? [
                      BoxShadow(
                        color: AppColors.primaryGlow(0.25),
                        blurRadius: 12,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );

    final column = Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (toolCalls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ToolCallChips(
              toolNames: toolCalls,
              active: toolCallsActive,
            ),
          ),
        content,
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        // Top, so a tall turn's avatar sits beside its first line, not its last.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const _AiAvatar(),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (isDashboard)
            Expanded(child: column)
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.sizeOf(context).width * _kBubbleMaxWidthFactor,
                ),
                child: column,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tool-call indicator chips ─────────────────────────────────────────────────

/// Small pill row showing which coach tools were invoked while producing a
/// reply. [active] pulses subtly to indicate a tool call is in flight.
class _ToolCallChips extends StatelessWidget {
  const _ToolCallChips({required this.toolNames, this.active = false});
  final List<String> toolNames;
  final bool active;

  // Dedupe while preserving first-seen order — a tool can be called more
  // than once per turn (e.g. re-checking after an update), but the chip row
  // only needs to say *which* tools ran, not how many times.
  List<String> get _unique => <String>{...toolNames}.toList();

  String _label(String toolName) => toolName
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final name in _unique)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.bolt_rounded : Icons.build_rounded,
                  color: AppColors.secondary,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  _label(name),
                  style: const TextStyle(
                    fontFamily: 'GeistMono',
                    color: AppColors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Renders one coach reply: an A2UI dashboard when the text is a UI payload,
/// otherwise Markdown.
///
/// Public so widget tests can drive it directly. Parsing is memoized per text
/// value — the old code re-parsed on every rebuild, including on every partial
/// frame of a stream.
class CoachMessageContent extends StatefulWidget {
  const CoachMessageContent({
    super.key,
    required this.text,
    this.streaming = false,
  });

  static final _parser = A2UiParser(defaultA2UiRegistry);

  /// Parsed nodes by source text. Shared because the turn layout needs the
  /// result before this widget builds; bounded so transcripts don't accumulate.
  static final Map<String, A2UiNode?> _nodeCache = <String, A2UiNode?>{};
  static const _nodeCacheLimit = 32;

  static A2UiNode? nodeFor(String text) {
    if (_nodeCache.containsKey(text)) return _nodeCache[text];
    if (_nodeCache.length >= _nodeCacheLimit) {
      _nodeCache.remove(_nodeCache.keys.first);
    }
    return _nodeCache[text] = _parser.parse(text);
  }

  /// True when [text] is a complete A2UI payload, so renders full-width.
  static bool rendersAsDashboard(String text) => nodeFor(text) != null;

  /// True when [text] is a partial A2UI payload still arriving.
  static bool looksLikeUi(String text) => _parser.looksLikeUi(text);

  final String text;

  /// True while tokens are still arriving, so a half-written JSON payload
  /// shows a placeholder instead of raw braces.
  final bool streaming;

  @override
  State<CoachMessageContent> createState() => _CoachMessageContentState();
}

class _CoachMessageContentState extends State<CoachMessageContent> {
  @override
  Widget build(BuildContext context) {
    final node = CoachMessageContent.nodeFor(widget.text);
    if (node != null) return A2UiRenderer(node: node);

    // Mid-stream JSON: hide the braces behind a progress row rather than
    // letting the Markdown renderer spill raw payload into the bubble.
    if (widget.streaming && CoachMessageContent.looksLikeUi(widget.text)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Building dashboard…',
            style: TextStyle(
              fontFamily: 'Geist',
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    return _CoachMarkdown(text: widget.text);
  }
}

class _CoachMarkdown extends StatelessWidget {
  const _CoachMarkdown({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      text,
      style: TextStyle(
        fontFamily: 'Geist',
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 1.55,
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return const RFGradientBadge(
      icon: Icons.auto_awesome_rounded,
      size: 28,
      radius: AppRadius.sm,
    );
  }
}
