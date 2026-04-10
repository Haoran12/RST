import '../models/common.dart';

class PresetBuiltinEntryNames {
  static const String mainPrompt = 'Main_Prompt';
  static const String lores = 'lores';
  static const String userDescription = 'user_description';
  static const String chatHistory = 'chat_history';
  static const String scene = 'scene';
  static const String userInput = 'user_input';

  static const List<String> all = <String>[
    mainPrompt,
    lores,
    userDescription,
    chatHistory,
    scene,
    userInput,
  ];
}

class RuntimeApiConfig {
  const RuntimeApiConfig({
    required this.apiId,
    required this.name,
    required this.providerType,
    required this.baseUrl,
    required this.requestPath,
    required this.apiKey,
    required this.defaultModel,
    this.customHeaders = const <String, String>{},
    this.requestTimeoutMs,
  });

  final String apiId;
  final String name;
  final ProviderType providerType;
  final String baseUrl;
  final String requestPath;
  final String apiKey;
  final String defaultModel;
  final Map<String, String> customHeaders;
  final int? requestTimeoutMs;
}

class RuntimePresetEntry {
  const RuntimePresetEntry({
    required this.name,
    required this.role,
    required this.content,
    required this.disabled,
    required this.comment,
    required this.builtin,
  });

  final String name;
  final String role;
  final String content;
  final bool disabled;
  final String comment;
  final bool builtin;
}

class RuntimePresetConfig {
  const RuntimePresetConfig({
    required this.presetId,
    required this.name,
    required this.entries,
    this.temperature,
    this.topP,
    this.presencePenalty,
    this.frequencyPenalty,
    this.maxCompletionTokens,
    this.stopSequences = const <String>[],
    this.reasoningEffort,
    this.verbosity,
  });

  final String presetId;
  final String name;
  final List<RuntimePresetEntry> entries;
  final double? temperature;
  final double? topP;
  final double? presencePenalty;
  final double? frequencyPenalty;
  final int? maxCompletionTokens;
  final List<String> stopSequences;
  final String? reasoningEffort;
  final String? verbosity;
}

class StartupChatRuntime {
  const StartupChatRuntime({
    required this.apiConfig,
    required this.presetConfig,
    required this.maxContextMessages,
    required this.defaultUserDescription,
    required this.defaultScene,
    required this.defaultLores,
  });

  final RuntimeApiConfig apiConfig;
  final RuntimePresetConfig presetConfig;
  final int maxContextMessages;
  final String defaultUserDescription;
  final String defaultScene;
  final String defaultLores;
}

class ApiService {
  const ApiService();

  static const String _providerTypeRaw = String.fromEnvironment(
    'RST_API_PROVIDER',
    defaultValue: 'openai_compatible',
  );
  static const String _apiBaseUrl = String.fromEnvironment(
    'RST_API_BASE_URL',
    defaultValue: 'https://api.openai.com',
  );
  static const String _apiRequestPathRaw = String.fromEnvironment(
    'RST_API_REQUEST_PATH',
    defaultValue: '',
  );
  static const String _apiKey = String.fromEnvironment(
    'RST_API_KEY',
    defaultValue: '',
  );
  static const String _apiModel = String.fromEnvironment(
    'RST_API_MODEL',
    defaultValue: 'gpt-5.4-mini',
  );
  static const String _apiId = String.fromEnvironment(
    'RST_API_ID',
    defaultValue: 'api-startup',
  );
  static const String _apiName = String.fromEnvironment(
    'RST_API_NAME',
    defaultValue: 'Startup API Config',
  );

  static const String _presetId = String.fromEnvironment(
    'RST_PRESET_ID',
    defaultValue: 'preset-startup',
  );
  static const String _presetName = String.fromEnvironment(
    'RST_PRESET_NAME',
    defaultValue: 'Startup Preset',
  );
  static const String _presetMainPrompt = String.fromEnvironment(
    'RST_PRESET_MAIN_PROMPT',
    defaultValue: '你是 RST 的助手，请基于上下文给出清晰、连贯的回复。',
  );
  static const String _presetTemperatureRaw = String.fromEnvironment(
    'RST_PRESET_TEMPERATURE',
    defaultValue: '0.8',
  );
  static const String _presetTopPRaw = String.fromEnvironment(
    'RST_PRESET_TOP_P',
    defaultValue: '1.0',
  );
  static const String _presetPresencePenaltyRaw = String.fromEnvironment(
    'RST_PRESET_PRESENCE_PENALTY',
    defaultValue: '',
  );
  static const String _presetFrequencyPenaltyRaw = String.fromEnvironment(
    'RST_PRESET_FREQUENCY_PENALTY',
    defaultValue: '',
  );
  static const String _presetMaxCompletionTokensRaw = String.fromEnvironment(
    'RST_PRESET_MAX_COMPLETION_TOKENS',
    defaultValue: '512',
  );
  static const String _presetReasoningEffort = String.fromEnvironment(
    'RST_PRESET_REASONING_EFFORT',
    defaultValue: '',
  );
  static const String _presetVerbosity = String.fromEnvironment(
    'RST_PRESET_VERBOSITY',
    defaultValue: '',
  );
  static const String _presetStopSequencesRaw = String.fromEnvironment(
    'RST_PRESET_STOP_SEQUENCES',
    defaultValue: '',
  );
  static const String _presetOrderRaw = String.fromEnvironment(
    'RST_PRESET_ENTRY_ORDER',
    defaultValue: '',
  );
  static const String _presetDisabledRaw = String.fromEnvironment(
    'RST_PRESET_DISABLED_ENTRIES',
    defaultValue: '',
  );
  static const String _maxContextMessagesRaw = String.fromEnvironment(
    'RST_MAX_CONTEXT_MESSAGES',
    defaultValue: '16',
  );
  static const String _defaultUserDescription = String.fromEnvironment(
    'RST_SESSION_USER_DESCRIPTION',
    defaultValue: '',
  );
  static const String _defaultScene = String.fromEnvironment(
    'RST_SCENE_DESCRIPTION',
    defaultValue: '',
  );
  static const String _defaultLores = String.fromEnvironment(
    'RST_LORES_DESCRIPTION',
    defaultValue: '',
  );

  StartupChatRuntime loadStartupRuntime() {
    final providerType = _providerTypeRaw.trim().toLowerCase() == 'openai'
        ? ProviderType.openai
        : ProviderType.openaiCompatible;
    final requestPath = _apiRequestPathRaw.trim().isEmpty
        ? providerType == ProviderType.openai
              ? '/v1/responses'
              : '/v1/chat/completions'
        : _apiRequestPathRaw.trim();

    final apiConfig = RuntimeApiConfig(
      apiId: _apiId,
      name: _apiName,
      providerType: providerType,
      baseUrl: _apiBaseUrl.trim(),
      requestPath: requestPath,
      apiKey: _apiKey.trim(),
      defaultModel: _apiModel.trim(),
      requestTimeoutMs: null,
    );

    final entries = _buildPresetEntries();
    _assertBuiltinEntries(entries);

    final presetConfig = RuntimePresetConfig(
      presetId: _presetId,
      name: _presetName,
      entries: entries,
      temperature: _parseDouble(_presetTemperatureRaw),
      topP: _parseDouble(_presetTopPRaw),
      presencePenalty: _parseDouble(_presetPresencePenaltyRaw),
      frequencyPenalty: _parseDouble(_presetFrequencyPenaltyRaw),
      maxCompletionTokens: _parseInt(_presetMaxCompletionTokensRaw),
      stopSequences: _parseCsv(_presetStopSequencesRaw),
      reasoningEffort: _normalizeOptional(_presetReasoningEffort),
      verbosity: _normalizeOptional(_presetVerbosity),
    );

    return StartupChatRuntime(
      apiConfig: apiConfig,
      presetConfig: presetConfig,
      maxContextMessages: _parseInt(_maxContextMessagesRaw) ?? 16,
      defaultUserDescription: _defaultUserDescription.trim(),
      defaultScene: _defaultScene.trim(),
      defaultLores: _defaultLores.trim(),
    );
  }

  Future<void> warmup() async {
    loadStartupRuntime();
  }

  List<RuntimePresetEntry> _buildPresetEntries() {
    final disabled = _parseCsv(_presetDisabledRaw).toSet();
    final order = _parseCsv(_presetOrderRaw);
    final defaults = <String, RuntimePresetEntry>{
      PresetBuiltinEntryNames.mainPrompt: RuntimePresetEntry(
        name: PresetBuiltinEntryNames.mainPrompt,
        role: 'system',
        content: _presetMainPrompt.trim(),
        disabled: disabled.contains(PresetBuiltinEntryNames.mainPrompt),
        comment: '主系统指令（用户可通过 preset 主指令配置）',
        builtin: true,
      ),
      PresetBuiltinEntryNames.lores: RuntimePresetEntry(
        name: PresetBuiltinEntryNames.lores,
        role: 'system',
        content: '',
        disabled: disabled.contains(PresetBuiltinEntryNames.lores),
        comment: 'Lore 注入调度器输出',
        builtin: true,
      ),
      PresetBuiltinEntryNames.userDescription: RuntimePresetEntry(
        name: PresetBuiltinEntryNames.userDescription,
        role: 'system',
        content: '',
        disabled: disabled.contains(PresetBuiltinEntryNames.userDescription),
        comment: 'Session 用户描述',
        builtin: true,
      ),
      PresetBuiltinEntryNames.chatHistory: RuntimePresetEntry(
        name: PresetBuiltinEntryNames.chatHistory,
        role: 'system',
        content: '',
        disabled: disabled.contains(PresetBuiltinEntryNames.chatHistory),
        comment: '最近 mem_length 条可见消息',
        builtin: true,
      ),
      PresetBuiltinEntryNames.scene: RuntimePresetEntry(
        name: PresetBuiltinEntryNames.scene,
        role: 'system',
        content: '',
        disabled: disabled.contains(PresetBuiltinEntryNames.scene),
        comment: '会话场景',
        builtin: true,
      ),
      PresetBuiltinEntryNames.userInput: RuntimePresetEntry(
        name: PresetBuiltinEntryNames.userInput,
        role: 'user',
        content: '',
        disabled: disabled.contains(PresetBuiltinEntryNames.userInput),
        comment: '用户最新输入',
        builtin: true,
      ),
    };

    if (order.isEmpty) {
      return PresetBuiltinEntryNames.all
          .map((name) => defaults[name]!)
          .toList(growable: false);
    }

    final ordered = <RuntimePresetEntry>[];
    final remaining = <String>{...PresetBuiltinEntryNames.all};
    for (final name in order) {
      if (!defaults.containsKey(name)) {
        continue;
      }
      ordered.add(defaults[name]!);
      remaining.remove(name);
    }
    for (final name in PresetBuiltinEntryNames.all) {
      if (remaining.contains(name)) {
        ordered.add(defaults[name]!);
      }
    }
    return ordered;
  }

  void _assertBuiltinEntries(List<RuntimePresetEntry> entries) {
    final names = entries.map((entry) => entry.name).toSet();
    for (final requiredName in PresetBuiltinEntryNames.all) {
      if (!names.contains(requiredName)) {
        throw StateError('missing required preset builtin entry: $requiredName');
      }
    }
  }

  double? _parseDouble(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  int? _parseInt(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  String? _normalizeOptional(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<String> _parseCsv(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
