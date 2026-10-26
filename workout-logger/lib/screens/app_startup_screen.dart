import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return _StartupLayout(
      child: Semantics(
        label: 'Starting RepForge',
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/repforge_signal_foreground_v7.png',
              width: 192,
              height: 192,
              excludeFromSemantics: true,
            ),
            if (!reducedMotion) ...[
              const SizedBox(height: AppSpacing.lg),
              const ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppStartupErrorScreen extends StatelessWidget {
  const AppStartupErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _StartupLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              'Couldn’t start RepForge',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try again to finish opening the app.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: AppSpacing.md),
          ExpansionTile(
            title: const Text('Error details'),
            tilePadding: EdgeInsets.zero,
            expandedAlignment: Alignment.centerLeft,
            children: [SelectableText(error, style: textTheme.bodyMedium)],
          ),
        ],
      ),
    );
  }
}

class _StartupLayout extends StatelessWidget {
  const _StartupLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.lg * 2).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
