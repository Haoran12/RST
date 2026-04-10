import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../bridge/frb_api.dart' as frb;
import '../models/common.dart';
import '../models/workspace_config.dart';

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

  Future<void> warmup() async {
    await ensureDefaults();
  }

  StartupChatRuntime loadStartupRuntime() {
    final apiConfig = _defaultApiConfig();
    final presetConfig = _defaultPresetConfig();
    return StartupChatRuntime(
      apiConfig: _toRuntimeApiConfig(apiConfig),
      presetConfig: _toRuntimePresetConfig(presetConfig),
      maxContextMessages: _parseInt(_maxContextMessagesRaw) ?? 16,
      defaultUserDescription: _defaultUserDescription.trim(),
      defaultScene: _defaultScene.trim(),
      defaultLores: _defaultLores.trim(),
    );
  }

  StoredPresetConfig buildPresetDraft({String? name}) {
    final now = DateTime.now().toUtc();
    final base = _defaultPresetConfig();
    final normalizedName = (name ?? '新预设').trim();
    return base.copyWith(
      presetId: _newId('preset'),
      name: normalizedName.isEmpty ? '新预设' : normalizedName,
      createdAt: now,
      updatedAt: now,
    );
  }

  StoredApiConfig buildApiConfigDraft({String? name}) {
    final now = DateTime.now().toUtc();
    final base = _defaultApiConfig();
    final normalizedName = (name ?? '新API配置').trim();
    return base.copyWith(
      apiId: _newId('api'),
      name: normalizedName.isEmpty ? '新API配置' : normalizedName,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<StoredPresetConfig>> listPresets() async {
    await ensureDefaults();
    final files = await _jsonFiles(await _presetsDirectory());
    final items = <StoredPresetConfig>[];
    for (final file in files) {
      items.add(await _readPresetFile(file));
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<List<StoredApiConfig>> listApiConfigs() async {
    await ensureDefaults();
    final files = await _jsonFiles(await _apiConfigsDirectory());
    final items = <StoredApiConfig>[];
    for (final file in files) {
      items.add(await _readApiFile(file));
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<StoredPresetConfig> getPreset(String presetId) async {
    await ensureDefaults();
    final file = await _presetFile(presetId);
    if (!await file.exists()) {
      throw StateError('preset_not_found: $presetId');
    }
    return _readPresetFile(file);
  }

  Future<StoredApiConfig> getApiConfig(String apiId) async {
    await ensureDefaults();
    final file = await _apiConfigFile(apiId);
    if (!await file.exists()) {
      throw StateError('api_config_not_found: $apiId');
    }
    return _readApiFile(file);
  }

  Future<StoredPresetConfig> savePreset(StoredPresetConfig config) async {
    final now = DateTime.now().toUtc();
    final normalized = config.copyWith(
      name: config.name.trim().isEmpty ? '未命名预设' : config.name.trim(),
      description: _normalizeOptional(config.description),
      clearDescription: _normalizeOptional(config.description) == null,
      mainPrompt: config.mainPrompt.trim(),
      stopSequences: config.stopSequences
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      reasoningEffort: _normalizeOptional(config.reasoningEffort),
      clearReasoningEffort: _normalizeOptional(config.reasoningEffort) == null,
      verbosity: _normalizeOptional(config.verbosity),
      clearVerbosity: _normalizeOptional(config.verbosity) == null,
      updatedAt: now,
      createdAt: config.createdAt.toUtc(),
    );
    final file = await _presetFile(normalized.presetId);
    await _writeJson(file, normalized.toJson());
    return normalized;
  }

  Future<StoredApiConfig> saveApiConfig(StoredApiConfig config) async {
    final now = DateTime.now().toUtc();
    final normalizedKey = config.apiKeyCiphertext.trim();
    final normalized = config.copyWith(
      name: config.name.trim().isEmpty ? '未命名 API 配置' : config.name.trim(),
      baseUrl: config.baseUrl.trim(),
      requestPath: config.requestPath.trim(),
      apiKeyCiphertext: normalizedKey,
      apiKeyHint: _buildApiKeyHint(normalizedKey),
      clearApiKeyHint: normalizedKey.isEmpty,
      defaultModel: config.defaultModel.trim(),
      customHeaders: _sanitizeHeaders(config.customHeaders),
      requestTimeoutMs:
          config.requestTimeoutMs != null && config.requestTimeoutMs! > 0
          ? config.requestTimeoutMs
          : null,
      clearRequestTimeoutMs:
          config.requestTimeoutMs == null || config.requestTimeoutMs! <= 0,
      updatedAt: now,
      createdAt: config.createdAt.toUtc(),
    );
    final file = await _apiConfigFile(normalized.apiId);
    await _writeJson(file, normalized.toJson());
    return normalized;
  }

  Future<void> deletePreset(String presetId) async {
    final file = await _presetFile(presetId);
    if (await file.exists()) {
      await file.delete();
    }
    await ensureDefaults();
  }

  Future<void> deleteApiConfig(String apiId) async {
    final file = await _apiConfigFile(apiId);
    if (await file.exists()) {
      await file.delete();
    }
    await ensureDefaults();
  }

  Future<void> ensureDefaults() async {
    final presetsDir = await _presetsDirectory();
    final apisDir = await _apiConfigsDirectory();
    final presetFiles = await _jsonFiles(presetsDir);
    if (presetFiles.isEmpty) {
      await savePreset(_defaultPresetConfig());
    }
    final apiFiles = await _jsonFiles(apisDir);
    if (apiFiles.isEmpty) {
      await saveApiConfig(_defaultApiConfig());
    }
  }

  Future<StartupChatRuntime> loadSessionRuntime(
    frb.SessionConfig session,
  ) async {
    await ensureDefaults();
    final apiConfig = await getApiConfig(session.mainApiConfigId);
    final presetConfig = await getPreset(session.presetId);
    return StartupChatRuntime(
      apiConfig: _toRuntimeApiConfig(apiConfig),
      presetConfig: _toRuntimePresetConfig(presetConfig),
      maxContextMessages: _parseInt(_maxContextMessagesRaw) ?? 16,
      defaultUserDescription: _defaultUserDescription.trim(),
      defaultScene: _defaultScene.trim(),
      defaultLores: _defaultLores.trim(),
    );
  }

  RuntimeApiConfig _toRuntimeApiConfig(StoredApiConfig config) {
    final providerType = config.providerType;
    final requestPath = config.requestPath.trim().isEmpty
        ? providerType == ProviderType.openai
              ? '/v1/responses'
              : '/v1/chat/completions'
        : config.requestPath.trim();
    return RuntimeApiConfig(
      apiId: config.apiId,
      name: config.name,
      providerType: providerType,
      baseUrl: config.baseUrl.trim(),
      requestPath: requestPath,
      apiKey: config.apiKeyCiphertext.trim(),
      defaultModel: config.defaultModel.trim(),
      customHeaders: config.customHeaders,
      requestTimeoutMs: config.requestTimeoutMs,
    );
  }

  RuntimePresetConfig _toRuntimePresetConfig(StoredPresetConfig config) {
    final entries = _buildPresetEntries(config.mainPrompt.trim());
    _assertBuiltinEntries(entries);
    return RuntimePresetConfig(
      presetId: config.presetId,
      name: config.name,
      entries: entries,
      temperature: config.temperature,
      topP: config.topP,
      presencePenalty: config.presencePenalty,
      frequencyPenalty: config.frequencyPenalty,
      maxCompletionTokens: config.maxCompletionTokens,
      stopSequences: config.stopSequences,
      reasoningEffort: _normalizeOptional(config.reasoningEffort),
      verbosity: _normalizeOptional(config.verbosity),
    );
  }

  List<RuntimePresetEntry> _buildPresetEntries(String mainPrompt) {
    return <RuntimePresetEntry>[
      RuntimePresetEntry(
        name: PresetBuiltinEntryNames.mainPrompt,
        role: 'system',
        content: mainPrompt,
        disabled: false,
        comment: '主系统指令',
        builtin: true,
      ),
      const RuntimePresetEntry(
        name: PresetBuiltinEntryNames.lores,
        role: 'system',
        content: '',
        disabled: false,
        comment: 'Lore 注入调度器输出',
        builtin: true,
      ),
      const RuntimePresetEntry(
        name: PresetBuiltinEntryNames.userDescription,
        role: 'system',
        content: '',
        disabled: false,
        comment: 'Session 用户描述',
        builtin: true,
      ),
      const RuntimePresetEntry(
        name: PresetBuiltinEntryNames.chatHistory,
        role: 'system',
        content: '',
        disabled: false,
        comment: '最近可见消息',
        builtin: true,
      ),
      const RuntimePresetEntry(
        name: PresetBuiltinEntryNames.scene,
        role: 'system',
        content: '',
        disabled: false,
        comment: '会话场景',
        builtin: true,
      ),
      const RuntimePresetEntry(
        name: PresetBuiltinEntryNames.userInput,
        role: 'user',
        content: '',
        disabled: false,
        comment: '用户输入',
        builtin: true,
      ),
    ];
  }

  void _assertBuiltinEntries(List<RuntimePresetEntry> entries) {
    final names = entries.map((entry) => entry.name).toSet();
    for (final requiredName in PresetBuiltinEntryNames.all) {
      if (!names.contains(requiredName)) {
        throw StateError(
          'missing required preset builtin entry: $requiredName',
        );
      }
    }
  }

  StoredApiConfig _defaultApiConfig() {
    final providerType = _providerTypeRaw.trim().toLowerCase() == 'openai'
        ? ProviderType.openai
        : ProviderType.openaiCompatible;
    final requestPath = _apiRequestPathRaw.trim().isEmpty
        ? providerType == ProviderType.openai
              ? '/v1/responses'
              : '/v1/chat/completions'
        : _apiRequestPathRaw.trim();
    final now = DateTime.now().toUtc();
    return StoredApiConfig(
      apiId: _apiId,
      name: _apiName,
      providerType: providerType,
      baseUrl: _apiBaseUrl.trim(),
      requestPath: requestPath,
      apiKeyCiphertext: _apiKey.trim(),
      apiKeyHint: _buildApiKeyHint(_apiKey.trim()),
      defaultModel: _apiModel.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  StoredPresetConfig _defaultPresetConfig() {
    final now = DateTime.now().toUtc();
    return StoredPresetConfig(
      presetId: _presetId,
      name: _presetName,
      mainPrompt: _presetMainPrompt.trim(),
      temperature: _parseDouble(_presetTemperatureRaw),
      topP: _parseDouble(_presetTopPRaw),
      presencePenalty: _parseDouble(_presetPresencePenaltyRaw),
      frequencyPenalty: _parseDouble(_presetFrequencyPenaltyRaw),
      maxCompletionTokens: _parseInt(_presetMaxCompletionTokensRaw),
      stopSequences: _parseCsv(_presetStopSequencesRaw),
      reasoningEffort: _normalizeOptional(_presetReasoningEffort),
      verbosity: _normalizeOptional(_presetVerbosity),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Directory> _workspaceDir() async {
    Directory supportDir;
    try {
      supportDir = await getApplicationSupportDirectory();
    } catch (_) {
      supportDir = Directory('${Directory.systemTemp.path}/rst_test_support');
      if (!supportDir.existsSync()) {
        supportDir.createSync(recursive: true);
      }
    }
    final workspaceDir = Directory('${supportDir.path}/rst_data');
    if (!workspaceDir.existsSync()) {
      workspaceDir.createSync(recursive: true);
    }
    return workspaceDir;
  }

  Future<Directory> _presetsDirectory() async {
    final dir = Directory('${(await _workspaceDir()).path}/config/presets');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<Directory> _apiConfigsDirectory() async {
    final dir = Directory('${(await _workspaceDir()).path}/config/api_configs');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<File> _presetFile(String presetId) async {
    return File('${(await _presetsDirectory()).path}/$presetId.json');
  }

  Future<File> _apiConfigFile(String apiId) async {
    return File('${(await _apiConfigsDirectory()).path}/$apiId.json');
  }

  Future<List<File>> _jsonFiles(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<StoredPresetConfig> _readPresetFile(File file) async {
    final raw = await file.readAsString();
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw StateError('invalid_preset_file: ${file.path}');
    }
    return StoredPresetConfig.fromJson(json);
  }

  Future<StoredApiConfig> _readApiFile(File file) async {
    final raw = await file.readAsString();
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw StateError('invalid_api_config_file: ${file.path}');
    }
    return StoredApiConfig.fromJson(json);
  }

  Future<void> _writeJson(File file, Map<String, dynamic> json) async {
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  String _newId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> raw) {
    final next = <String, String>{};
    raw.forEach((key, value) {
      final normalizedKey = key.trim();
      final normalizedValue = value.trim();
      if (normalizedKey.isEmpty || normalizedValue.isEmpty) {
        return;
      }
      next[normalizedKey] = normalizedValue;
    });
    return next;
  }

  String? _buildApiKeyHint(String apiKey) {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length <= 8) {
      return '${normalized.substring(0, 2)}***';
    }
    return '${normalized.substring(0, 4)}***${normalized.substring(normalized.length - 4)}';
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

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim() ?? '';
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
