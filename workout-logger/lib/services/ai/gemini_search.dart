import 'package:ai_orchestration/ai_orchestration.dart';
import '../../models/web_search_result.dart';

WebSearchResult? parseGeminiGrounding(String text, JsonMap grounding) {
  if (grounding.isEmpty || text.trim().isEmpty) return null;
  final entryPoint = grounding['searchEntryPoint'];
  final rawHtml = entryPoint is Map ? entryPoint['renderedContent'] : null;
  final html = rawHtml is String ? rawHtml : '';
  final sources = <WebSearchSource>[];
  final seen = <String>{};
  final chunks = grounding['groundingChunks'];
  for (final chunk in chunks is List ? chunks : const []) {
    if (chunk is! Map || chunk['web'] is! Map) continue;
    final web = chunk['web'] as Map;
    final url = web['uri'];
    if (url is! String || externalWebUri(url) == null || !seen.add(url)) {
      continue;
    }
    final title = web['title'];
    sources.add(
      WebSearchSource(
        title: title is String && title.trim().isNotEmpty
            ? title
            : Uri.parse(url).host,
        url: url,
      ),
    );
  }
  if (sources.isEmpty && html.isEmpty) return null;
  final rawQueries = grounding['webSearchQueries'];
  final queries = rawQueries is List
      ? rawQueries.whereType<String>().join(' · ')
      : '';
  return WebSearchResult(
    query: queries,
    text: text,
    sources: List.unmodifiable(sources),
    suggestionsHtml: html,
  );
}
