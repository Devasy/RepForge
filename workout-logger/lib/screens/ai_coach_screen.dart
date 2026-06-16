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
import '../viewmodels/ai_coach_view_model.dart';
import '../services/ai/gemini_ai_service.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'profile_screen.dart';

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
          duration: const Duration(milliseconds: 250),
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
          SafeArea(
            child: Column(
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AiCoachViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glass3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSoft,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF5B21B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow(0.4),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Coach',
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Powered by Gemini',
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (vm.isConfigured) ...[
            _HeaderIconButton(
              icon: Icons.history_rounded,
              onTap: () => _openHistory(context, vm),
            ),
            const SizedBox(width: AppSpacing.sm),
            _HeaderIconButton(
              icon: Icons.add_rounded,
              onTap: () {
                HapticFeedback.lightImpact();
                vm.newConversation();
              },
            ),
          ],
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      itemCount: messages.length + (vm.isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == messages.length) {
          return _StreamingBubble(text: vm.streamingText);
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGlow(0.45),
                    blurRadius: 28,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              name != null && name.isNotEmpty ? 'Hey $name 👋' : 'Your AI Coach',
              style: TextStyle(fontFamily: 'Geist', 
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
              style: TextStyle(fontFamily: 'Geist', 
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
                  _SuggestionChip(
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
              subtitle: 'Add your Gemini API key in\nProfile → AI Features to start chatting',
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
    final loading = vm.isLoading;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glass3,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.glassBorderStrong),
              ),
              child: TextField(
                controller: _controller,
                style: TextStyle(fontFamily: 'Geist', 
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask your coach...',
                  hintStyle: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textFaint,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: loading ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: loading
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: loading ? AppColors.glass3 : null,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: loading
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primaryGlow(0.4),
                          blurRadius: 12,
                          spreadRadius: -4,
                        ),
                      ],
              ),
              child: loading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header icon button ──────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: AppColors.textSoft, size: 18),
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
                      style: TextStyle(fontFamily: 'Geist', 
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
                          const Icon(Icons.add_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'New chat',
                            style: TextStyle(fontFamily: 'Geist', 
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'No saved conversations yet.',
                      style: TextStyle(fontFamily: 'Geist', 
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
                      separatorBuilder: (_, __) =>
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
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : AppColors.glass3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.textMuted, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                conversation.title.isEmpty ? 'New chat' : conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Geist', 
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
                child: Icon(Icons.delete_outline_rounded,
                    color: AppColors.textFaint, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'Geist', 
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _AiAvatar(),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : AppColors.glass3,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isUser ? AppRadius.lg : 4),
                  bottomRight: Radius.circular(isUser ? 4 : AppRadius.lg),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.glassBorder),
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
              child: isUser
                  ? Text(
                      message.text,
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    )
                  : _CoachMarkdown(text: message.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AiAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.glass3,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: text.isEmpty
                  ? const RFLoadingDots()
                  : _CoachMarkdown(text: text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Markdown renderer for coach replies, styled to the app theme.
class _CoachMarkdown extends StatelessWidget {
  const _CoachMarkdown({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      text,
      style: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 1.55,
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow(0.35),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
    );
  }
}
