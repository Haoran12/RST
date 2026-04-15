class ParsedReasoningMarkup {
  const ParsedReasoningMarkup({required this.content, required this.reasoning});

  final String content;
  final String reasoning;

  bool get hasReasoning => reasoning.trim().isNotEmpty;
}

class ReasoningMarkup {
  static final RegExp _reasoningBlockPattern = RegExp(
    r'<reasoning>([\s\S]*?)<\/reasoning>',
    caseSensitive: false,
  );

  static ParsedReasoningMarkup parse(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    final contentBuffer = StringBuffer();
    final reasoningSegments = <String>[];

    var cursor = 0;
    for (final match in _reasoningBlockPattern.allMatches(normalized)) {
      if (match.start > cursor) {
        contentBuffer.write(normalized.substring(cursor, match.start));
      }
      final reasoning = (match.group(1) ?? '').trim();
      if (reasoning.isNotEmpty) {
        reasoningSegments.add(reasoning);
      }
      cursor = match.end;
    }
    if (cursor < normalized.length) {
      contentBuffer.write(normalized.substring(cursor));
    }

    return ParsedReasoningMarkup(
      content: _normalizePlainText(contentBuffer.toString()),
      reasoning: _normalizeReasoningText(reasoningSegments.join('\n\n')),
    );
  }

  static String stripReasoning(String raw) => parse(raw).content;

  static String compose({required String content, required String reasoning}) {
    final normalizedContent = _normalizePlainText(content);
    final normalizedReasoning = _normalizeReasoningText(reasoning);
    if (normalizedReasoning.isEmpty) {
      return normalizedContent;
    }
    if (normalizedContent.isEmpty) {
      return '<reasoning>\n$normalizedReasoning\n</reasoning>';
    }
    return '$normalizedContent\n\n<reasoning>\n$normalizedReasoning\n</reasoning>';
  }

  static String _normalizePlainText(String value) {
    final normalized = value.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static String _normalizeReasoningText(String value) {
    final normalized = value.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return '';
    }
    final compactLines = normalized
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n');
    return compactLines.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
}
