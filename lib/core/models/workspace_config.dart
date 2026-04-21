import 'common.dart';

class StoredApiConfig {
  const StoredApiConfig({
    required this.apiId,
    required this.name,
    required this.providerType,
    required this.baseUrl,
    required this.requestPath,
    required this.apiKeyCiphertext,
    this.apiKeyHint,
    required this.defaultModel,
    this.customHeaders = const <String, String>{},
    this.requestTimeoutMs,
    this.stream,
    this.temperature,
    this.topP,
    this.topK,
    this.presencePenalty,
    this.frequencyPenalty,
    this.maxCompletionTokens,
    this.stopSequences = const <String>[],
    this.reasoningEffort,
    this.verbosity,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  final String apiId;
  final String name;
  final ProviderType providerType;
  final String baseUrl;
  final String requestPath;
  final String apiKeyCiphertext;
  final String? apiKeyHint;
  final String defaultModel;
  final Map<String, String> customHeaders;
  final int? requestTimeoutMs;
  final bool? stream;
  final double? temperature;
  final double? topP;
  final int? topK;
  final double? presencePenalty;
  final double? frequencyPenalty;
  final int? maxCompletionTokens;
  final List<String> stopSequences;
  final String? reasoningEffort;
  final String? verbosity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  StoredApiConfig copyWith({
    String? apiId,
    String? name,
    ProviderType? providerType,
    String? baseUrl,
    String? requestPath,
    String? apiKeyCiphertext,
    String? apiKeyHint,
    bool clearApiKeyHint = false,
    String? defaultModel,
    Map<String, String>? customHeaders,
    int? requestTimeoutMs,
    bool clearRequestTimeoutMs = false,
    bool? stream,
    bool clearStream = false,
    double? temperature,
    bool clearTemperature = false,
    double? topP,
    bool clearTopP = false,
    int? topK,
    bool clearTopK = false,
    double? presencePenalty,
    bool clearPresencePenalty = false,
    double? frequencyPenalty,
    bool clearFrequencyPenalty = false,
    int? maxCompletionTokens,
    bool clearMaxCompletionTokens = false,
    List<String>? stopSequences,
    String? reasoningEffort,
    bool clearReasoningEffort = false,
    String? verbosity,
    bool clearVerbosity = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return StoredApiConfig(
      apiId: apiId ?? this.apiId,
      name: name ?? this.name,
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      requestPath: requestPath ?? this.requestPath,
      apiKeyCiphertext: apiKeyCiphertext ?? this.apiKeyCiphertext,
      apiKeyHint: clearApiKeyHint ? null : (apiKeyHint ?? this.apiKeyHint),
      defaultModel: defaultModel ?? this.defaultModel,
      customHeaders: customHeaders ?? this.customHeaders,
      requestTimeoutMs: clearRequestTimeoutMs
          ? null
          : (requestTimeoutMs ?? this.requestTimeoutMs),
      stream: clearStream ? null : (stream ?? this.stream),
      temperature: clearTemperature ? null : (temperature ?? this.temperature),
      topP: clearTopP ? null : (topP ?? this.topP),
      topK: clearTopK ? null : (topK ?? this.topK),
      presencePenalty: clearPresencePenalty
          ? null
          : (presencePenalty ?? this.presencePenalty),
      frequencyPenalty: clearFrequencyPenalty
          ? null
          : (frequencyPenalty ?? this.frequencyPenalty),
      maxCompletionTokens: clearMaxCompletionTokens
          ? null
          : (maxCompletionTokens ?? this.maxCompletionTokens),
      stopSequences: stopSequences ?? this.stopSequences,
      reasoningEffort: clearReasoningEffort
          ? null
          : (reasoningEffort ?? this.reasoningEffort),
      verbosity: clearVerbosity ? null : (verbosity ?? this.verbosity),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'apiId': apiId,
      'name': name,
      'providerType': providerType.wireValue,
      'baseUrl': baseUrl,
      'requestPath': requestPath,
      'apiKeyCiphertext': apiKeyCiphertext,
      'apiKeyHint': apiKeyHint,
      'defaultModel': defaultModel,
      'customHeaders': customHeaders,
      'requestTimeoutMs': requestTimeoutMs,
      'stream': stream,
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'presencePenalty': presencePenalty,
      'frequencyPenalty': frequencyPenalty,
      'maxCompletionTokens': maxCompletionTokens,
      'stopSequences': stopSequences,
      'reasoningEffort': reasoningEffort,
      'verbosity': verbosity,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'version': version,
    };
  }

  factory StoredApiConfig.fromJson(Map<String, dynamic> json) {
    return StoredApiConfig(
      apiId: '${json['apiId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      providerType: providerTypeFromWire(json['providerType']),
      baseUrl: '${json['baseUrl'] ?? ''}',
      requestPath: '${json['requestPath'] ?? ''}',
      apiKeyCiphertext: '${json['apiKeyCiphertext'] ?? ''}',
      apiKeyHint: _normalizeOptional(json['apiKeyHint']),
      defaultModel: '${json['defaultModel'] ?? ''}',
      customHeaders: _parseHeaders(json['customHeaders']),
      requestTimeoutMs: _parseInt(json['requestTimeoutMs']),
      stream: _parseBool(json['stream']),
      temperature: _parseDouble(json['temperature']),
      topP: _parseDouble(json['topP']),
      topK: _parseInt(json['topK']),
      presencePenalty: _parseDouble(json['presencePenalty']),
      frequencyPenalty: _parseDouble(json['frequencyPenalty']),
      maxCompletionTokens: _parseInt(json['maxCompletionTokens']),
      stopSequences: _parseStringList(json['stopSequences']),
      reasoningEffort: _normalizeOptional(json['reasoningEffort']),
      verbosity: _normalizeOptional(json['verbosity']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      version: _parseInt(json['version']) ?? 1,
    );
  }
}

enum StoredPresetEntryRole {
  system('system', 'System'),
  user('user', 'User'),
  assistant('assistant', 'Assistant');

  const StoredPresetEntryRole(this.wireValue, this.displayLabel);

  final String wireValue;
  final String displayLabel;
}

StoredPresetEntryRole storedPresetEntryRoleFromWire(Object? raw) {
  final normalized = '$raw'.trim().toLowerCase();
  for (final value in StoredPresetEntryRole.values) {
    if (value.wireValue == normalized) {
      return value;
    }
  }
  return StoredPresetEntryRole.system;
}

class PresetBuiltinEntryKeys {
  const PresetBuiltinEntryKeys._();

  static const String mainPrompt = 'main_prompt';
  static const String loreBefore = 'lore_before';
  static const String loreAfter = 'lore_after';
  static const String userDescription = 'user_description';
  static const String chatHistory = 'chat_history';
  static const String scene = 'scene';
  static const String interactiveInput = 'interactive_input';

  static const List<String> ordered = <String>[
    mainPrompt,
    loreBefore,
    userDescription,
    chatHistory,
    loreAfter,
    scene,
    interactiveInput,
  ];

  static String defaultTitleOf(String builtinKey) {
    return switch (builtinKey) {
      mainPrompt => 'Main Prompt',
      loreBefore => 'Lore Before',
      loreAfter => 'Lore After',
      userDescription => 'User Description',
      chatHistory => 'Chat History',
      scene => 'Scene',
      interactiveInput => 'Interactive Input',
      _ => builtinKey,
    };
  }
}

class StoredPresetEntry {
  const StoredPresetEntry({
    required this.entryId,
    required this.title,
    required this.role,
    required this.content,
    this.enabled = true,
    this.builtinKey,
  });

  final String entryId;
  final String title;
  final StoredPresetEntryRole role;
  final String content;
  final bool enabled;
  final String? builtinKey;

  bool get isBuiltin => builtinKey != null;

  StoredPresetEntry copyWith({
    String? entryId,
    String? title,
    StoredPresetEntryRole? role,
    String? content,
    bool? enabled,
    String? builtinKey,
    bool clearBuiltinKey = false,
  }) {
    return StoredPresetEntry(
      entryId: entryId ?? this.entryId,
      title: title ?? this.title,
      role: role ?? this.role,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      builtinKey: clearBuiltinKey ? null : (builtinKey ?? this.builtinKey),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entryId': entryId,
      'title': title,
      'role': role.wireValue,
      'content': content,
      'enabled': enabled,
      'builtinKey': builtinKey,
    };
  }

  factory StoredPresetEntry.fromJson(
    Map<String, dynamic> json, {
    int index = 0,
  }) {
    final rawBuiltin = _normalizeOptional(json['builtinKey'] ?? json['name']);
    final builtinKey =
        rawBuiltin != null &&
            PresetBuiltinEntryKeys.ordered.contains(rawBuiltin)
        ? rawBuiltin
        : null;
    final normalizedTitle =
        _normalizeOptional(json['title'] ?? json['label'] ?? json['name']) ??
        (builtinKey == null
            ? '未命名条目 ${index + 1}'
            : PresetBuiltinEntryKeys.defaultTitleOf(builtinKey));
    return StoredPresetEntry(
      entryId:
          _normalizeOptional(json['entryId']) ??
          (builtinKey == null ? 'entry-$index' : 'builtin-$builtinKey'),
      title: normalizedTitle,
      role: storedPresetEntryRoleFromWire(json['role']),
      content: '${json['content'] ?? ''}',
      enabled: _parsePresetEntryEnabled(json),
      builtinKey: builtinKey,
    );
  }
}

List<StoredPresetEntry> normalizeStoredPresetEntries(
  List<StoredPresetEntry> rawEntries, {
  String legacyMainPrompt = '',
}) {
  final next = rawEntries
      .asMap()
      .entries
      .map(
        (item) => item.value.copyWith(
          entryId: item.value.entryId.trim().isEmpty
              ? (item.value.isBuiltin
                    ? 'builtin-${item.value.builtinKey}'
                    : 'entry-${item.key}')
              : item.value.entryId.trim(),
          title: item.value.title.trim().isEmpty
              ? (item.value.builtinKey == null
                    ? '未命名条目 ${item.key + 1}'
                    : PresetBuiltinEntryKeys.defaultTitleOf(
                        item.value.builtinKey!,
                      ))
              : item.value.title.trim(),
          content: item.value.content.replaceAll('\r\n', '\n'),
        ),
      )
      .toList(growable: true);

  if (next.isEmpty) {
    return buildDefaultPresetEntries(mainPromptContent: legacyMainPrompt);
  }

  for (final builtinKey in PresetBuiltinEntryKeys.ordered) {
    final existingIndex = next.indexWhere(
      (entry) => entry.builtinKey == builtinKey,
    );
    final defaultEntry = _buildBuiltinPresetEntry(
      builtinKey,
      mainPromptContent: legacyMainPrompt,
    );
    if (existingIndex < 0) {
      next.add(defaultEntry);
      continue;
    }
    next[existingIndex] = _normalizeBuiltinEntryInvariants(
      next[existingIndex],
      legacyMainPrompt: legacyMainPrompt,
    );
  }

  return next;
}

List<StoredPresetEntry> buildDefaultPresetEntries({
  String mainPromptContent = '',
}) {
  return PresetBuiltinEntryKeys.ordered
      .map(
        (builtinKey) => _buildBuiltinPresetEntry(
          builtinKey,
          mainPromptContent: mainPromptContent,
        ),
      )
      .toList(growable: false);
}

StoredPresetEntry _buildBuiltinPresetEntry(
  String builtinKey, {
  String mainPromptContent = '',
}) {
  final entry = StoredPresetEntry(
    entryId: 'builtin-$builtinKey',
    title: PresetBuiltinEntryKeys.defaultTitleOf(builtinKey),
    role: builtinKey == PresetBuiltinEntryKeys.interactiveInput
        ? StoredPresetEntryRole.user
        : StoredPresetEntryRole.system,
    content: builtinKey == PresetBuiltinEntryKeys.mainPrompt
        ? mainPromptContent.trim()
        : '',
    builtinKey: builtinKey,
  );
  return _normalizeBuiltinEntryInvariants(
    entry,
    legacyMainPrompt: mainPromptContent,
  );
}

StoredPresetEntry _normalizeBuiltinEntryInvariants(
  StoredPresetEntry entry, {
  String legacyMainPrompt = '',
}) {
  final builtinKey = entry.builtinKey;
  if (builtinKey == null) {
    return entry;
  }
  if (builtinKey == PresetBuiltinEntryKeys.mainPrompt &&
      entry.content.trim().isEmpty &&
      legacyMainPrompt.trim().isNotEmpty) {
    return entry.copyWith(content: legacyMainPrompt.trim());
  }
  if (builtinKey == PresetBuiltinEntryKeys.interactiveInput) {
    return entry.copyWith(
      title: PresetBuiltinEntryKeys.defaultTitleOf(builtinKey),
      role: StoredPresetEntryRole.user,
      content: '',
      enabled: true,
    );
  }
  return entry;
}

class StoredPresetConfig {
  const StoredPresetConfig({
    required this.presetId,
    required this.name,
    required this.entries,
    this.description,
    this.temperature,
    this.topP,
    this.presencePenalty,
    this.frequencyPenalty,
    this.maxCompletionTokens,
    this.stopSequences = const <String>[],
    this.reasoningEffort,
    this.verbosity,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  final String presetId;
  final String name;
  final List<StoredPresetEntry> entries;
  final String? description;
  final double? temperature;
  final double? topP;
  final double? presencePenalty;
  final double? frequencyPenalty;
  final int? maxCompletionTokens;
  final List<String> stopSequences;
  final String? reasoningEffort;
  final String? verbosity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  String get mainPrompt {
    for (final entry in entries) {
      if (entry.builtinKey == PresetBuiltinEntryKeys.mainPrompt) {
        return entry.content;
      }
    }
    return '';
  }

  StoredPresetConfig copyWith({
    String? presetId,
    String? name,
    List<StoredPresetEntry>? entries,
    String? description,
    bool clearDescription = false,
    double? temperature,
    bool clearTemperature = false,
    double? topP,
    bool clearTopP = false,
    double? presencePenalty,
    bool clearPresencePenalty = false,
    double? frequencyPenalty,
    bool clearFrequencyPenalty = false,
    int? maxCompletionTokens,
    bool clearMaxCompletionTokens = false,
    List<String>? stopSequences,
    String? reasoningEffort,
    bool clearReasoningEffort = false,
    String? verbosity,
    bool clearVerbosity = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return StoredPresetConfig(
      presetId: presetId ?? this.presetId,
      name: name ?? this.name,
      entries: entries ?? this.entries,
      description: clearDescription ? null : (description ?? this.description),
      temperature: clearTemperature ? null : (temperature ?? this.temperature),
      topP: clearTopP ? null : (topP ?? this.topP),
      presencePenalty: clearPresencePenalty
          ? null
          : (presencePenalty ?? this.presencePenalty),
      frequencyPenalty: clearFrequencyPenalty
          ? null
          : (frequencyPenalty ?? this.frequencyPenalty),
      maxCompletionTokens: clearMaxCompletionTokens
          ? null
          : (maxCompletionTokens ?? this.maxCompletionTokens),
      stopSequences: stopSequences ?? this.stopSequences,
      reasoningEffort: clearReasoningEffort
          ? null
          : (reasoningEffort ?? this.reasoningEffort),
      verbosity: clearVerbosity ? null : (verbosity ?? this.verbosity),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'presetId': presetId,
      'name': name,
      'entries': entries.map((item) => item.toJson()).toList(growable: false),
      'prompts': _toSillyTavernPrompts(entries),
      'prompt_order': _toSillyTavernPromptOrder(entries),
      'description': description,
      'mainPrompt': mainPrompt,
      'temperature': temperature,
      'topP': topP,
      'presencePenalty': presencePenalty,
      'frequencyPenalty': frequencyPenalty,
      'maxCompletionTokens': maxCompletionTokens,
      'stopSequences': stopSequences,
      'reasoningEffort': reasoningEffort,
      'verbosity': verbosity,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'version': version,
    };
  }

  factory StoredPresetConfig.fromJson(Map<String, dynamic> json) {
    final legacyMainPrompt = '${json['mainPrompt'] ?? ''}'.trim();
    final rawEntries = _parseStoredPresetEntries(json['entries']).isNotEmpty
        ? _parseStoredPresetEntries(json['entries'])
        : _parseStoredPresetEntriesFromSillyTavern(json);
    return StoredPresetConfig(
      presetId: '${json['presetId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      entries: normalizeStoredPresetEntries(
        rawEntries,
        legacyMainPrompt: legacyMainPrompt,
      ),
      description: _normalizeOptional(json['description']),
      temperature: _parseDouble(json['temperature']),
      topP: _parseDouble(json['topP']),
      presencePenalty: _parseDouble(json['presencePenalty']),
      frequencyPenalty: _parseDouble(json['frequencyPenalty']),
      maxCompletionTokens: _parseInt(json['maxCompletionTokens']),
      stopSequences: _parseStringList(json['stopSequences']),
      reasoningEffort: _normalizeOptional(json['reasoningEffort']),
      verbosity: _normalizeOptional(json['verbosity']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      version: _parseInt(json['version']) ?? 1,
    );
  }
}

List<StoredPresetEntry> _parseStoredPresetEntries(Object? raw) {
  if (raw is! List) {
    return const <StoredPresetEntry>[];
  }
  final items = <StoredPresetEntry>[];
  for (var index = 0; index < raw.length; index++) {
    final item = raw[index];
    if (item is! Map) {
      continue;
    }
    items.add(
      StoredPresetEntry.fromJson(Map<String, dynamic>.from(item), index: index),
    );
  }
  return items;
}

List<StoredPresetEntry> _parseStoredPresetEntriesFromSillyTavern(
  Map<String, dynamic> json,
) {
  final rawPrompts = json['prompts'];
  if (rawPrompts is! List) {
    return const <StoredPresetEntry>[];
  }

  final promptByIdentifier = <String, Map<String, dynamic>>{};
  for (final item in rawPrompts) {
    if (item is! Map) {
      continue;
    }
    final prompt = Map<String, dynamic>.from(item);
    final identifier = _normalizeOptional(prompt['identifier']);
    if (identifier == null) {
      continue;
    }
    promptByIdentifier[identifier] = prompt;
  }

  final orderedIdentifiers = <String>[];
  final enabledByIdentifier = <String, bool>{};
  final promptOrder = json['prompt_order'];
  if (promptOrder is List) {
    for (final item in promptOrder) {
      if (item is! Map) {
        continue;
      }
      final orderList = item['order'];
      if (orderList is! List) {
        continue;
      }
      for (final orderItem in orderList) {
        if (orderItem is! Map) {
          continue;
        }
        final identifier = _normalizeOptional(orderItem['identifier']);
        if (identifier == null) {
          continue;
        }
        orderedIdentifiers.add(identifier);
        enabledByIdentifier[identifier] =
            _parseBool(orderItem['enabled']) ?? true;
      }
      break;
    }
  }

  for (final identifier in promptByIdentifier.keys) {
    if (!orderedIdentifiers.contains(identifier)) {
      orderedIdentifiers.add(identifier);
    }
  }

  final entries = <StoredPresetEntry>[];
  for (final identifier in orderedIdentifiers) {
    final prompt = promptByIdentifier[identifier];
    if (prompt == null) {
      continue;
    }
    final builtinKey = _builtinKeyFromSillyTavernIdentifier(identifier);
    final marker = _parseBool(prompt['marker']) ?? false;
    final role = storedPresetEntryRoleFromWire(prompt['role']);
    final title =
        _normalizeOptional(prompt['name']) ??
        (builtinKey == null
            ? identifier
            : PresetBuiltinEntryKeys.defaultTitleOf(builtinKey));
    final content = '${prompt['content'] ?? ''}';
    final enabled =
        enabledByIdentifier[identifier] ??
        _parseBool(prompt['enabled']) ??
        true;

    if (builtinKey == null && marker && content.trim().isEmpty) {
      continue;
    }

    entries.add(
      StoredPresetEntry(
        entryId: identifier,
        title: title,
        role: role,
        content: content,
        enabled: enabled,
        builtinKey: builtinKey,
      ),
    );
  }
  return entries;
}

List<Map<String, dynamic>> _toSillyTavernPrompts(
  List<StoredPresetEntry> entries,
) {
  return entries
      .map(
        (entry) => <String, dynamic>{
          'identifier': _sillyTavernIdentifierForEntry(entry),
          'name': entry.title,
          'system_prompt': entry.role == StoredPresetEntryRole.system,
          'marker': entry.builtinKey == PresetBuiltinEntryKeys.chatHistory,
          if (entry.content.trim().isNotEmpty ||
              entry.builtinKey != PresetBuiltinEntryKeys.chatHistory)
            'content': entry.content,
          'role': entry.role.wireValue,
          'injection_position': 0,
          'injection_depth': 4,
          'forbid_overrides': false,
          'enabled': entry.enabled,
        },
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> _toSillyTavernPromptOrder(
  List<StoredPresetEntry> entries,
) {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'character_id': 100001,
      'order': entries
          .map(
            (entry) => <String, dynamic>{
              'identifier': _sillyTavernIdentifierForEntry(entry),
              'enabled': entry.enabled,
            },
          )
          .toList(growable: false),
    },
  ];
}

String _sillyTavernIdentifierForEntry(StoredPresetEntry entry) {
  if (entry.builtinKey != null) {
    return switch (entry.builtinKey!) {
      PresetBuiltinEntryKeys.mainPrompt => 'main',
      PresetBuiltinEntryKeys.loreBefore => 'worldInfoBefore',
      PresetBuiltinEntryKeys.loreAfter => 'worldInfoAfter',
      PresetBuiltinEntryKeys.userDescription => 'personaDescription',
      PresetBuiltinEntryKeys.chatHistory => 'chatHistory',
      PresetBuiltinEntryKeys.scene => 'scenario',
      PresetBuiltinEntryKeys.interactiveInput => 'interactiveInput',
      _ => entry.entryId,
    };
  }
  return entry.entryId;
}

String? _builtinKeyFromSillyTavernIdentifier(String identifier) {
  return switch (identifier) {
    'main' => PresetBuiltinEntryKeys.mainPrompt,
    'worldInfoBefore' => PresetBuiltinEntryKeys.loreBefore,
    'worldInfoAfter' => PresetBuiltinEntryKeys.loreAfter,
    'personaDescription' => PresetBuiltinEntryKeys.userDescription,
    'chatHistory' => PresetBuiltinEntryKeys.chatHistory,
    'scenario' => PresetBuiltinEntryKeys.scene,
    'interactiveInput' => PresetBuiltinEntryKeys.interactiveInput,
    _ => null,
  };
}

bool _parsePresetEntryEnabled(Map<String, dynamic> json) {
  final enabled = _parseBool(json['enabled']);
  if (enabled != null) {
    return enabled;
  }
  final disabled = _parseBool(json['disabled']);
  if (disabled != null) {
    return !disabled;
  }
  return true;
}

Map<String, String> _parseHeaders(Object? raw) {
  if (raw is! Map) {
    return const <String, String>{};
  }
  final next = <String, String>{};
  raw.forEach((key, value) {
    final normalizedKey = '$key'.trim();
    final normalizedValue = '$value'.trim();
    if (normalizedKey.isEmpty || normalizedValue.isEmpty) {
      return;
    }
    next[normalizedKey] = normalizedValue;
  });
  return next;
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _normalizeOptional(Object? raw) {
  final normalized = '$raw'.trim();
  if (normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}

int? _parseInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse('$raw'.trim());
}

double? _parseDouble(Object? raw) {
  if (raw is double) {
    return raw;
  }
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse('$raw'.trim());
}

bool? _parseBool(Object? raw) {
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

DateTime _parseDateTime(Object? raw) {
  final parsed = DateTime.tryParse('$raw');
  return parsed?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
