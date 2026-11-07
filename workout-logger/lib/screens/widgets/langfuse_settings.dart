import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai/observability/langfuse_config.dart';
import '../../services/ai/observability/langfuse_service.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

class DeveloperFeaturesSection extends StatelessWidget {
  const DeveloperFeaturesSection({super.key});
  @override
  Widget build(BuildContext context) {
    final tracing = context.watch<LangfuseService?>();
    if (tracing == null) return const SizedBox.shrink();
    return GlassCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.developer_mode, color: AppColors.primary),
        title: const Text('Developer features'),
        subtitle: Text('Langfuse · ${tracing.status}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => LangfuseSettingsDialog(service: tracing),
        ),
      ),
    );
  }
}

class LangfuseSettingsDialog extends StatefulWidget {
  const LangfuseSettingsDialog({super.key, required this.service});
  final LangfuseService service;
  @override
  State<LangfuseSettingsDialog> createState() => _LangfuseSettingsDialogState();
}

class _LangfuseSettingsDialogState extends State<LangfuseSettingsDialog> {
  late final TextEditingController _host, _public, _secret;
  late bool _enabled, _capture;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    final config = widget.service.config;
    _host = TextEditingController(text: config.host);
    _public = TextEditingController(text: config.publicKey);
    _secret = TextEditingController(text: config.secretKey);
    _enabled = config.enabled;
    _capture = config.captureContent;
  }

  LangfuseConfig get _config => LangfuseConfig(
    host: _host.text.trim(),
    publicKey: _public.text.trim(),
    secretKey: _secret.text.trim(),
    enabled: _enabled,
    captureContent: _capture,
  );
  Future<void> _act(bool test) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (test) {
        await widget.service.testConnection(_config);
        if (mounted) setState(() => _message = 'Connection successful');
      } else {
        await widget.service.save(_config);
        if (mounted) Navigator.pop(context);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = test
              ? 'Connection failed. Check the host and keys.'
              : 'Could not securely save settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _public.dispose();
    _secret.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget _switches() => Column(
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enable Langfuse tracing'),
        value: _enabled,
        onChanged: _busy ? null : (value) => setState(() => _enabled = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Include conversation and tool content'),
        subtitle: const Text(
          'Sends prompts, replies, SQL and tool results to your Langfuse project. These may contain workout or health data. Keys and images are excluded.',
        ),
        value: _capture,
        onChanged: _busy ? null : (value) => setState(() => _capture = value),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Langfuse'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use your own developer project credentials. Saved securely on this device, outside workout backups.',
            ),
            const SizedBox(height: 16),
            _field('Host URL', _host),
            _field('Public key', _public),
            _field('Secret key', _secret, secret: true),
            _switches(),
            if (_message != null)
              Text(_message!, key: const ValueKey('langfuse-message')),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _busy ? null : () => _act(true),
        child: const Text('Test connection'),
      ),
      FilledButton(
        onPressed: _busy ? null : () => _act(false),
        child: const Text('Save'),
      ),
    ],
  );
}
