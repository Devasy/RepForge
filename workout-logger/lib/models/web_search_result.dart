Uri? externalWebUri(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

class WebSearchSource {
  const WebSearchSource({required this.title, required this.url});
  final String title;
  final String url;
  Map<String, dynamic> toJson() => {'title': title, 'url': url};
  factory WebSearchSource.fromJson(Map<String, dynamic> json) =>
      WebSearchSource(
        title: json['title'] as String,
        url: json['url'] as String,
      );
}

class WebSearchResult {
  const WebSearchResult({
    required this.query,
    required this.text,
    required this.sources,
    required this.suggestionsHtml,
  });
  final String query;
  final String text;
  final List<WebSearchSource> sources;
  final String suggestionsHtml;

  Map<String, dynamic> toJson() => {
    'query': query,
    'text': text,
    'sources': sources.map((source) => source.toJson()).toList(),
    'suggestionsHtml': suggestionsHtml,
  };

  factory WebSearchResult.fromJson(Map<String, dynamic> json) =>
      WebSearchResult(
        query: json['query'] as String,
        text: json['text'] as String,
        sources: (json['sources'] as List)
            .map(
              (source) => WebSearchSource.fromJson(
                Map<String, dynamic>.from(source as Map),
              ),
            )
            .toList(),
        suggestionsHtml: json['suggestionsHtml'] as String,
      );
}
