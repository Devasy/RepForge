import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/web_search_result.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

Future<void> openSearchLink(BuildContext context, String value) async {
  final uri = externalWebUri(value);
  if (uri == null) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* The source remains available to copy from the answer. */
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Could not open this source')),
    );
  }
}

class WebSearchResultCard extends StatelessWidget {
  const WebSearchResultCard({
    super.key,
    required this.result,
    this.suggestionsBuilder,
  });
  final WebSearchResult result;
  final Widget Function(String html)? suggestionsBuilder;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: AppColors.textSoft),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Web evidence',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.query,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GptMarkdown(
            result.text,
            onLinkTap: (url, _) => openSearchLink(context, url),
            style: const TextStyle(
              fontFamily: 'Geist',
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (result.sources.isNotEmpty)
            _SearchSources(sources: result.sources),
          const SizedBox(height: 12),
          if (result.suggestionsHtml.isNotEmpty)
            suggestionsBuilder?.call(result.suggestionsHtml) ??
                GoogleSearchSuggestions(html: result.suggestionsHtml),
        ],
      ),
    ),
  );
}

class _SearchSources extends StatelessWidget {
  const _SearchSources({required this.sources});
  final List<WebSearchSource> sources;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Sources',
        style: TextStyle(color: AppColors.textSoft, fontSize: 12),
      ),
      for (final source in sources)
        TextButton.icon(
          onPressed: () => openSearchLink(context, source.url),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(source.title, softWrap: true),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: AppColors.accentInk,
            minimumSize: const Size(48, 48),
          ),
        ),
    ],
  );
}

class GoogleSearchSuggestions extends StatefulWidget {
  const GoogleSearchSuggestions({super.key, required this.html});
  final String html;
  @override
  State<GoogleSearchSuggestions> createState() =>
      _GoogleSearchSuggestionsState();
}

class _GoogleSearchSuggestionsState extends State<GoogleSearchSuggestions> {
  WebViewController? _controller;
  double _height = 120;

  @override
  void initState() {
    super.initState();
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            openSearchLink(context, request.url);
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) => _measure(),
        ),
      );
    _load();
  }

  void _load() {
    _controller?.loadHtmlString(
      '<html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>'
      '<body style="margin:0">${widget.html}</body></html>',
      baseUrl: 'https://www.google.com',
    );
  }

  Future<void> _measure() async {
    try {
      final height = await _controller?.runJavaScriptReturningResult(
        'Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)',
      );
      final value = double.tryParse(height.toString());
      if (mounted && value != null && value.isFinite) {
        setState(() => _height = value.clamp(48, 800));
      }
    } catch (_) {
      /* Keep the scrollable viewport if measurement is unavailable. */
    }
  }

  @override
  void didUpdateWidget(GoogleSearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) _load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Text(
        'Google Search suggestions require the mobile app',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      );
    }
    return Semantics(
      label: 'Google Search suggestions',
      child: SizedBox(
        height: _height,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
