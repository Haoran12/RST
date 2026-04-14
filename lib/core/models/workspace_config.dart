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

class StoredPresetConfig {
  const StoredPresetConfig({
    required this.presetId,
    required this.name,
    this.description,
    required this.mainPrompt,
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
  final String? description;
  final String mainPrompt;
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

  StoredPresetConfig copyWith({
    String? presetId,
    String? name,
    String? description,
    bool clearDescription = false,
    String? mainPrompt,
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
      description: clearDescription ? null : (description ?? this.description),
      mainPrompt: mainPrompt ?? this.mainPrompt,
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
    return StoredPresetConfig(
      presetId: '${json['presetId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: _normalizeOptional(json['description']),
      mainPrompt: '${json['mainPrompt'] ?? ''}',
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
