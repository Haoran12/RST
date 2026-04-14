import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../bridge/frb_api.dart' as frb;
import '../models/common.dart';
import '../models/workspace_config.dart';

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
}

class RuntimePresetEntry {
  const RuntimePresetEntry({
    required this.entryId,
    required this.title,
    required this.role,
    required this.content,
    required this.enabled,
    this.builtinKey,
  });

  final String entryId;
  final String title;
  final String role;
  final String content;
  final bool enabled;
  final String? builtinKey;

  bool get isBuiltin => builtinKey != null;
}

class RuntimePresetConfig {
  const RuntimePresetConfig({
    required this.presetId,
    required this.name,
    required this.entries,
  });

  final String presetId;
  final String name;
  final List<RuntimePresetEntry> entries;
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
    final normalizedEntries = normalizeStoredPresetEntries(
      config.entries
          .map(
            (entry) => entry.copyWith(
              title: entry.title.trim(),
              content: entry.content.replaceAll('\r\n', '\n'),
            ),
          )
          .toList(growable: false),
      legacyMainPrompt: config.mainPrompt,
    );
    final normalized = config.copyWith(
      name: config.name.trim().isEmpty ? '未命名预设' : config.name.trim(),
      entries: normalizedEntries,
      description: _normalizeOptional(config.description),
      clearDescription: _normalizeOptional(config.description) == null,
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
      stream: config.stream,
      clearStream: config.stream == null,
      temperature: config.temperature,
      clearTemperature: config.temperature == null,
      topP: config.topP,
      clearTopP: config.topP == null,
      topK: config.topK != null && config.topK! >= 0 ? config.topK : null,
      clearTopK: config.topK == null || config.topK! < 0,
      presencePenalty: config.presencePenalty,
      clearPresencePenalty: config.presencePenalty == null,
      frequencyPenalty: config.frequencyPenalty,
      clearFrequencyPenalty: config.frequencyPenalty == null,
      maxCompletionTokens:
          config.maxCompletionTokens != null && config.maxCompletionTokens! > 0
          ? config.maxCompletionTokens
          : null,
      clearMaxCompletionTokens:
          config.maxCompletionTokens == null ||
          config.maxCompletionTokens! <= 0,
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

  Future<List<String>> fetchAvailableModels({
    required ProviderType providerType,
    required String baseUrl,
    required String requestPath,
    required String apiKey,
    Map<String, String> customHeaders = const <String, String>{},
    int? requestTimeoutMs,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(milliseconds: requestTimeoutMs ?? 15000),
        receiveTimeout: Duration(milliseconds: requestTimeoutMs ?? 15000),
        sendTimeout: Duration(milliseconds: requestTimeoutMs ?? 15000),
      ),
    );

    try {
      final response = await dio.getUri<dynamic>(
        _buildModelsUri(
          providerType: providerType,
          baseUrl: baseUrl,
          requestPath: requestPath,
          apiKey: apiKey,
        ),
        options: Options(
          headers: _buildModelFetchHeaders(
            providerType: providerType,
            apiKey: apiKey,
            customHeaders: customHeaders,
          ),
        ),
      );
      final payload = response.data;
      final models = _extractModels(
        providerType: providerType,
        payload: payload,
      );

      if (models.isEmpty) {
        throw StateError('没有返回可用模型');
      }
      return models;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final details = error.response?.data?.toString().trim();
      if (statusCode == null) {
        throw StateError(error.message ?? '获取模型列表失败');
      }
      if (details == null || details.isEmpty) {
        throw StateError('http_$statusCode');
      }
      throw StateError('http_$statusCode: $details');
    } finally {
      dio.close();
    }
  }

  RuntimeApiConfig _toRuntimeApiConfig(StoredApiConfig config) {
    final providerType = config.providerType;
    final requestPath = config.requestPath.trim().isEmpty
        ? providerType.defaultRequestPath
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
      stream: config.stream,
      temperature: config.temperature,
      topP: config.topP,
      topK: config.topK,
      presencePenalty: config.presencePenalty,
      frequencyPenalty: config.frequencyPenalty,
      maxCompletionTokens: config.maxCompletionTokens,
      stopSequences: config.stopSequences,
      reasoningEffort: _normalizeOptional(config.reasoningEffort),
      verbosity: _normalizeOptional(config.verbosity),
    );
  }

  RuntimePresetConfig _toRuntimePresetConfig(StoredPresetConfig config) {
    final entries = _buildPresetEntries(config.entries);
    _assertBuiltinEntries(entries);
    return RuntimePresetConfig(
      presetId: config.presetId,
      name: config.name,
      entries: entries,
    );
  }

  List<RuntimePresetEntry> _buildPresetEntries(
    List<StoredPresetEntry> entries,
  ) {
    return entries
        .map(
          (entry) => RuntimePresetEntry(
            entryId: entry.entryId,
            title: entry.title,
            role: entry.role.wireValue,
            content: entry.content,
            enabled: entry.enabled,
            builtinKey: entry.builtinKey,
          ),
        )
        .toList(growable: false);
  }

  void _assertBuiltinEntries(List<RuntimePresetEntry> entries) {
    final builtinKeys = entries
        .map((entry) => entry.builtinKey)
        .whereType<String>()
        .toSet();
    for (final requiredName in PresetBuiltinEntryKeys.ordered) {
      if (!builtinKeys.contains(requiredName)) {
        throw StateError(
          'missing required preset builtin entry: $requiredName',
        );
      }
    }
  }

  StoredApiConfig _defaultApiConfig() {
    final providerType = providerTypeFromWire(_providerTypeRaw);
    final requestPath = _apiRequestPathRaw.trim().isEmpty
        ? providerType.defaultRequestPath
        : _apiRequestPathRaw.trim();
    final now = DateTime.now().toUtc();
    return StoredApiConfig(
      apiId: _apiId,
      name: _apiName,
      providerType: providerType,
      baseUrl: _apiBaseUrl.trim().isEmpty
          ? providerType.defaultBaseUrl
          : _apiBaseUrl.trim(),
      requestPath: requestPath,
      apiKeyCiphertext: _apiKey.trim(),
      apiKeyHint: _buildApiKeyHint(_apiKey.trim()),
      defaultModel: _apiModel.trim().isEmpty
          ? providerType.defaultModel
          : _apiModel.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  StoredPresetConfig _defaultPresetConfig() {
    final now = DateTime.now().toUtc();
    return StoredPresetConfig(
      presetId: _presetId,
      name: _presetName,
      entries: buildDefaultPresetEntries(
        mainPromptContent: _presetMainPrompt.trim(),
      ),
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
    final normalizedJson = <String, dynamic>{
      ...json,
      if ('${json['presetId'] ?? ''}'.trim().isEmpty)
        'presetId': file.uri.pathSegments.last.replaceFirst('.json', ''),
      if ('${json['name'] ?? ''}'.trim().isEmpty)
        'name': file.uri.pathSegments.last.replaceFirst('.json', ''),
    };
    return StoredPresetConfig.fromJson(normalizedJson);
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

  String _composeModelsUrl({
    required String baseUrl,
    required String requestPath,
  }) {
    final endpointUri = _resolveRequestUri(
      baseUrl: baseUrl,
      requestPath: requestPath,
    );
    var segments = endpointUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: true);
    segments = _trimRequestSegments(segments);
    if (!segments.contains('v1')) {
      segments.add('v1');
    } else {
      final v1Index = segments.indexOf('v1');
      segments = segments.sublist(0, v1Index + 1);
    }
    segments.add('models');

    return endpointUri
        .replace(pathSegments: segments, query: null, fragment: null)
        .toString();
  }

  List<String> _trimRequestSegments(List<String> segments) {
    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'chat' &&
        segments.last == 'completions') {
      return segments.sublist(0, segments.length - 2);
    }
    if (segments.isNotEmpty &&
        (segments.last == 'responses' || segments.last == 'completions')) {
      return segments.sublist(0, segments.length - 1);
    }
    return segments;
  }

  Uri _buildModelsUri({
    required ProviderType providerType,
    required String baseUrl,
    required String requestPath,
    required String apiKey,
  }) {
    switch (providerType) {
      case ProviderType.gemini:
        final url = _composeGeminiModelsUrl(
          baseUrl: baseUrl,
          requestPath: requestPath,
        );
        final uri = Uri.parse(url);
        return uri.replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            if (apiKey.trim().isNotEmpty) 'key': apiKey.trim(),
          },
        );
      case ProviderType.deepseek:
        return Uri.parse(
          _composeModelsUrl(
            baseUrl: _stripTrailingDeepSeekBeta(baseUrl),
            requestPath: requestPath,
          ),
        );
      default:
        return Uri.parse(
          _composeModelsUrl(baseUrl: baseUrl, requestPath: requestPath),
        );
    }
  }

  Map<String, String> _buildModelFetchHeaders({
    required ProviderType providerType,
    required String apiKey,
    required Map<String, String> customHeaders,
  }) {
    final headers = <String, String>{...customHeaders};
    if (providerType == ProviderType.openai ||
        providerType == ProviderType.openaiCompatible ||
        providerType == ProviderType.deepseek ||
        providerType == ProviderType.openrouter) {
      if (apiKey.trim().isNotEmpty) {
        headers.putIfAbsent('Authorization', () => 'Bearer ${apiKey.trim()}');
      }
    }
    if (providerType == ProviderType.openrouter) {
      headers.putIfAbsent('HTTP-Referer', () => 'https://sillytavern.app');
      headers.putIfAbsent('X-Title', () => 'SillyTavern');
    }
    if (providerType == ProviderType.anthropic) {
      if (apiKey.trim().isNotEmpty) {
        headers.putIfAbsent('x-api-key', () => apiKey.trim());
      }
      headers.putIfAbsent('anthropic-version', () => '2023-06-01');
    }
    return headers;
  }

  List<String> _extractModels({
    required ProviderType providerType,
    required Object? payload,
  }) {
    if (payload is! Map) {
      throw StateError('模型列表响应格式不正确');
    }
    switch (providerType) {
      case ProviderType.gemini:
        final models = payload['models'];
        if (models is! List) {
          throw StateError('模型列表响应缺少 models');
        }
        return models
            .whereType<Map>()
            .map((item) => '${item['name'] ?? ''}'.trim())
            .map((name) => name.replaceFirst('models/', ''))
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
      default:
        final data = payload['data'];
        if (data is! List) {
          throw StateError('模型列表响应缺少 data');
        }
        return data
            .whereType<Map>()
            .map((item) => '${item['id'] ?? ''}'.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    }
  }

  String _composeGeminiModelsUrl({
    required String baseUrl,
    required String requestPath,
  }) {
    final normalizedPath = requestPath.trim().isEmpty
        ? ProviderType.gemini.defaultRequestPath
        : requestPath.trim();
    return _resolveRequestUri(
      baseUrl: baseUrl,
      requestPath: normalizedPath,
    ).toString();
  }

  String _stripTrailingDeepSeekBeta(String baseUrl) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/beta')) {
      return trimmed.substring(0, trimmed.length - 5);
    }
    return trimmed;
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

  int? _parseInt(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  Uri _resolveRequestUri({
    required String baseUrl,
    required String requestPath,
  }) {
    final normalizedBase = baseUrl.trim();
    if (normalizedBase.isEmpty) {
      throw StateError('Base URL 不能为空');
    }
    final baseUri = Uri.tryParse(normalizedBase);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      throw StateError('Base URL 不是合法地址: $baseUrl');
    }

    final normalizedRequestPath = requestPath.trim();
    if (normalizedRequestPath.isEmpty) {
      return baseUri.replace(pathSegments: _splitPathSegments(baseUri.path));
    }

    final absoluteRequestUri = _parseAbsoluteUriOrNull(normalizedRequestPath);
    if (absoluteRequestUri != null) {
      return absoluteRequestUri.replace(
        pathSegments: _splitPathSegments(absoluteRequestUri.path),
      );
    }

    final relativeRequestUri = Uri.tryParse(
      normalizedRequestPath.startsWith('/')
          ? normalizedRequestPath
          : '/$normalizedRequestPath',
    );
    if (relativeRequestUri == null) {
      throw StateError('Request Path 不是合法路径: $requestPath');
    }

    final mergedSegments = _mergePathSegments(
      _splitPathSegments(baseUri.path),
      _splitPathSegments(relativeRequestUri.path),
    );
    return baseUri.replace(
      pathSegments: mergedSegments,
      query: relativeRequestUri.hasQuery ? relativeRequestUri.query : null,
      fragment: relativeRequestUri.fragment.isNotEmpty
          ? relativeRequestUri.fragment
          : null,
    );
  }

  Uri? _parseAbsoluteUriOrNull(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  List<String> _splitPathSegments(String path) {
    return path
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _mergePathSegments(
    List<String> baseSegments,
    List<String> requestSegments,
  ) {
    if (requestSegments.isEmpty) {
      return baseSegments;
    }
    var overlap = 0;
    final maxOverlap = baseSegments.length < requestSegments.length
        ? baseSegments.length
        : requestSegments.length;
    for (var size = maxOverlap; size > 0; size--) {
      final baseSlice = baseSegments.sublist(baseSegments.length - size);
      final requestSlice = requestSegments.sublist(0, size);
      var matched = true;
      for (var index = 0; index < size; index++) {
        if (baseSlice[index] != requestSlice[index]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        overlap = size;
        break;
      }
    }
    return <String>[...baseSegments, ...requestSegments.sublist(overlap)];
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
