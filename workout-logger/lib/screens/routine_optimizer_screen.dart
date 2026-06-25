// routine_optimizer_screen.dart — Full-screen conversational routine optimizer UI.
//
// This is a lean View: all orchestration (streaming, tool calls, question
// intercept, persistence) lives in RoutineOptimizerViewModel. The widget only
// renders state, forwards user intents, and holds UI-local controllers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../models/models.dart';
import '../viewmodels/routine_optimizer_view_model.dart';
import '../services/ai/gemini_ai_service.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/interfaces/storage_service_interface.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/rf_question_card.dart';

/// Public entry point. Owns the screen-scoped [RoutineOptimizerViewModel].
class RoutineOptimizerScreen extends StatelessWidget {
  const RoutineOptimizerScreen({super.key, required this.routine});

  final Routine routine;

  /// Renders only the view body with an externally provided VM.
  /// Use this in widget tests to avoid wiring up real AI services.
  @visibleForTesting
  static Widget testBody(Routine routine) => _OptimizerView(routine: routine);

  @override
  Widget build(BuildContext context) {
    final storage = context.read<IStorageService>();
    return ChangeNotifierProvider<RoutineOptimizerViewModel>(
      create: (ctx) {
        final conversations =
            ConversationManager(storage, kind: 'optimizer');
        return RoutineOptimizerViewModel(
          ai: ctx.read<GeminiAiService>(),
          coachTools: ctx.read<CoachToolService>(),
          conversations: conversations,
          settings: ctx.read<SettingsProvider>(),
        )
          ..loadConversations()
          ..startForRoutine(routine);
      },
      child: _OptimizerView(routine: routine),
    );
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

class _OptimizerView extends StatefulWidget {
  const _OptimizerView({required this.routine});
  final Routine routine;

  @override
  State<_OptimizerView> createState() => _OptimizerViewState();
}

class _OptimizerViewState extends State<_OptimizerView> {
  final _scrollCtrl = ScrollController();
  RoutineOptimizerViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<RoutineOptimizerViewModel>();
    if (!identical(vm, _vm)) {
      _vm?.removeListener(_onVmChanged);
      _vm = vm..addListener(_onVmChanged);
    }
  }

  void _onVmChanged() => _scrollToBottom();

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
  void dispose() {
    _vm?.removeListener(_onVmChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoutineOptimizerViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AmbientGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, vm),
                Expanded(child: _buildChatArea(vm)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RoutineOptimizerViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          // Back button
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
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, Color(0xFF0097A7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryGlow(0.4),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_fix_high_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Optimize Routine',
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  widget.routine.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // History button
          _HeaderIconButton(
            icon: Icons.history_rounded,
            onTap: () => _openHistory(context, vm),
          ),
        ],
      ),
    );
  }

  Future<void> _openHistory(
    BuildContext context,
    RoutineOptimizerViewModel vm,
  ) async {
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

  Widget _buildChatArea(RoutineOptimizerViewModel vm) {
    final messages = vm.messages;
    final hasContent = messages.isNotEmpty || vm.isLoading;
    if (!hasContent) return _buildEmpty();

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
          // Loading slot — show question card if pending, else streaming bubble
          if (vm.pendingQuestions != null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: RFQuestionCard(
                questions: vm.pendingQuestions!.questions,
                onSubmit: vm.submitAnswers,
              ),
            );
          }
          return _StreamingBubble(text: vm.streamingText);
        }
        return _MessageBubble(message: messages[i]);
      },
    );
  }

  Widget _buildEmpty() {
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
                  colors: [AppColors.secondary, Color(0xFF0097A7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondaryGlow(0.45),
                    blurRadius: 28,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Analyzing your routine…',
              style: TextStyle(fontFamily: 'Geist', 
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Reviewing your history and building a personalized plan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Geist', 
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
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
          color: AppColors.glass3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: AppColors.textSoft, size: 18),
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
            _OptimizerAvatar(),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
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
              child: isUser
                  ? Text(
                      message.text,
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    )
                  : _OptimizerMarkdown(text: message.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streaming bubble ──────────────────────────────────────────────────────────

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
          _OptimizerAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
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
                  ? const RFLoadingDots(color: AppColors.secondary)
                  : _OptimizerMarkdown(text: text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Markdown renderer styled to the app theme.
class _OptimizerMarkdown extends StatelessWidget {
  const _OptimizerMarkdown({required this.text});
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

class _OptimizerAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, Color(0xFF0097A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryGlow(0.35),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 14),
    );
  }
}

// ── Conversations history sheet ───────────────────────────────────────────────

class _ConversationsSheet extends StatelessWidget {
  const _ConversationsSheet({required this.vm});
  final RoutineOptimizerViewModel vm;

  @override
  Widget build(BuildContext context) {
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
                Text(
                  'Optimization History',
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'No saved optimization sessions yet.',
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
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.secondary.withValues(alpha: 0.12)
              : AppColors.glass3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive
                ? AppColors.secondary.withValues(alpha: 0.4)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_fix_high_rounded,
                color: AppColors.textMuted, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title.isEmpty
                        ? 'Optimization session'
                        : conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${conversation.messages.length} messages',
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.textFaint,
                      fontSize: 11,
                    ),
                  ),
                ],
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
