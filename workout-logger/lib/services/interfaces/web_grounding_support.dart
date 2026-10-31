bool supportsGeminiWebGrounding(String model) {
  final match = RegExp(
    r'^gemini-(\d+)\.\d+-flash(?:-lite)?$',
  ).firstMatch(model);
  return match != null && int.parse(match.group(1)!) >= 3;
}

abstract interface class WebGroundingSupport {
  bool get supportsWebGrounding;
}
