import 'dart:convert';

import '../bridge/frb_api.dart' as frb;
import '../providers/app_state.dart';

const String worldBookJsonFieldKey = 'worldbook_json';
const String worldBookLegacyEntriesFieldKey = 'entries_json';

class WorldBookInjection {
  const WorldBookInjection._();

  static String mergeWithLores({
    required String sessionId,
    required String userInput,
    required List<frb.MessageRecord> visibleMessages,
    required String baseLores,
    required ManagedOption? worldBook,
  }) {
    if (worldBook == null) {
      return baseLores.trim();
    }
    final entries = parseWorldBookEntries(worldBook);
    if (entries.isEmpty) {
      return baseLores.trim();
    }

    final corpus = _buildCorpus(userInput: userInput, messages: visibleMessages);
    final sorted = entries.toList(growable: true)
      ..sort((a, b) {
        final orderCmp = _asInt(b['order']).compareTo(_asInt(a['order']));
        if (orderCmp != 0) {
          return orderCmp;
        }
        return _asInt(a['uid']).compareTo(_asInt(b['uid']));
      });

    final beforeInjected = <String>[];
    final afterInjected = <String>[];
    final dedupe = <String>{};
    for (final entry in sorted) {
      if (!_shouldInject(
        entry: entry,
        corpus: corpus,
        sessionId: sessionId,
        userInput: userInput,
      )) {
        continue;
      }
      final content = '${entry['content'] ?? ''}'.trim();
      if (content.isEmpty) {
        continue;
      }
      if (dedupe.add(content)) {
        if (_asInt(entry['position']) == 0) {
          beforeInjected.add(content);
        } else {
          afterInjected.add(content);
        }
      }
    }

    if (beforeInjected.isEmpty && afterInjected.isEmpty) {
      return baseLores.trim();
    }
    final base = baseLores.trim();
    final chunks = <String>[
      if (beforeInjected.isNotEmpty) beforeInjected.join('\n\n').trim(),
      if (base.isNotEmpty) base,
      if (afterInjected.isNotEmpty) afterInjected.join('\n\n').trim(),
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);
    if (chunks.isEmpty) {
      return '';
    }
    return chunks.join('\n\n');
  }
}

List<Map<String, dynamic>> parseWorldBookEntries(ManagedOption worldBook) {
  final rawValue =
      worldBook.fieldValue(worldBookJsonFieldKey) ??
      worldBook.fieldValue(worldBookLegacyEntriesFieldKey);
  if (rawValue is! String || rawValue.trim().isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final decoded = _safeDecode(rawValue.trim());
  if (decoded is Map && decoded['entries'] is Map) {
    final entries = (decoded['entries'] as Map).values
        .whereType<Map>()
        .map((item) => _normalizeEntry(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return entries;
  }

  // Legacy UI format fallback.
  if (decoded is List) {
    return decoded
        .whereType<Map>()
        .toList(growable: false)
        .asMap()
        .entries
        .map((item) => _legacyToStEntry(Map<String, dynamic>.from(item.value), item.key))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _legacyToStEntry(Map<String, dynamic> old, int index) {
  return _normalizeEntry(<String, dynamic>{
    'uid': _intOrDefault(old['uid'], index),
    'key': _csvToList('${old['keys'] ?? ''}'),
    'keysecondary': _csvToList('${old['keys2'] ?? ''}'),
    'comment': '${old['title'] ?? old['note'] ?? ''}',
    'content': '${old['content'] ?? ''}',
    'constant': old['constant'] == true,
    'selective': true,
    'selectiveLogic': 0,
    'addMemo': true,
    'order': _intOrDefault(old['priority'], 100),
    'position': _positionFromMode('${old['mode'] ?? ''}'),
    'disable': !(old['enabled'] == true),
    'depth': _intOrDefault(old['depth'], 4),
    'group': '${old['group'] ?? ''}',
    'probability': _intOrDefault(old['probability'], 100),
    'useProbability': true,
  });
}

Map<String, dynamic> _normalizeEntry(Map<String, dynamic> source) {
  final uid = _asInt(source['uid']);
  return <String, dynamic>{
    'uid': uid,
    'key': _asStringList(source['key']),
    'keysecondary': _asStringList(source['keysecondary']),
    'comment': '${source['comment'] ?? ''}',
    'content': '${source['content'] ?? ''}',
    'constant': source['constant'] == true,
    'vectorized': source['vectorized'] == true,
    'selective': source['selective'] != false,
    'selectiveLogic': _intOrDefault(source['selectiveLogic'], 0),
    'addMemo': source['addMemo'] != false,
    'order': _intOrDefault(source['order'], 100),
    'position': _intOrDefault(source['position'], 0),
    'disable': source['disable'] == true,
    'ignoreBudget': source['ignoreBudget'] == true,
    'excludeRecursion': source['excludeRecursion'] == true,
    'preventRecursion': source['preventRecursion'] == true,
    'matchPersonaDescription': source['matchPersonaDescription'] == true,
    'matchCharacterDescription': source['matchCharacterDescription'] == true,
    'matchCharacterPersonality': source['matchCharacterPersonality'] == true,
    'matchCharacterDepthPrompt': source['matchCharacterDepthPrompt'] == true,
    'matchScenario': source['matchScenario'] == true,
    'matchCreatorNotes': source['matchCreatorNotes'] == true,
    'delayUntilRecursion': source['delayUntilRecursion'] == true,
    'probability': _intOrDefault(source['probability'], 100),
    'useProbability': source['useProbability'] != false,
    'depth': _intOrDefault(source['depth'], 4),
    'group': '${source['group'] ?? ''}',
    'groupOverride': source['groupOverride'] == true,
    'groupWeight': _intOrDefault(source['groupWeight'], 100),
    'scanDepth': _nullableInt(source['scanDepth']),
    'caseSensitive': _nullableBool(source['caseSensitive']),
    'matchWholeWords': _nullableBool(source['matchWholeWords']),
    'useGroupScoring': _nullableBool(source['useGroupScoring']),
    'automationId': '${source['automationId'] ?? ''}',
    'role': source['role'] == null ? null : '${source['role']}',
    'sticky': _asInt(source['sticky']),
    'cooldown': _asInt(source['cooldown']),
    'delay': _asInt(source['delay']),
    'triggers': _asStringList(source['triggers']),
    'displayIndex': _intOrDefault(source['displayIndex'], uid),
    'characterFilter': source['characterFilter'] is Map
        ? Map<String, dynamic>.from(source['characterFilter'] as Map)
        : <String, dynamic>{'isExclude': false, 'names': <String>[], 'tags': <String>[]},
  };
}

String _buildCorpus({
  required String userInput,
  required List<frb.MessageRecord> messages,
}) {
  final tail = messages.reversed
      .where((m) => m.visible && m.content.trim().isNotEmpty)
      .take(12)
      .map((m) => m.content.trim())
      .toList(growable: false)
      .reversed;
  final pieces = <String>[userInput.trim(), ...tail];
  return pieces.where((part) => part.isNotEmpty).join('\n').trim();
}

bool _shouldInject({
  required Map<String, dynamic> entry,
  required String corpus,
  required String sessionId,
  required String userInput,
}) {
  if (entry['disable'] == true) {
    return false;
  }
  if (entry['constant'] == true) {
    return true;
  }

  final keyMatched = _matchAny(
    corpus: corpus,
    tokens: _asStringList(entry['key']),
    caseSensitive: _nullableBool(entry['caseSensitive']) ?? false,
    wholeWords: _nullableBool(entry['matchWholeWords']) ?? false,
  );
  final secondaryMatched = _matchAny(
    corpus: corpus,
    tokens: _asStringList(entry['keysecondary']),
    caseSensitive: _nullableBool(entry['caseSensitive']) ?? false,
    wholeWords: _nullableBool(entry['matchWholeWords']) ?? false,
  );
  final hasSecondary = _asStringList(entry['keysecondary']).isNotEmpty;
  final triggerMatched = _matchAny(
    corpus: corpus,
    tokens: _asStringList(entry['triggers']),
    caseSensitive: _nullableBool(entry['caseSensitive']) ?? false,
    wholeWords: _nullableBool(entry['matchWholeWords']) ?? false,
  );
  final selective = entry['selective'] != false;
  final selectiveLogic = _asInt(entry['selectiveLogic']);

  bool matched;
  if (!selective) {
    matched = keyMatched || secondaryMatched || triggerMatched;
  } else if (!hasSecondary) {
    matched = keyMatched || triggerMatched;
  } else if (selectiveLogic == 0) {
    matched = (keyMatched && secondaryMatched) || triggerMatched;
  } else {
    matched = keyMatched || secondaryMatched || triggerMatched;
  }
  if (!matched) {
    return false;
  }

  final useProbability = entry['useProbability'] != false;
  final probability = _asInt(entry['probability']).clamp(0, 100);
  if (!useProbability || probability >= 100) {
    return true;
  }
  final seed = '$sessionId|${entry['uid']}|$userInput';
  final bucket = seed.hashCode.abs() % 100;
  return bucket < probability;
}

bool _matchAny({
  required String corpus,
  required List<String> tokens,
  required bool caseSensitive,
  required bool wholeWords,
}) {
  if (tokens.isEmpty || corpus.isEmpty) {
    return false;
  }
  final haystack = caseSensitive ? corpus : corpus.toLowerCase();
  for (final raw in tokens) {
    final token = raw.trim();
    if (token.isEmpty) {
      continue;
    }
    final needle = caseSensitive ? token : token.toLowerCase();
    if (!wholeWords) {
      if (haystack.contains(needle)) {
        return true;
      }
      continue;
    }
    final escaped = RegExp.escape(needle);
    final regex = RegExp('(^|[^\\w])$escaped([^\\w]|\$)');
    if (regex.hasMatch(haystack)) {
      return true;
    }
  }
  return false;
}

Object? _safeDecode(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

int _positionFromMode(String mode) {
  if (mode == 'before') {
    return 0;
  }
  return 1;
}

int _asInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse('$raw'.trim()) ?? 0;
}

int _intOrDefault(Object? raw, int fallback) {
  if (raw == null) {
    return fallback;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  final parsed = int.tryParse('$raw'.trim());
  return parsed ?? fallback;
}

int? _nullableInt(Object? raw) {
  if (raw == null) {
    return null;
  }
  return _asInt(raw);
}

bool? _nullableBool(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is bool) {
    return raw;
  }
  final normalized = '$raw'.trim().toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return null;
}

List<String> _asStringList(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

List<String> _csvToList(String raw) {
  return raw
      .split(RegExp(r'[,，\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
