import 'dart:convert';

import '../bridge/frb_api.dart' as frb;
import '../providers/app_state.dart';

const String worldBookJsonFieldKey = 'worldbook_json';
const String worldBookLegacyEntriesFieldKey = 'entries_json';
const String worldBookCategoryFieldKey = 'worldbook_ui_categories';
const String worldBookScanDepthFieldKey = 'worldbook_scan_depth';

int loadWorldBookScanDepth(ManagedOption worldBook) {
  final raw = worldBook.fieldValue(worldBookScanDepthFieldKey);
  if (raw is String && raw.trim().isNotEmpty) {
    final value = int.tryParse(raw.trim());
    if (value != null && value >= 0) {
      return value;
    }
  }
  return 4;
}

class StLoreInjectionResult {
  const StLoreInjectionResult({
    required this.before,
    required this.after,
    this.activatedEntryUids = const <int>[],
  });

  final String before;
  final String after;
  final List<int> activatedEntryUids;
}

class WorldBookInjection {
  const WorldBookInjection._();

  static final Map<String, Map<int, _EntryTimedState>> _timedStatesBySession =
      <String, Map<int, _EntryTimedState>>{};

  static String mergeWithLores({
    required String sessionId,
    required String userInput,
    required List<frb.MessageRecord> visibleMessages,
    required String baseLores,
    required ManagedOption? worldBook,
  }) {
    final result = buildStModeLore(
      sessionId: sessionId,
      userInput: userInput,
      visibleMessages: visibleMessages,
      baseLores: baseLores,
      userDescription: '',
      scene: '',
      worldBook: worldBook,
    );
    return <String>[
      result.before.trim(),
      result.after.trim(),
    ].where((item) => item.isNotEmpty).join('\n\n');
  }

  static StLoreInjectionResult buildStModeLore({
    required String sessionId,
    required String userInput,
    required List<frb.MessageRecord> visibleMessages,
    required String baseLores,
    required String userDescription,
    required String scene,
    required ManagedOption? worldBook,
    String trigger = 'chat',
    int defaultScanDepth = 4,
  }) {
    final base = baseLores.trim();
    if (worldBook == null) {
      return StLoreInjectionResult(before: base, after: '');
    }

    final entries = parseWorldBookEntries(worldBook);
    if (entries.isEmpty) {
      return StLoreInjectionResult(before: base, after: '');
    }

    final scanInput = _ScanInput(
      userInput: userInput,
      visibleMessages: visibleMessages,
      personaDescription: userDescription,
      characterDescription: baseLores,
      scenario: scene,
      trigger: trigger,
      defaultScanDepth: defaultScanDepth,
    );

    final sorted = entries.toList(growable: false)
      ..sort((a, b) {
        final orderCmp = _asInt(b['order']).compareTo(_asInt(a['order']));
        if (orderCmp != 0) {
          return orderCmp;
        }
        return _asInt(a['uid']).compareTo(_asInt(b['uid']));
      });

    final roundSeed =
        '${sessionId.trim()}|${userInput.trim()}|${visibleMessages.length}|${scanInput.trigger}';

    final candidates = <_ActivatedEntry>[];
    final messageCount = visibleMessages.where((item) => item.visible).length;

    for (final entry in sorted) {
      if (entry['disable'] == true) {
        continue;
      }
      if (!_passesTriggerGate(entry: entry, trigger: scanInput.trigger)) {
        continue;
      }
      if (!_passesCharacterFilter(entry)) {
        continue;
      }

      final uid = _asInt(entry['uid']);
      final timedState = _timedState(sessionId, uid);
      final stickyActive = _isStickyActive(timedState, messageCount);

      if (_isDelayActive(entry: entry, messageCount: messageCount)) {
        continue;
      }
      if (!stickyActive && _isCooldownActive(timedState, messageCount)) {
        continue;
      }

      final decorated = _parseDecoratedContent('${entry['content'] ?? ''}');
      if (decorated.forceDisabled) {
        continue;
      }
      final content = decorated.content.trim();
      if (content.isEmpty) {
        continue;
      }

      final corpus = _buildEntryCorpus(entry: entry, scanInput: scanInput);
      final score = _estimateEntryScore(entry: entry, corpus: corpus);

      final shouldActivateByShortcut =
          decorated.forceEnabled || entry['constant'] == true || stickyActive;
      final matched =
          shouldActivateByShortcut ||
          _matchesEntryKeywords(entry: entry, corpus: corpus);
      if (!matched) {
        continue;
      }

      candidates.add(
        _ActivatedEntry(
          entry: entry,
          uid: uid,
          order: _asInt(entry['order']),
          position: _asInt(entry['position']),
          content: content,
          score: score,
          stickyActive: stickyActive,
        ),
      );
    }

    final grouped = _applyGroupCompetition(
      candidates: candidates,
      roundSeed: roundSeed,
    );

    final activated = <_ActivatedEntry>[];
    for (final item in grouped) {
      final passedProbability = _passesProbability(
        entry: item.entry,
        stickyActive: item.stickyActive,
        seed: '$roundSeed|prob|${item.uid}',
      );
      if (!passedProbability) {
        continue;
      }
      activated.add(item);
      _markEntryActivated(
        sessionId: sessionId,
        entry: item.entry,
        messageCount: messageCount,
      );
    }

    final beforeBlocks = <String>[];
    final afterBlocks = <String>[];
    final beforeSet = <String>{};
    final afterSet = <String>{};

    for (final item in activated) {
      if (item.position <= 0) {
        if (beforeSet.add(item.content)) {
          beforeBlocks.add(item.content);
        }
      } else {
        if (afterSet.add(item.content)) {
          afterBlocks.add(item.content);
        }
      }
    }

    final mergedBefore = <String>[
      beforeBlocks.join('\n\n').trim(),
      base,
    ].where((item) => item.isNotEmpty).join('\n\n');

    return StLoreInjectionResult(
      before: mergedBefore,
      after: afterBlocks.join('\n\n').trim(),
      activatedEntryUids: activated
          .map((item) => item.uid)
          .toList(growable: false),
    );
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
    final sourceEntries = decoded['entries'] as Map;
    final parsed = <Map<String, dynamic>>[];
    var fallbackIndex = 0;
    for (final item in sourceEntries.entries) {
      final rawEntry = item.value;
      if (rawEntry is! Map) {
        continue;
      }
      parsed.add(
        _normalizeEntry(
          Map<String, dynamic>.from(rawEntry),
          fallbackUid: _fallbackUidFromMapKey(
            mapKey: item.key,
            fallbackIndex: fallbackIndex,
          ),
        ),
      );
      fallbackIndex += 1;
    }
    return _ensureUniqueUids(parsed);
  }

  // Legacy UI format fallback.
  if (decoded is List) {
    final parsed = decoded
        .whereType<Map>()
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (item) =>
              _legacyToStEntry(Map<String, dynamic>.from(item.value), item.key),
        )
        .toList(growable: false);
    return _ensureUniqueUids(parsed);
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

Map<String, dynamic> _normalizeEntry(
  Map<String, dynamic> source, {
  int? fallbackUid,
}) {
  final uid = _intOrDefault(source['uid'], fallbackUid ?? 0);
  final normalized = <String, dynamic>{
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
        : <String, dynamic>{
            'isExclude': false,
            'names': <String>[],
            'tags': <String>[],
          },
  };
  for (final entry in source.entries) {
    if (!normalized.containsKey(entry.key)) {
      normalized[entry.key] = entry.value;
    }
  }
  return normalized;
}

int _fallbackUidFromMapKey({
  required Object? mapKey,
  required int fallbackIndex,
}) {
  if (mapKey is int) {
    return mapKey;
  }
  final parsed = int.tryParse('$mapKey'.trim());
  return parsed ?? fallbackIndex;
}

List<Map<String, dynamic>> _ensureUniqueUids(
  List<Map<String, dynamic>> entries,
) {
  if (entries.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  final used = <int>{};
  var maxUid = -1;
  for (final entry in entries) {
    final uid = _asInt(entry['uid']);
    if (uid > maxUid) {
      maxUid = uid;
    }
  }

  final normalized = <Map<String, dynamic>>[];
  for (final entry in entries) {
    final next = Map<String, dynamic>.from(entry);
    var uid = _asInt(next['uid']);
    if (uid < 0) {
      uid = 0;
    }
    if (used.contains(uid)) {
      maxUid += 1;
      uid = maxUid;
    }
    if (uid > maxUid) {
      maxUid = uid;
    }
    used.add(uid);
    next['uid'] = uid;
    next['displayIndex'] = _intOrDefault(next['displayIndex'], uid);
    normalized.add(next);
  }
  return normalized;
}

List<_ActivatedEntry> _applyGroupCompetition({
  required List<_ActivatedEntry> candidates,
  required String roundSeed,
}) {
  if (candidates.isEmpty) {
    return const <_ActivatedEntry>[];
  }

  final ungrouped = <_ActivatedEntry>[];
  final grouped = <String, List<_ActivatedEntry>>{};

  for (final candidate in candidates) {
    final groups = _parseGroups(candidate.entry);
    if (groups.isEmpty) {
      ungrouped.add(candidate);
      continue;
    }
    for (final group in groups) {
      grouped.putIfAbsent(group, () => <_ActivatedEntry>[]).add(candidate);
    }
  }

  final winnerByUid = <int, _ActivatedEntry>{
    for (final item in ungrouped) item.uid: item,
  };

  final sortedGroupKeys = grouped.keys.toList(growable: false)..sort();
  for (final groupKey in sortedGroupKeys) {
    var groupCandidates = grouped[groupKey] ?? const <_ActivatedEntry>[];
    if (groupCandidates.isEmpty) {
      continue;
    }

    final stickyCandidates = groupCandidates
        .where((item) => item.stickyActive)
        .toList(growable: false);
    if (stickyCandidates.isNotEmpty) {
      groupCandidates = stickyCandidates;
    }

    final useScore = groupCandidates.any(
      (item) => _nullableBool(item.entry['useGroupScoring']) == true,
    );
    if (useScore) {
      var maxScore = groupCandidates.first.score;
      for (final item in groupCandidates) {
        if (item.score > maxScore) {
          maxScore = item.score;
        }
      }
      groupCandidates = groupCandidates
          .where((item) => item.score == maxScore)
          .toList(growable: false);
    }

    final overrides = groupCandidates
        .where((item) => item.entry['groupOverride'] == true)
        .toList(growable: false);
    if (overrides.isNotEmpty) {
      final selected = _selectHighestOrder(overrides);
      winnerByUid[selected.uid] = selected;
      continue;
    }

    final selected = _selectByWeight(
      groupCandidates,
      '$roundSeed|group|$groupKey',
    );
    winnerByUid[selected.uid] = selected;
  }

  final ordered = candidates
      .where((item) => winnerByUid.containsKey(item.uid))
      .toList(growable: false);
  return ordered;
}

_ActivatedEntry _selectHighestOrder(List<_ActivatedEntry> entries) {
  var best = entries.first;
  for (final item in entries.skip(1)) {
    if (item.order > best.order) {
      best = item;
      continue;
    }
    if (item.order == best.order && item.uid < best.uid) {
      best = item;
    }
  }
  return best;
}

_ActivatedEntry _selectByWeight(List<_ActivatedEntry> entries, String seed) {
  if (entries.length == 1) {
    return entries.first;
  }

  var total = 0;
  for (final item in entries) {
    total += _positiveWeight(item.entry['groupWeight']);
  }
  if (total <= 0) {
    return entries.first;
  }

  final bucket = _stableHash(seed) % total;
  var cursor = 0;
  for (final item in entries) {
    cursor += _positiveWeight(item.entry['groupWeight']);
    if (bucket < cursor) {
      return item;
    }
  }
  return entries.last;
}

int _positiveWeight(Object? raw) {
  final value = _asInt(raw);
  return value <= 0 ? 1 : value;
}

bool _passesProbability({
  required Map<String, dynamic> entry,
  required bool stickyActive,
  required String seed,
}) {
  if (stickyActive) {
    return true;
  }

  final useProbability = entry['useProbability'] != false;
  final probability = _asInt(entry['probability']).clamp(0, 100);
  if (!useProbability || probability >= 100) {
    return true;
  }

  final bucket = _stableHash(seed) % 100;
  return bucket < probability;
}

bool _matchesEntryKeywords({
  required Map<String, dynamic> entry,
  required String corpus,
}) {
  final primaryKeys = _asStringList(entry['key']);
  if (primaryKeys.isEmpty) {
    return false;
  }

  final caseSensitive = _nullableBool(entry['caseSensitive']) ?? false;
  final wholeWords = _nullableBool(entry['matchWholeWords']) ?? false;

  final primaryMatched = _matchAny(
    corpus: corpus,
    tokens: primaryKeys,
    caseSensitive: caseSensitive,
    wholeWords: wholeWords,
  );
  if (!primaryMatched) {
    return false;
  }

  final secondaryKeys = _asStringList(entry['keysecondary']);
  final selective = entry['selective'] != false;
  if (!selective || secondaryKeys.isEmpty) {
    return true;
  }

  final secondaryMatches = secondaryKeys
      .map(
        (token) => _matchToken(
          corpus: corpus,
          token: token,
          caseSensitive: caseSensitive,
          wholeWords: wholeWords,
        ),
      )
      .toList(growable: false);

  final selectiveLogic = _asInt(entry['selectiveLogic']);
  switch (selectiveLogic) {
    case 1: // NOT_ALL
      return secondaryMatches.any((value) => !value);
    case 2: // NOT_ANY
      return secondaryMatches.every((value) => !value);
    case 3: // AND_ALL
      return secondaryMatches.every((value) => value);
    case 0: // AND_ANY
    default:
      return secondaryMatches.any((value) => value);
  }
}

bool _passesTriggerGate({
  required Map<String, dynamic> entry,
  required String trigger,
}) {
  final triggers = _asStringList(entry['triggers'])
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet();
  if (triggers.isEmpty) {
    return true;
  }

  final normalized = trigger.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  return triggers.contains('*') ||
      triggers.contains(normalized) ||
      (normalized == 'chat' && triggers.contains('normal'));
}

bool _passesCharacterFilter(Map<String, dynamic> entry) {
  final raw = entry['characterFilter'];
  if (raw is! Map) {
    return true;
  }
  final map = Map<String, dynamic>.from(raw);
  final names = _asStringList(map['names']);
  final tags = _asStringList(map['tags']);
  if (names.isEmpty && tags.isEmpty) {
    return true;
  }

  // MVP 当前没有角色名/标签运行态，保持宽松以避免误过滤。
  return true;
}

bool _isDelayActive({
  required Map<String, dynamic> entry,
  required int messageCount,
}) {
  final delay = _asInt(entry['delay']);
  if (delay <= 0) {
    return false;
  }
  return messageCount < delay;
}

bool _isCooldownActive(_EntryTimedState? state, int messageCount) {
  if (state == null) {
    return false;
  }
  return messageCount < state.cooldownUntilMessageCount;
}

bool _isStickyActive(_EntryTimedState? state, int messageCount) {
  if (state == null) {
    return false;
  }
  return messageCount < state.stickyUntilMessageCount;
}

_EntryTimedState? _timedState(String sessionId, int uid) {
  final sessionStates = WorldBookInjection._timedStatesBySession[sessionId];
  if (sessionStates == null) {
    return null;
  }
  return sessionStates[uid];
}

void _markEntryActivated({
  required String sessionId,
  required Map<String, dynamic> entry,
  required int messageCount,
}) {
  final uid = _asInt(entry['uid']);
  final sessionStates = WorldBookInjection._timedStatesBySession.putIfAbsent(
    sessionId,
    () => <int, _EntryTimedState>{},
  );
  final state = sessionStates.putIfAbsent(uid, _EntryTimedState.new);

  final sticky = _asInt(entry['sticky']);
  final cooldown = _asInt(entry['cooldown']);

  state.lastActivatedMessageCount = messageCount;
  state.stickyUntilMessageCount = sticky > 0
      ? messageCount + sticky
      : messageCount;
  if (cooldown > 0) {
    final cooldownBase = sticky > 0
        ? state.stickyUntilMessageCount
        : messageCount;
    state.cooldownUntilMessageCount = cooldownBase + cooldown;
  } else {
    state.cooldownUntilMessageCount = messageCount;
  }
}

String _buildEntryCorpus({
  required Map<String, dynamic> entry,
  required _ScanInput scanInput,
}) {
  final scanDepthRaw = _nullableInt(entry['scanDepth']);
  final scanDepth = (scanDepthRaw ?? scanInput.defaultScanDepth)
      .clamp(0, 2048)
      .toInt();

  final historySlice = scanInput.visibleMessages
      .where((item) => item.visible && item.content.trim().isNotEmpty)
      .toList(growable: false)
      .reversed
      .take(scanDepth)
      .map((item) => '${_roleLabel(item.role)}: ${item.content.trim()}')
      .toList(growable: false);

  final parts = <String>[scanInput.userInput.trim(), ...historySlice];

  if (entry['matchPersonaDescription'] == true) {
    parts.add(scanInput.personaDescription.trim());
  }
  if (entry['matchCharacterDescription'] == true) {
    parts.add(scanInput.characterDescription.trim());
  }
  if (entry['matchScenario'] == true) {
    parts.add(scanInput.scenario.trim());
  }

  return parts.where((item) => item.isNotEmpty).join('\n');
}

String _roleLabel(frb.MessageRole role) {
  return switch (role) {
    frb.MessageRole.system => 'system',
    frb.MessageRole.user => 'user',
    frb.MessageRole.assistant => 'assistant',
  };
}

int _estimateEntryScore({
  required Map<String, dynamic> entry,
  required String corpus,
}) {
  final caseSensitive = _nullableBool(entry['caseSensitive']) ?? false;
  final wholeWords = _nullableBool(entry['matchWholeWords']) ?? false;

  var score = 0;
  for (final token in _asStringList(entry['key'])) {
    if (_matchToken(
      corpus: corpus,
      token: token,
      caseSensitive: caseSensitive,
      wholeWords: wholeWords,
    )) {
      score += 2;
    }
  }
  for (final token in _asStringList(entry['keysecondary'])) {
    if (_matchToken(
      corpus: corpus,
      token: token,
      caseSensitive: caseSensitive,
      wholeWords: wholeWords,
    )) {
      score += 1;
    }
  }
  return score;
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
  for (final token in tokens) {
    if (_matchToken(
      corpus: corpus,
      token: token,
      caseSensitive: caseSensitive,
      wholeWords: wholeWords,
    )) {
      return true;
    }
  }
  return false;
}

bool _matchToken({
  required String corpus,
  required String token,
  required bool caseSensitive,
  required bool wholeWords,
}) {
  final normalizedToken = token.trim();
  if (normalizedToken.isEmpty || corpus.isEmpty) {
    return false;
  }

  final regexToken = _parseRegexToken(normalizedToken);
  if (regexToken != null) {
    return regexToken.hasMatch(corpus, caseSensitive);
  }

  final haystack = caseSensitive ? corpus : corpus.toLowerCase();
  final needle = caseSensitive
      ? normalizedToken
      : normalizedToken.toLowerCase();

  if (!wholeWords) {
    return haystack.contains(needle);
  }

  if (needle.contains(RegExp(r'\s'))) {
    return haystack.contains(needle);
  }

  final escaped = RegExp.escape(needle);
  final regex = RegExp('(^|[^\\w])$escaped([^\\w]|\\\$)');
  return regex.hasMatch(haystack);
}

_RegexToken? _parseRegexToken(String raw) {
  if (!raw.startsWith('/') || raw.length < 2) {
    return null;
  }

  var closingSlash = -1;
  for (var index = raw.length - 1; index > 0; index -= 1) {
    if (raw[index] == '/' && raw[index - 1] != '\\') {
      closingSlash = index;
      break;
    }
  }
  if (closingSlash <= 0) {
    return null;
  }

  final pattern = raw.substring(1, closingSlash);
  final flags = raw.substring(closingSlash + 1);
  final normalizedFlags = flags.trim();
  if (pattern.isEmpty) {
    return null;
  }

  return _RegexToken(pattern: pattern, flags: normalizedFlags);
}

_DecoratedContent _parseDecoratedContent(String raw) {
  if (raw.trim().isEmpty) {
    return const _DecoratedContent(content: '');
  }

  var forceEnabled = false;
  var forceDisabled = false;
  final keptLines = <String>[];

  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == '@@activate') {
      forceEnabled = true;
      continue;
    }
    if (trimmed == '@@dont_activate') {
      forceDisabled = true;
      continue;
    }
    keptLines.add(line);
  }

  return _DecoratedContent(
    content: keptLines.join('\n'),
    forceEnabled: forceEnabled,
    forceDisabled: forceDisabled,
  );
}

List<String> _parseGroups(Map<String, dynamic> entry) {
  return '${entry['group'] ?? ''}'
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _positionFromMode(String mode) {
  if (mode == 'before') {
    return 0;
  }
  return 1;
}

int _stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

Object? _safeDecode(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
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

class _ScanInput {
  const _ScanInput({
    required this.userInput,
    required this.visibleMessages,
    required this.personaDescription,
    required this.characterDescription,
    required this.scenario,
    required this.trigger,
    required this.defaultScanDepth,
  });

  final String userInput;
  final List<frb.MessageRecord> visibleMessages;
  final String personaDescription;
  final String characterDescription;
  final String scenario;
  final String trigger;
  final int defaultScanDepth;
}

class _ActivatedEntry {
  const _ActivatedEntry({
    required this.entry,
    required this.uid,
    required this.order,
    required this.position,
    required this.content,
    required this.score,
    required this.stickyActive,
  });

  final Map<String, dynamic> entry;
  final int uid;
  final int order;
  final int position;
  final String content;
  final int score;
  final bool stickyActive;
}

class _DecoratedContent {
  const _DecoratedContent({
    required this.content,
    this.forceEnabled = false,
    this.forceDisabled = false,
  });

  final String content;
  final bool forceEnabled;
  final bool forceDisabled;
}

class _RegexToken {
  const _RegexToken({required this.pattern, required this.flags});

  final String pattern;
  final String flags;

  bool hasMatch(String source, bool fallbackCaseSensitive) {
    final normalizedFlags = flags.toLowerCase();
    final caseSensitive = normalizedFlags.contains('i')
        ? false
        : fallbackCaseSensitive;
    final multiLine = normalizedFlags.contains('m');
    final dotAll = normalizedFlags.contains('s');
    final unicode = normalizedFlags.contains('u');

    try {
      final regex = RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiLine,
        dotAll: dotAll,
        unicode: unicode,
      );
      return regex.hasMatch(source);
    } catch (_) {
      return false;
    }
  }
}

class _EntryTimedState {
  int stickyUntilMessageCount = 0;
  int cooldownUntilMessageCount = 0;
  int lastActivatedMessageCount = 0;
}
