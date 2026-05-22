// ai_coach_screen.dart — Conversational AI workout coach powered by Gemini

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/gemini_service.dart';
import '../services/gemini_context_builder.dart';
import '../services/workout_provider.dart';
import '../services/settings_provider.dart';
import '../services/interfaces/ml_service_interface.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'profile_screen.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});
  final String role; // 'user' | 'model'
  final String text;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _loading = false;
  String _streamingText = '';

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _buildSystemPrompt() {
    final wp = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final mlService = context.read<IMLService>();

    final exerciseMap = {for (final e in wp.allExercises) e.id: e};
    final allSessions = wp.sessions;
    final recoveryScores = mlService.computeMuscleRecoveryScores(
      allSessions,
      exerciseMap,
    );
    final activeTargets = wp.targets.where((t) => !t.isCompleted).toList();

    return GeminiContextBuilder.buildCoachSystemPrompt(
      recentSessions: allSessions,
      exerciseMap: exerciseMap,
      recoveryScores: recoveryScores,
      activeTargets: activeTargets,
      userName: settings.userName,
      unitLabel: settings.unitLabel,
    );
  }

  List<Content> _buildHistory() => _messages
      .map((m) => Content(m.role, [TextPart(m.text)]))
      .toList();

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    HapticFeedback.lightImpact();
    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _loading = true;
      _streamingText = '';
    });
    _scrollToBottom();

    final gemini = context.read<GeminiService>();
    final systemPrompt = _buildSystemPrompt();
    // Build history from all messages except the one we just added.
    final history = _messages.length > 1
        ? _buildHistory().sublist(0, _messages.length - 1)
        : <Content>[];

    final buffer = StringBuffer();
    try {
      await for (final chunk in gemini.streamCoachReply(
        userMessage: text,
        systemPrompt: systemPrompt,
        history: history,
      )) {
        buffer.write(chunk);
        if (mounted) {
          setState(() => _streamingText = buffer.toString());
          _scrollToBottom();
        }
      }
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(role: 'model', text: buffer.toString()));
          _streamingText = '';
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() { _streamingText = ''; _loading = false; });
    }
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
    final gemini = context.watch<GeminiService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AmbientGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: gemini.isConfigured
                      ? _buildChatArea()
                      : _buildNoKeyState(context),
                ),
                if (gemini.isConfigured) _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  style: GoogleFonts.geist(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Powered by Gemini',
                  style: GoogleFonts.geist(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _messages.clear()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  'Clear',
                  style: GoogleFonts.geist(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    final hasMessages = _messages.isNotEmpty || _loading;

    if (!hasMessages) return _buildWelcome();

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) {
          // Streaming bubble
          return _StreamingBubble(text: _streamingText);
        }
        return _MessageBubble(message: _messages[i]);
      },
    );
  }

  Widget _buildWelcome() {
    final settings = context.read<SettingsProvider>();
    final name = settings.userName;
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
              name != null && name.isNotEmpty
                  ? 'Hey $name 👋'
                  : 'Your AI Coach',
              style: GoogleFonts.geist(
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
              style: GoogleFonts.geist(
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
              children: const [
                _SuggestionChip('What should I train today?'),
                _SuggestionChip('How\'s my recovery?'),
                _SuggestionChip('Am I progressing on bench?'),
                _SuggestionChip('Suggest a deload week'),
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

  Widget _buildInputBar() {
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
                style: GoogleFonts.geist(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask your coach...',
                  hintStyle: GoogleFonts.geist(
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
            onTap: _loading ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _loading
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _loading ? AppColors.glass3 : null,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: _loading
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primaryGlow(0.4),
                          blurRadius: 12,
                          spreadRadius: -4,
                        ),
                      ],
              ),
              child: _loading
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

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_AiCoachScreenState>();
        if (state == null) return;
        state._controller.text = label;
        state._send();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
        ),
        child: Text(
          label,
          style: GoogleFonts.geist(
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
  final _ChatMessage message;

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
              child: Text(
                message.text,
                style: GoogleFonts.geist(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
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
                  : Text(
                      text,
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
            ),
          ),
        ],
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
