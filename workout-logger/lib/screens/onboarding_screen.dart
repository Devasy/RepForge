// onboarding_screen.dart — First-launch name prompt + version update modal.
//
// Shown by AppInitializer when:
//   • userName == null  → full welcome page asking for name
//   • userName != null && version changed → version-update bottom sheet

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_provider.dart';
import '../services/release_service.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/gender_picker.dart';
import '../data/body_figure.dart';
import 'widgets/release_widgets.dart';

// ── Welcome page (first install) ──────────────────────────────────────────────

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _controller = TextEditingController();
  bool _saving = false;
  UserGender _gender = UserGender.preferNotToSay;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final settings = context.read<SettingsProvider>();
      await settings.setUserGender(_gender);
      await settings.setUserName(name);
      final version = await settings.getCurrentVersion();
      await settings.markVersionSeen(version);
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your profile. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AmbientGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SingleChildScrollView(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 36),
                  // Logo mark
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.secondary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Welcome to\nRepForge',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Track every rep. Beat every record.\nForge your best self.',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 15,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'WHAT SHOULD WE CALL YOU?',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      hintStyle: TextStyle(
                        fontFamily: 'Geist',
                        color: AppColors.textFaint,
                      ),
                      filled: true,
                      fillColor: AppColors.glass2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GenderPicker(value: _gender, onChanged: _saving ? null :
                    (value) => setState(() => _gender = value)),
                  const SizedBox(height: 8),
                  const Text('Chooses muscle diagrams throughout the app. Change your gender in Profile.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: GlowButton(
                      label: _saving ? 'Setting up…' : "Let's Go!",
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              )),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-time setup for existing users whose database has no saved gender.
class GenderSetupPage extends StatefulWidget {
  const GenderSetupPage({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<GenderSetupPage> createState() => _GenderSetupPageState();
}

class _GenderSetupPageState extends State<GenderSetupPage> {
  bool _saving = false;

  Future<void> _select(UserGender gender) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<SettingsProvider>().setUserGender(gender);
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your gender. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Choose your gender', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        const Text('This selects the muscle diagrams used throughout RepForge. You can change your gender later in Profile.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        const SizedBox(height: AppSpacing.xl),
        for (final entry in const {
          UserGender.male: 'Male', UserGender.female: 'Female',
          UserGender.preferNotToSay: 'Prefer not to say',
        }.entries) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: OutlinedButton(onPressed: _saving ? null : () => _select(entry.key),
            child: Text(entry.value))),
        if (_saving) const Center(child: CircularProgressIndicator()),
      ]),
    ))),
  );
}

// ── Version-update bottom sheet ───────────────────────────────────────────────

Future<void> showVersionUpdateSheet(
  BuildContext context,
  String version, {
  String? previousVersion,
  ReleaseService? releaseService,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _VersionUpdateSheet(
      version: version,
      previousVersion: previousVersion,
      releaseService: releaseService,
    ),
  );
}

class _VersionUpdateSheet extends StatelessWidget {
  const _VersionUpdateSheet({
    required this.version,
    this.previousVersion,
    this.releaseService,
  });

  final String version;
  final String? previousVersion;
  final ReleaseService? releaseService;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.new_releases_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Updated to v$version',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'RepForge is better than ever',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ReleaseNotes(
              current: version,
              previous: previousVersion,
              service: releaseService,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GlowButton(
                label: "Let's Crush It",
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
