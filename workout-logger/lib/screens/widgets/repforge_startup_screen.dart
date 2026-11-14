import 'package:material_ui/material_ui.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

class RepForgeStartupScreen extends StatelessWidget {
  const RepForgeStartupScreen({super.key, this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Stack(
      children: [
        const AmbientGlow(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _StartupBrand(),
                          const SizedBox(height: 12),
                          if (error == null)
                            const _StartupLoading()
                          else
                            _StartupError(error: error!, onRetry: onRetry),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StartupBrand extends StatelessWidget {
  const _StartupBrand();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRect(
        child: Align(
          heightFactor: 0.6,
          child: Image.asset(
            'assets/icon/repforge_signal_foreground_v7.png',
            width: 240,
            height: 240,
            excludeFromSemantics: true,
          ),
        ),
      ),
      const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'RepForge',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Preparing your training',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSoft, fontSize: 14),
      ),
      SizedBox(height: 28),
      SizedBox(
        width: 160,
        child: LinearProgressIndicator(
          minHeight: 3,
          color: AppColors.primary,
          backgroundColor: AppColors.glass3,
          semanticsLabel: 'Loading RepForge',
        ),
      ),
    ],
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, this.onRetry});
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Could not start RepForge',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSoft),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
      ),
    ],
  );
}
