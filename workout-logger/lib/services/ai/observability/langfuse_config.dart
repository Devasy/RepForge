class LangfuseConfig {
  const LangfuseConfig({
    this.host = 'https://cloud.langfuse.com',
    this.publicKey = '',
    this.secretKey = '',
    this.enabled = false,
    this.captureContent = false,
  });
  final String host, publicKey, secretKey;
  final bool enabled, captureContent;
  Uri get endpoint {
    final uri = Uri.tryParse(host.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Use an HTTPS Langfuse host without a path, query or credentials.',
      );
    }
    return uri.replace(path: '/api/public/otel/v1/traces');
  }

  void validate() {
    endpoint;
    if (!RegExp(r'^pk-lf-[a-zA-Z0-9_-]{8,}$').hasMatch(publicKey) ||
        !RegExp(r'^sk-lf-[a-zA-Z0-9_-]{8,}$').hasMatch(secretKey) ||
        publicKey.contains('...') ||
        secretKey.contains('...')) {
      throw const FormatException(
        'Enter your real Langfuse public and secret keys.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'host': host,
    'publicKey': publicKey,
    'secretKey': secretKey,
    'enabled': enabled,
    'captureContent': captureContent,
  };
  factory LangfuseConfig.fromJson(Map<String, dynamic> data) => LangfuseConfig(
    host: data['host'] as String? ?? 'https://cloud.langfuse.com',
    publicKey: data['publicKey'] as String? ?? '',
    secretKey: data['secretKey'] as String? ?? '',
    enabled: data['enabled'] == true,
    captureContent: data['captureContent'] == true,
  );
}
