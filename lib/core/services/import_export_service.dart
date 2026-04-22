import 'dart:convert';
import 'dart:io';

import '../bridge/frb_api.dart' as frb;
import '../models/import_export_models.dart';
import '../models/workspace_config.dart';
import '../providers/app_state.dart';
import 'api_service.dart';
import 'chat_service.dart';
import 'world_book_injection.dart';

const String worldBookImportSourceFieldKey = 'worldbook_import_source';
const String worldBookCharacterCardImagePathFieldKey =
    'worldbook_character_card_image_path';
const String worldBookCharacterCardJsonFieldKey =
    'worldbook_character_card_json';

class ImportExportService {
  ImportExportService({
    required ApiService apiService,
    required ChatService chatService,
  }) : _apiService = apiService,
       _chatService = chatService;

  final ApiService _apiService;
  final ChatService _chatService;

  Future<void> exportPresetToFile({
    required StoredPresetConfig preset,
    required String outputPath,
  }) async {
    await _writeJsonFile(outputPath, <String, dynamic>{
      'format': 'rst',
      'type': 'preset',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceApp': 'RST',
      'item': preset.toJson(),
    });
  }

  Future<ImportResult<StoredPresetConfig>> importPresetFromFile({
    required String filePath,
    required Iterable<StoredPresetConfig> existingPresets,
  }) async {
    final decoded = await _readJsonObjectFile(filePath);
    final warnings = <ImportWarning>[];
    final raw = _extractWrappedItem(decoded, expectedType: 'preset') ?? decoded;
    final imported = StoredPresetConfig.fromJson(raw);
    final presetIds = existingPresets.map((item) => item.presetId).toSet();
    final presetNames = existingPresets.map((item) => item.name).toSet();
    final resolvedId =
        imported.presetId.trim().isEmpty ||
            presetIds.contains(imported.presetId.trim())
        ? _newId('preset')
        : imported.presetId.trim();
    if (resolvedId != imported.presetId.trim()) {
      warnings.add(
        const ImportWarning(code: 'preset_id_reassigned', message: '已生成新预设 ID'),
      );
    }
    final baseName = imported.name.trim().isEmpty
        ? '导入预设'
        : imported.name.trim();
    final resolvedName = _uniqueName(baseName, presetNames);
    if (resolvedName != baseName) {
      warnings.add(
        ImportWarning(
          code: 'preset_name_renamed',
          message: '名称冲突，已重命名为“$resolvedName”',
        ),
      );
    }
    return ImportResult<StoredPresetConfig>(
      value: imported.copyWith(
        presetId: resolvedId,
        name: resolvedName,
        updatedAt: DateTime.now().toUtc(),
      ),
      warnings: warnings,
    );
  }

  Future<void> exportAppearanceToFile({
    required ManagedOption appearance,
    required String outputPath,
  }) async {
    await _writeJsonFile(outputPath, <String, dynamic>{
      'format': 'rst',
      'type': 'appearance',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceApp': 'RST',
      'item': _apiService.managedOptionToJson(appearance),
    });
  }

  Future<ImportResult<ManagedOption>> importAppearanceFromFile({
    required String filePath,
    required Iterable<ManagedOption> existingOptions,
  }) async {
    final decoded = await _readJsonObjectFile(filePath);
    final warnings = <ImportWarning>[];
    final raw =
        _extractWrappedItem(decoded, expectedType: 'appearance') ?? decoded;
    final imported = _apiService.managedOptionFromJson(raw);
    final sanitized = _sanitizeAppearanceOption(imported, warnings: warnings);
    final ids = existingOptions.map((item) => item.id).toSet();
    final names = existingOptions.map((item) => item.name).toSet();
    final resolvedId =
        sanitized.id.trim().isEmpty || ids.contains(sanitized.id.trim())
        ? _newId('appearance')
        : sanitized.id.trim();
    if (resolvedId != sanitized.id.trim()) {
      warnings.add(
        const ImportWarning(
          code: 'appearance_id_reassigned',
          message: '已生成新外观 ID',
        ),
      );
    }
    final baseName = sanitized.name.trim().isEmpty
        ? '导入外观'
        : sanitized.name.trim();
    final resolvedName = _uniqueName(baseName, names);
    if (resolvedName != baseName) {
      warnings.add(
        ImportWarning(
          code: 'appearance_name_renamed',
          message: '名称冲突，已重命名为“$resolvedName”',
        ),
      );
    }
    return ImportResult<ManagedOption>(
      value: sanitized.copyWith(
        id: resolvedId,
        name: resolvedName,
        updatedAt: DateTime.now().toUtc(),
      ),
      warnings: warnings,
    );
  }

  Future<void> exportWorldBookToFile({
    required ManagedOption worldBook,
    required String outputPath,
  }) async {
    await _writeJsonFile(outputPath, <String, dynamic>{
      'format': 'rst',
      'type': 'worldbook',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceApp': 'RST',
      'item': _apiService.managedOptionToJson(worldBook),
    });
  }

  Future<WorldBookImportProbe> probeWorldBookImportFile(String filePath) async {
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      final card = await _tryReadCharacterCardFromPng(filePath);
      if (card == null) {
        return const WorldBookImportProbe(
          kind: WorldBookImportSourceKind.unsupported,
        );
      }
      return WorldBookImportProbe(
        kind: WorldBookImportSourceKind.stCharacterCardPng,
        detectedName: card.displayName,
        attachedCharacterBookEntryCount: card.characterBookEntries.length,
      );
    }

    final decoded = await _tryReadJsonObjectFile(filePath);
    if (decoded == null) {
      return const WorldBookImportProbe(
        kind: WorldBookImportSourceKind.unsupported,
      );
    }

    final wrapped = _extractWrappedItem(decoded, expectedType: 'worldbook');
    if (wrapped != null ||
        _looksLikeManagedOption(decoded, ManagedOptionType.worldBook)) {
      final option = _apiService.managedOptionFromJson(wrapped ?? decoded);
      return WorldBookImportProbe(
        kind: WorldBookImportSourceKind.rstWorldBook,
        detectedName: option.name,
      );
    }

    final card = _tryReadCharacterCardFromJson(decoded);
    if (card != null) {
      return WorldBookImportProbe(
        kind: WorldBookImportSourceKind.stCharacterCardJson,
        detectedName: card.displayName,
        attachedCharacterBookEntryCount: card.characterBookEntries.length,
      );
    }

    if (_looksLikeStWorldInfo(decoded)) {
      return WorldBookImportProbe(
        kind: WorldBookImportSourceKind.stWorldInfo,
        detectedName: _readStWorldBookName(decoded),
      );
    }

    return const WorldBookImportProbe(
      kind: WorldBookImportSourceKind.unsupported,
    );
  }

  Future<ImportResult<ManagedOption>> importWorldBookFromFile({
    required String filePath,
    required Iterable<ManagedOption> existingOptions,
    StoredApiConfig? classificationApiConfig,
  }) async {
    final probe = await probeWorldBookImportFile(filePath);
    switch (probe.kind) {
      case WorldBookImportSourceKind.rstWorldBook:
        return _importRstWorldBook(
          filePath: filePath,
          existingOptions: existingOptions,
        );
      case WorldBookImportSourceKind.stWorldInfo:
        return _importStWorldInfo(
          filePath: filePath,
          existingOptions: existingOptions,
        );
      case WorldBookImportSourceKind.stCharacterCardJson:
        return _importCharacterCardFromJsonFile(
          filePath: filePath,
          existingOptions: existingOptions,
          classificationApiConfig: classificationApiConfig,
        );
      case WorldBookImportSourceKind.stCharacterCardPng:
        return _importCharacterCardFromPngFile(
          filePath: filePath,
          existingOptions: existingOptions,
          classificationApiConfig: classificationApiConfig,
        );
      case WorldBookImportSourceKind.unsupported:
        throw StateError('unsupported_worldbook_import_file');
    }
  }

  Future<void> exportSessionToFile({
    required String sessionId,
    required String outputPath,
  }) async {
    final rawSession = await _apiService.readSessionDocument(sessionId);
    if (rawSession == null) {
      throw StateError('session_not_found: $sessionId');
    }
    final metadata = await _apiService.loadSessionMetadata(sessionId);
    final snapshot = await _apiService.loadSessionWorldBookSnapshot(
      sessionId: sessionId,
    );
    await _writeJsonFile(outputPath, <String, dynamic>{
      'format': 'rst',
      'type': 'session',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceApp': 'RST',
      'session': rawSession,
      'metadata': metadata?.toJson(),
      'worldBookSnapshot': snapshot?.toJson(),
    });
  }

  Future<ImportResult<frb.SessionConfig>> importSessionFromFile({
    required String filePath,
    required Iterable<frb.SessionSummary> existingSessions,
  }) async {
    final decoded = await _readJsonObjectFile(filePath);
    final warnings = <ImportWarning>[];
    final sessionDoc = _extractWrappedSession(decoded) ?? decoded;
    final metadataMap = _extractMap(decoded['metadata']);
    final snapshotMap =
        _extractMap(decoded['worldBookSnapshot']) ??
        _extractMap(decoded['snapshot']);
    final imported = _normalizeImportedSession(
      sessionDoc,
      existingSessions: existingSessions,
      warnings: warnings,
    );

    await _apiService.writeSessionDocument(
      sessionId: imported.config.sessionId,
      document: imported.document,
    );
    await _apiService.saveSessionMetadata(
      sessionId: imported.config.sessionId,
      metadata: metadataMap == null
          ? _defaultSessionMetadata(imported.config.mode)
          : SessionStoredMetadata.fromJson(metadataMap),
    );
    if (snapshotMap != null &&
        imported.config.mode == frb.SessionMode.st &&
        '${snapshotMap['worldBookJson'] ?? ''}'.trim().isNotEmpty) {
      final snapshot = SessionWorldBookSnapshotData.fromJson(snapshotMap);
      await _apiService.writeSessionWorldBookSnapshot(
        sessionId: imported.config.sessionId,
        sourceWorldBookId: snapshot.sourceWorldBookId,
        sourceWorldBookName: snapshot.sourceWorldBookName,
        worldBookJson: snapshot.worldBookJson,
      );
    } else {
      await _apiService.deleteSessionWorldBookSnapshot(
        sessionId: imported.config.sessionId,
      );
    }

    return ImportResult<frb.SessionConfig>(
      value: imported.config,
      warnings: warnings,
    );
  }

  Future<ImportResult<ManagedOption>> _importRstWorldBook({
    required String filePath,
    required Iterable<ManagedOption> existingOptions,
  }) async {
    final decoded = await _readJsonObjectFile(filePath);
    final raw =
        _extractWrappedItem(decoded, expectedType: 'worldbook') ?? decoded;
    final imported = _apiService.managedOptionFromJson(raw);
    final warnings = <ImportWarning>[];
    if (imported.type != ManagedOptionType.worldBook) {
      throw StateError('imported_file_is_not_worldbook');
    }
    return ImportResult<ManagedOption>(
      value: _resolveWorldBookConflicts(
        imported,
        existingOptions: existingOptions,
        warnings: warnings,
      ),
      warnings: warnings,
    );
  }

  Future<ImportResult<ManagedOption>> _importStWorldInfo({
    required String filePath,
    required Iterable<ManagedOption> existingOptions,
  }) async {
    final decoded = await _readJsonObjectFile(filePath);
    final warnings = <ImportWarning>[];
    final entries = _extractStEntries(decoded, warnings: warnings);
    final scanDepth = _readScanDepth(decoded);
    final name = _readStWorldBookName(decoded) ?? _fileBaseName(filePath);
    final option = _buildWorldBookOption(
      id: _newId('wb'),
      name: name.trim().isEmpty ? '导入世界书' : name.trim(),
      description: '从 SillyTavern 世界书导入',
      entries: entries,
      categories: _buildWorldBookCategories(entries),
      scanDepth: scanDepth,
      additionalFields: <String, String>{
        worldBookImportSourceFieldKey: 'st_world_info',
      },
    );
    return ImportResult<ManagedOption>(
      value: _resolveWorldBookConflicts(
        option,
        existingOptions: existingOptions,
        warnings: warnings,
      ),
      warnings: warnings,
    );
  }

  Future<ImportResult<ManagedOption>> _importCharacterCardFromJsonFile({
    required String filePath,
    required Iterable<ManagedOption> existingOptions,
    StoredApiConfig? classificationApiConfig,
  }) async {
    final decoded = await _readJsonObjectFile(filePath);
    final card = _tryReadCharacterCardFromJson(decoded);
    if (card == null) {
      throw StateError('invalid_character_card_json');
    }
    return _buildWorldBookFromCharacterCard(
      card: card,
      sourcePath: filePath,
      existingOptions: existingOptions,
      classificationApiConfig: classificationApiConfig,
    );
  }

  Future<ImportResult<ManagedOption>> _importCharacterCardFromPngFile({
    required String filePath,
    required Iterable<ManagedOption> existingOptions,
    StoredApiConfig? classificationApiConfig,
  }) async {
    final card = await _tryReadCharacterCardFromPng(filePath);
    if (card == null) {
      throw StateError('invalid_character_card_png');
    }
    return _buildWorldBookFromCharacterCard(
      card: card,
      sourcePath: filePath,
      existingOptions: existingOptions,
      classificationApiConfig: classificationApiConfig,
    );
  }

  Future<ImportResult<ManagedOption>> _buildWorldBookFromCharacterCard({
    required _CharacterCardData card,
    required String sourcePath,
    required Iterable<ManagedOption> existingOptions,
    StoredApiConfig? classificationApiConfig,
  }) async {
    final warnings = <ImportWarning>[];
    final baseName = card.displayName.trim().isEmpty
        ? '导入角色卡'
        : card.displayName.trim();
    final ids = existingOptions.map((item) => item.id).toSet();
    final names = existingOptions.map((item) => item.name).toSet();
    final suggestedId = card.suggestedId;
    final worldBookId = ids.contains(suggestedId) ? _newId('wb') : suggestedId;
    final worldBookName = _uniqueName(baseName, names);
    if (worldBookName != baseName) {
      warnings.add(
        ImportWarning(
          code: 'worldbook_name_renamed',
          message: '名称冲突，已重命名为“$worldBookName”',
        ),
      );
    }

    final entries = <Map<String, dynamic>>[];
    final categories = <String, String>{};

    final mainEntry = _buildCharacterMainEntry(card, displayIndex: 0);
    entries.add(mainEntry);
    categories['${mainEntry['uid']}'] = _WorldBookUiCategory.character.name;

    final classifiedEntries = await _classifyCharacterBookEntries(
      entries: card.characterBookEntries,
      apiConfig: classificationApiConfig,
      warnings: warnings,
    );

    final normalizedClassifiedEntries = _ensureCategorizedEntriesAvoidUids(
      classifiedEntries,
      usedUids: <int>{_asInt(mainEntry['uid'])},
    );

    for (
      var index = 0;
      index < normalizedClassifiedEntries.length;
      index += 1
    ) {
      final item = normalizedClassifiedEntries[index];
      final entry = Map<String, dynamic>.from(item.entry);
      entry['displayIndex'] = index + 1;
      entries.add(entry);
      categories['${entry['uid']}'] = item.category.name;
    }

    final extraFields = <String, String>{
      worldBookImportSourceFieldKey: card.sourceKind,
      worldBookCharacterCardJsonFieldKey: jsonEncode(card.rawJson),
    };
    if (card.sourceKind == 'st_character_card_png') {
      final copiedImage = await _copyCharacterCardImage(
        sourcePath: sourcePath,
        targetId: worldBookId,
      );
      extraFields[worldBookCharacterCardImagePathFieldKey] = copiedImage;
    }

    final option = _buildWorldBookOption(
      id: worldBookId,
      name: worldBookName,
      description: '从 SillyTavern 角色卡导入',
      entries: entries,
      categories: categories,
      scanDepth: card.scanDepth,
      additionalFields: extraFields,
    );
    return ImportResult<ManagedOption>(value: option, warnings: warnings);
  }

  Future<List<_CategorizedEntry>> _classifyCharacterBookEntries({
    required List<Map<String, dynamic>> entries,
    required StoredApiConfig? apiConfig,
    required List<ImportWarning> warnings,
  }) async {
    if (entries.isEmpty) {
      return const <_CategorizedEntry>[];
    }

    final fallback = entries
        .map(
          (entry) => _CategorizedEntry(
            entry: entry,
            category: _classifyEntryByRule(entry),
          ),
        )
        .toList(growable: false);
    if (apiConfig == null) {
      return fallback;
    }

    try {
      final runtimeConfig = _apiService.toRuntimeApiConfig(apiConfig);
      final prompt = _buildClassificationPrompt(entries);
      final response = await _chatService.generateUtilityText(
        apiConfig: runtimeConfig,
        messages: <Map<String, String>>[
          const <String, String>{
            'role': 'system',
            'content': '你负责把世界书条目分到 character 或 setting。只返回 JSON，不要输出解释。',
          },
          <String, String>{'role': 'user', 'content': prompt},
        ],
      );
      final parsed = _extractJsonObjectFromText(response);
      if (parsed == null) {
        throw StateError('invalid_classification_response');
      }
      final items = parsed['items'];
      if (items is! List) {
        throw StateError('invalid_classification_items');
      }
      final categoryByUid = <int, _WorldBookUiCategory>{};
      for (final item in items) {
        if (item is! Map) {
          continue;
        }
        final uid = _asInt(item['uid']);
        categoryByUid[uid] = _categoryFromClassificationWire(item['category']);
      }
      return entries
          .map(
            (entry) => _CategorizedEntry(
              entry: entry,
              category:
                  categoryByUid[_asInt(entry['uid'])] ??
                  _classifyEntryByRule(entry),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      warnings.add(
        const ImportWarning(
          code: 'classification_fallback',
          message: 'LLM 分类失败，已回退到规则分类',
        ),
      );
      return fallback;
    }
  }

  String _buildClassificationPrompt(List<Map<String, dynamic>> entries) {
    final payload = <Map<String, Object?>>[];
    for (final entry in entries) {
      payload.add(<String, Object?>{
        'uid': _asInt(entry['uid']),
        'comment': '${entry['comment'] ?? ''}',
        'key': _stringList(entry['key']),
        'content': _truncate('${entry['content'] ?? ''}', 1200),
      });
    }
    return jsonEncode(<String, Object?>{
      'task': '把每个条目分成 character 或 setting。',
      'rules': const <String>[
        '人物身份、外貌、性格、关系、口吻、背景经历归类为 character',
        '地点、组织、制度、历史、世界规则、物品、事件归类为 setting',
      ],
      'return': <String, Object?>{
        'items': const <Map<String, Object?>>[
          <String, Object?>{'uid': 1, 'category': 'character'},
        ],
      },
      'entries': payload,
    });
  }

  ManagedOption _resolveWorldBookConflicts(
    ManagedOption option, {
    required Iterable<ManagedOption> existingOptions,
    required List<ImportWarning> warnings,
  }) {
    final ids = existingOptions.map((item) => item.id).toSet();
    final names = existingOptions.map((item) => item.name).toSet();
    final resolvedId =
        option.id.trim().isEmpty || ids.contains(option.id.trim())
        ? _newId('wb')
        : option.id.trim();
    if (resolvedId != option.id.trim()) {
      warnings.add(
        const ImportWarning(
          code: 'worldbook_id_reassigned',
          message: '已生成新世界书 ID',
        ),
      );
    }
    final baseName = option.name.trim().isEmpty ? '导入世界书' : option.name.trim();
    final resolvedName = _uniqueName(baseName, names);
    if (resolvedName != baseName) {
      warnings.add(
        ImportWarning(
          code: 'worldbook_name_renamed',
          message: '名称冲突，已重命名为“$resolvedName”',
        ),
      );
    }
    return option.copyWith(
      id: resolvedId,
      name: resolvedName,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  ManagedOption _sanitizeAppearanceOption(
    ManagedOption imported, {
    required List<ImportWarning> warnings,
  }) {
    final requestedTheme = '${imported.fieldValue('theme_mode') ?? 'dark'}'
        .trim();
    final themeMode = requestedTheme == 'light' ? 'light' : 'dark';
    if (requestedTheme != 'dark' && requestedTheme != 'light') {
      warnings.add(
        const ImportWarning(
          code: 'appearance_theme_fallback',
          message: '非法主题模式已回退到默认值',
        ),
      );
    }
    final fallback = buildAppearanceOptionTemplate(
      id: imported.id.trim().isEmpty
          ? _newId('appearance')
          : imported.id.trim(),
      name: imported.name.trim().isEmpty ? '导入外观' : imported.name.trim(),
      description: imported.description,
      themeMode: themeMode,
    );
    final importedFields = <String, ManagedOptionField>{};
    for (final section in imported.sections) {
      for (final field in section.fields) {
        importedFields[field.key] = field;
      }
    }

    final nextSections = fallback.sections
        .map(
          (section) => section.copyWith(
            fields: section.fields
                .map((field) {
                  final importedField = importedFields[field.key];
                  if (importedField == null) {
                    return field;
                  }
                  final sanitizedValue = _sanitizeAppearanceFieldValue(
                    templateField: field,
                    incoming: importedField.value,
                    warnings: warnings,
                  );
                  return field.copyWith(
                    value: sanitizedValue,
                    replaceValue: true,
                  );
                })
                .toList(growable: false),
          ),
        )
        .toList(growable: true);

    final knownKeys = <String>{
      for (final section in fallback.sections)
        for (final field in section.fields) field.key,
    };
    for (final section in imported.sections) {
      final extras = section.fields
          .where((field) => !knownKeys.contains(field.key))
          .toList(growable: false);
      if (extras.isEmpty) {
        continue;
      }
      nextSections.add(
        ManagedOptionSection(
          title: section.title,
          description: section.description,
          fields: extras,
        ),
      );
    }

    return imported.copyWith(
      type: ManagedOptionType.appearance,
      sections: nextSections,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Object? _sanitizeAppearanceFieldValue({
    required ManagedOptionField templateField,
    required Object? incoming,
    required List<ImportWarning> warnings,
  }) {
    switch (templateField.type) {
      case ManagedFieldType.toggle:
        final parsed = _parseBool(incoming);
        if (parsed == null) {
          warnings.add(
            ImportWarning(
              code: 'appearance_toggle_fallback',
              message: '${templateField.key} 已回退默认值',
            ),
          );
          return templateField.value;
        }
        return parsed;
      case ManagedFieldType.integer:
        final parsed = _parseInt(incoming);
        if (parsed == null) {
          warnings.add(
            ImportWarning(
              code: 'appearance_integer_fallback',
              message: '${templateField.key} 已回退默认值',
            ),
          );
          return templateField.value;
        }
        return parsed;
      case ManagedFieldType.decimal:
        final parsed = _parseDouble(incoming);
        if (parsed == null) {
          warnings.add(
            ImportWarning(
              code: 'appearance_decimal_fallback',
              message: '${templateField.key} 已回退默认值',
            ),
          );
          return templateField.value;
        }
        return parsed;
      case ManagedFieldType.select:
        final normalized = '${incoming ?? ''}'.trim();
        if (normalized.isEmpty ||
            !templateField.choices.any(
              (choice) => choice.value == normalized,
            )) {
          warnings.add(
            ImportWarning(
              code: 'appearance_choice_fallback',
              message: '${templateField.key} 已回退默认值',
            ),
          );
          return templateField.value;
        }
        return normalized;
      case ManagedFieldType.color:
        final normalized = '${incoming ?? ''}'.trim();
        if (!_isHexColor(normalized)) {
          warnings.add(
            ImportWarning(
              code: 'appearance_color_fallback',
              message: '${templateField.key} 颜色非法，已回退默认值',
            ),
          );
          return templateField.value;
        }
        return normalized.toUpperCase();
      case ManagedFieldType.text:
      case ManagedFieldType.multiline:
        return '${incoming ?? ''}';
    }
  }

  ManagedOption _buildWorldBookOption({
    required String id,
    required String name,
    required String description,
    required List<Map<String, dynamic>> entries,
    required Map<String, String> categories,
    required int scanDepth,
    Map<String, String> additionalFields = const <String, String>{},
  }) {
    var sections = buildManagedOptionTemplate(
      ManagedOptionType.worldBook,
      id: id,
      name: name,
      description: description,
    ).sections;
    final encodedEntries = <String, dynamic>{};
    for (var index = 0; index < entries.length; index += 1) {
      final entry = Map<String, dynamic>.from(entries[index]);
      entry['displayIndex'] = index;
      encodedEntries['${_asInt(entry['uid'])}'] = entry;
    }
    sections = _upsertField(
      sections,
      worldBookJsonFieldKey,
      jsonEncode(<String, dynamic>{'entries': encodedEntries}),
    );
    sections = _upsertField(
      sections,
      worldBookCategoryFieldKey,
      jsonEncode(categories),
    );
    sections = _upsertField(
      sections,
      worldBookScanDepthFieldKey,
      '${scanDepth.clamp(0, 2048)}',
    );
    for (final entry in additionalFields.entries) {
      sections = _upsertField(sections, entry.key, entry.value);
    }
    return ManagedOption(
      id: id,
      name: name,
      description: description,
      updatedAt: DateTime.now().toUtc(),
      type: ManagedOptionType.worldBook,
      sections: sections,
    );
  }

  Map<String, String> _buildWorldBookCategories(
    List<Map<String, dynamic>> entries,
  ) {
    final categories = <String, String>{};
    for (final entry in entries) {
      categories['${_asInt(entry['uid'])}'] = _classifyEntryByRule(entry).name;
    }
    return categories;
  }

  Future<String> _copyCharacterCardImage({
    required String sourcePath,
    required String targetId,
  }) async {
    final assetsDir = Directory(
      '${(await _apiService.worldBookAssetsDirectory()).path}/character_cards',
    );
    if (!assetsDir.existsSync()) {
      assetsDir.createSync(recursive: true);
    }
    final target = File('${assetsDir.path}/$targetId.png');
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  _ImportedSession _normalizeImportedSession(
    Map<String, dynamic> source, {
    required Iterable<frb.SessionSummary> existingSessions,
    required List<ImportWarning> warnings,
  }) {
    final configMap = _extractMap(source['config']);
    if (configMap == null) {
      throw StateError('session_import_missing_config');
    }
    final runtimeMap = _extractMap(source['runtime']) ?? <String, dynamic>{};
    final rawMessages = source['messages'];
    final now = DateTime.now().toUtc().toIso8601String();
    final existingNames = existingSessions
        .map((item) => item.sessionName)
        .toSet();
    final sessionId = _newId('session');
    final sourceName = '${configMap['sessionName'] ?? '导入会话'}'.trim();
    final sessionName = _uniqueName(
      sourceName.isEmpty ? '导入会话' : sourceName,
      existingNames,
    );
    if (sessionName != sourceName.trim()) {
      warnings.add(
        ImportWarning(
          code: 'session_name_renamed',
          message: '名称冲突，已重命名为“$sessionName”',
        ),
      );
    }

    final mode = _sessionModeFromImport(
      configMap['mode'],
      stWorldBookId: configMap['stWorldBookId'],
      warnings: warnings,
    );
    final messageResult = _normalizeImportedMessages(
      rawMessages,
      sessionId: sessionId,
      warnings: warnings,
    );
    final mappedActiveMessageId = runtimeMap['activeMessageId'] == null
        ? null
        : messageResult.messageIdMap['${runtimeMap['activeMessageId']}'];
    final streamingStatus = _streamingStatusFromWire(
      runtimeMap['streamingStatus'],
    );
    final runtimeStatus =
        mappedActiveMessageId == null &&
            streamingStatus == frb.StreamingStatus.receiving
        ? frb.StreamingStatus.idle
        : streamingStatus;

    final config = frb.SessionConfig(
      sessionId: sessionId,
      sessionName: sessionName,
      mode: mode,
      mainApiConfigId: '${configMap['mainApiConfigId'] ?? ''}'.trim(),
      presetId: '${configMap['presetId'] ?? ''}'.trim(),
      stWorldBookId: mode == frb.SessionMode.st
          ? _normalizeOptionalString(configMap['stWorldBookId'])
          : null,
      createdAt: _normalizeDateTimeString(
        configMap['createdAt'],
        fallback: now,
      ),
      updatedAt: _normalizeDateTimeString(
        configMap['updatedAt'],
        fallback: now,
      ),
    );

    final document = <String, dynamic>{
      'config': <String, dynamic>{
        'sessionId': config.sessionId,
        'sessionName': config.sessionName,
        'mode': config.mode.name,
        'mainApiConfigId': config.mainApiConfigId,
        'presetId': config.presetId,
        'stWorldBookId': config.stWorldBookId,
        'createdAt': config.createdAt,
        'updatedAt': config.updatedAt,
      },
      'runtime': <String, dynamic>{
        'sessionId': sessionId,
        'activeMessageId': mappedActiveMessageId,
        'streamingStatus': runtimeStatus.name,
        'lastError': _normalizeOptionalString(runtimeMap['lastError']),
        'lastPromptTokenEstimate': _parseInt(
          runtimeMap['lastPromptTokenEstimate'],
        ),
        'lastCompletionTokenEstimate': _parseInt(
          runtimeMap['lastCompletionTokenEstimate'],
        ),
        'lastUsedModel': _normalizeOptionalString(runtimeMap['lastUsedModel']),
        'lastRequestStartedAt': _normalizeOptionalString(
          runtimeMap['lastRequestStartedAt'],
        ),
        'lastRequestFinishedAt': _normalizeOptionalString(
          runtimeMap['lastRequestFinishedAt'],
        ),
        'updatedAt': _normalizeDateTimeString(
          runtimeMap['updatedAt'],
          fallback: now,
        ),
      },
      'messages': messageResult.messages,
    };

    return _ImportedSession(config: config, document: document);
  }

  _NormalizedMessages _normalizeImportedMessages(
    Object? rawMessages, {
    required String sessionId,
    required List<ImportWarning> warnings,
  }) {
    if (rawMessages is! List) {
      warnings.add(
        const ImportWarning(
          code: 'session_messages_missing',
          message: '消息列表缺失，已按空会话导入',
        ),
      );
      return const _NormalizedMessages(messages: <Map<String, dynamic>>[]);
    }

    final messages = <Map<String, dynamic>>[];
    final messageIdMap = <String, String>{};
    var floor = 0;
    for (var index = 0; index < rawMessages.length; index += 1) {
      final raw = rawMessages[index];
      if (raw is! Map) {
        warnings.add(
          ImportWarning(
            code: 'session_message_skipped',
            message: '第 ${index + 1} 条消息损坏，已跳过',
          ),
        );
        continue;
      }
      final role = _messageRoleFromWire(raw['role']);
      if (role == null) {
        warnings.add(
          ImportWarning(
            code: 'session_message_skipped',
            message: '第 ${index + 1} 条消息 role 无法识别，已跳过',
          ),
        );
        continue;
      }
      final newMessageId = _newId('message');
      final oldMessageId = '${raw['messageId'] ?? ''}'.trim();
      if (oldMessageId.isNotEmpty) {
        messageIdMap[oldMessageId] = newMessageId;
      }
      final hasFloor =
          role == frb.MessageRole.user || role == frb.MessageRole.assistant;
      messages.add(<String, dynamic>{
        'messageId': newMessageId,
        'sessionId': sessionId,
        'role': role.name,
        'floorNo': hasFloor ? floor++ : null,
        'content': '${raw['content'] ?? ''}',
        'visible': _parseBool(raw['visible']) ?? true,
        'status': _messageStatusFromWire(raw['status']).name,
        'errorMessage': _normalizeOptionalString(raw['errorMessage']),
        'createdAt': _normalizeDateTimeString(raw['createdAt']),
        'updatedAt': _normalizeDateTimeString(raw['updatedAt']),
      });
    }
    return _NormalizedMessages(messages: messages, messageIdMap: messageIdMap);
  }

  SessionStoredMetadata _defaultSessionMetadata(frb.SessionMode mode) {
    return SessionStoredMetadata(
      schedulerMode: mode == frb.SessionMode.rst
          ? SchedulerMode.rst.name
          : SchedulerMode.sillyTavern.name,
      appearanceId: 'appearance-default',
      backgroundImagePath: '',
      userDescription: '',
      scene: '',
      lores: '',
    );
  }

  _CharacterCardData? _tryReadCharacterCardFromJson(Map<String, dynamic> json) {
    final cardRoot = _extractCharacterCardRoot(json);
    if (cardRoot == null) {
      return null;
    }
    final bookRoot =
        _extractMap(cardRoot['character_book']) ??
        _extractMap(cardRoot['characterBook']);
    return _CharacterCardData(
      rawJson: json,
      sourceKind: 'st_character_card_json',
      displayName: '${cardRoot['name'] ?? ''}'.trim(),
      description: '${cardRoot['description'] ?? ''}',
      personality: '${cardRoot['personality'] ?? ''}',
      scenario: '${cardRoot['scenario'] ?? ''}',
      firstMes: '${cardRoot['first_mes'] ?? cardRoot['firstMes'] ?? ''}',
      mesExample: '${cardRoot['mes_example'] ?? cardRoot['mesExample'] ?? ''}',
      creatorNotes:
          '${cardRoot['creator_notes'] ?? cardRoot['creatorNotes'] ?? ''}',
      systemPrompt:
          '${cardRoot['system_prompt'] ?? cardRoot['systemPrompt'] ?? ''}',
      postHistoryInstructions:
          '${cardRoot['post_history_instructions'] ?? cardRoot['postHistoryInstructions'] ?? ''}',
      alternateGreetings: _stringList(
        cardRoot['alternate_greetings'] ?? cardRoot['alternateGreetings'],
      ),
      characterBookEntries: bookRoot == null
          ? const <Map<String, dynamic>>[]
          : _extractStEntries(bookRoot, warnings: <ImportWarning>[]),
      scanDepth: _readScanDepth(bookRoot ?? cardRoot),
    );
  }

  Future<_CharacterCardData?> _tryReadCharacterCardFromPng(
    String filePath,
  ) async {
    final bytes = await File(filePath).readAsBytes();
    final rawCard = _extractCharacterCardJsonFromPng(bytes);
    if (rawCard == null) {
      return null;
    }
    final parsed = _tryReadCharacterCardFromJson(rawCard);
    if (parsed == null) {
      return null;
    }
    return parsed.copyWith(sourceKind: 'st_character_card_png');
  }

  Map<String, dynamic>? _extractCharacterCardJsonFromPng(List<int> bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < signature.length) {
      return null;
    }
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) {
        return null;
      }
    }

    final candidates = <String>[];
    var cursor = 8;
    while (cursor + 8 <= bytes.length) {
      final length = _readUint32(bytes, cursor);
      cursor += 4;
      if (cursor + 4 > bytes.length) {
        break;
      }
      final type = ascii.decode(bytes.sublist(cursor, cursor + 4));
      cursor += 4;
      if (cursor + length > bytes.length) {
        break;
      }
      final data = bytes.sublist(cursor, cursor + length);
      cursor += length;
      if (cursor + 4 > bytes.length) {
        break;
      }
      cursor += 4; // CRC

      switch (type) {
        case 'tEXt':
          final parsed = _parseTextChunk(data);
          if (parsed != null && _isCharacterCardChunkKey(parsed.$1)) {
            candidates.add(parsed.$2);
          }
          break;
        case 'zTXt':
          final parsed = _parseZTextChunk(data);
          if (parsed != null && _isCharacterCardChunkKey(parsed.$1)) {
            candidates.add(parsed.$2);
          }
          break;
        case 'iTXt':
          final parsed = _parseITextChunk(data);
          if (parsed != null && _isCharacterCardChunkKey(parsed.$1)) {
            candidates.add(parsed.$2);
          }
          break;
        default:
          break;
      }
    }

    for (final candidate in candidates) {
      final decoded = _decodeCharacterCardCandidate(candidate);
      if (decoded != null) {
        return decoded;
      }
    }
    return null;
  }

  (String, String)? _parseTextChunk(List<int> data) {
    final index = data.indexOf(0);
    if (index <= 0 || index >= data.length - 1) {
      return null;
    }
    final key = latin1.decode(data.sublist(0, index));
    final value = latin1.decode(data.sublist(index + 1));
    return (key, value);
  }

  (String, String)? _parseZTextChunk(List<int> data) {
    final index = data.indexOf(0);
    if (index <= 0 || index >= data.length - 2) {
      return null;
    }
    final key = latin1.decode(data.sublist(0, index));
    final compressed = data.sublist(index + 2);
    try {
      final value = utf8.decode(zlib.decode(compressed));
      return (key, value);
    } catch (_) {
      return null;
    }
  }

  (String, String)? _parseITextChunk(List<int> data) {
    var cursor = 0;
    final keywordEnd = data.indexOf(0, cursor);
    if (keywordEnd <= 0) {
      return null;
    }
    final key = latin1.decode(data.sublist(0, keywordEnd));
    cursor = keywordEnd + 1;
    if (cursor + 2 > data.length) {
      return null;
    }
    final compressed = data[cursor] == 1;
    cursor += 2;
    final languageEnd = data.indexOf(0, cursor);
    if (languageEnd < 0) {
      return null;
    }
    cursor = languageEnd + 1;
    final translatedEnd = data.indexOf(0, cursor);
    if (translatedEnd < 0) {
      return null;
    }
    cursor = translatedEnd + 1;
    if (cursor > data.length) {
      return null;
    }
    final textBytes = data.sublist(cursor);
    try {
      final value = compressed
          ? utf8.decode(zlib.decode(textBytes))
          : utf8.decode(textBytes);
      return (key, value);
    } catch (_) {
      return null;
    }
  }

  bool _isCharacterCardChunkKey(String raw) {
    final normalized = raw.trim().toLowerCase();
    return normalized == 'chara' ||
        normalized == 'ccv3' ||
        normalized == 'character';
  }

  Map<String, dynamic>? _decodeCharacterCardCandidate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final direct = _tryParseJsonObject(trimmed);
    if (direct != null && _extractCharacterCardRoot(direct) != null) {
      return direct;
    }
    final decodedBase64 = _tryDecodeBase64(trimmed);
    if (decodedBase64 == null) {
      return null;
    }
    final parsed = _tryParseJsonObject(decodedBase64);
    if (parsed != null && _extractCharacterCardRoot(parsed) != null) {
      return parsed;
    }
    return null;
  }

  Map<String, dynamic>? _extractCharacterCardRoot(Map<String, dynamic> json) {
    final direct = _extractMap(json['data']);
    if (json['spec'] != null && direct != null) {
      return direct;
    }
    final candidate = direct ?? json;
    final hasCharacterFields =
        '${candidate['name'] ?? ''}'.trim().isNotEmpty &&
        ('${candidate['description'] ?? ''}'.trim().isNotEmpty ||
            '${candidate['personality'] ?? ''}'.trim().isNotEmpty ||
            '${candidate['first_mes'] ?? candidate['firstMes'] ?? ''}'
                .trim()
                .isNotEmpty ||
            '${candidate['scenario'] ?? ''}'.trim().isNotEmpty);
    return hasCharacterFields ? candidate : null;
  }

  List<Map<String, dynamic>> _extractStEntries(
    Map<String, dynamic> json, {
    required List<ImportWarning> warnings,
  }) {
    final container = _extractStEntriesContainer(json);
    if (container == null) {
      throw StateError('st_worldbook_entries_missing');
    }
    final entries = <Map<String, dynamic>>[];
    if (container is Map) {
      var fallbackIndex = 0;
      for (final entry in container.entries) {
        final value = _extractMap(entry.value);
        if (value == null) {
          warnings.add(
            ImportWarning(
              code: 'worldbook_entry_skipped',
              message: '发现损坏条目，已跳过',
            ),
          );
          continue;
        }
        entries.add(
          _normalizeStEntry(
            value,
            fallbackUid: _parseInt(entry.key) ?? fallbackIndex,
          ),
        );
        fallbackIndex += 1;
      }
      return _ensureUniqueEntryUids(entries);
    }

    if (container is List) {
      for (var index = 0; index < container.length; index += 1) {
        final value = _extractMap(container[index]);
        if (value == null) {
          warnings.add(
            ImportWarning(
              code: 'worldbook_entry_skipped',
              message: '第 ${index + 1} 条数据损坏，已跳过',
            ),
          );
          continue;
        }
        entries.add(_normalizeStEntry(value, fallbackUid: index));
      }
      return _ensureUniqueEntryUids(entries);
    }

    throw StateError('st_worldbook_entries_invalid');
  }

  Object? _extractStEntriesContainer(Map<String, dynamic> json) {
    if (json['entries'] is Map || json['entries'] is List) {
      return json['entries'];
    }
    final worldInfo = _extractMap(json['world_info']);
    if (worldInfo != null &&
        (worldInfo['entries'] is Map || worldInfo['entries'] is List)) {
      return worldInfo['entries'];
    }
    final lorebook = _extractMap(json['lorebook']);
    if (lorebook != null &&
        (lorebook['entries'] is Map || lorebook['entries'] is List)) {
      return lorebook['entries'];
    }
    return null;
  }

  bool _looksLikeStWorldInfo(Map<String, dynamic> json) {
    return _extractStEntriesContainer(json) != null;
  }

  String? _readStWorldBookName(Map<String, dynamic> json) {
    final candidates = <Object?>[
      json['name'],
      json['title'],
      json['worldBookName'],
      _extractMap(json['world_info'])?['name'],
      _extractMap(json['lorebook'])?['name'],
    ];
    for (final candidate in candidates) {
      final normalized = '${candidate ?? ''}'.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeStEntry(
    Map<String, dynamic> raw, {
    required int fallbackUid,
  }) {
    final knownKeys = <String>{
      'uid',
      'id',
      'key',
      'keys',
      'keysecondary',
      'secondary_keys',
      'secondaryKeys',
      'comment',
      'name',
      'content',
      'constant',
      'vectorized',
      'selective',
      'selectiveLogic',
      'selective_logic',
      'addMemo',
      'add_memo',
      'order',
      'insertion_order',
      'insertionOrder',
      'position',
      'disable',
      'disabled',
      'enabled',
      'ignoreBudget',
      'ignore_budget',
      'excludeRecursion',
      'exclude_recursion',
      'preventRecursion',
      'prevent_recursion',
      'matchPersonaDescription',
      'matchCharacterDescription',
      'matchCharacterPersonality',
      'matchCharacterDepthPrompt',
      'matchScenario',
      'matchCreatorNotes',
      'delayUntilRecursion',
      'probability',
      'useProbability',
      'use_probability',
      'depth',
      'group',
      'groupOverride',
      'group_override',
      'groupWeight',
      'group_weight',
      'scanDepth',
      'scan_depth',
      'caseSensitive',
      'case_sensitive',
      'matchWholeWords',
      'match_whole_words',
      'useGroupScoring',
      'use_group_scoring',
      'automationId',
      'automation_id',
      'role',
      'sticky',
      'cooldown',
      'delay',
      'triggers',
      'displayIndex',
      'characterFilter',
      'character_filter',
    };
    final uid = _parseInt(raw['uid']) ?? _parseInt(raw['id']) ?? fallbackUid;
    final content = '${raw['content'] ?? ''}';
    final comment = '${raw['comment'] ?? raw['name'] ?? ''}'.trim();
    final enabled = _parseBool(raw['enabled']);
    final normalized = <String, dynamic>{
      'uid': uid,
      'key': _stringList(raw['key'] ?? raw['keys']),
      'keysecondary': _stringList(
        raw['keysecondary'] ?? raw['secondary_keys'] ?? raw['secondaryKeys'],
      ),
      'comment': comment.isEmpty ? '条目 $uid' : comment,
      'content': content,
      'constant': _parseBool(raw['constant']) ?? false,
      'vectorized': _parseBool(raw['vectorized']) ?? false,
      'selective': _parseBool(raw['selective']) ?? true,
      'selectiveLogic':
          _parseInt(raw['selectiveLogic'] ?? raw['selective_logic']) ?? 0,
      'addMemo': _parseBool(raw['addMemo'] ?? raw['add_memo']) ?? true,
      'order':
          _parseInt(
            raw['order'] ?? raw['insertion_order'] ?? raw['insertionOrder'],
          ) ??
          100,
      'position': _parsePosition(raw['position']),
      'disable': enabled == null
          ? (_parseBool(raw['disable'] ?? raw['disabled']) ?? false)
          : !enabled,
      'ignoreBudget':
          _parseBool(raw['ignoreBudget'] ?? raw['ignore_budget']) ?? false,
      'excludeRecursion':
          _parseBool(raw['excludeRecursion'] ?? raw['exclude_recursion']) ??
          false,
      'preventRecursion':
          _parseBool(raw['preventRecursion'] ?? raw['prevent_recursion']) ??
          false,
      'matchPersonaDescription':
          _parseBool(raw['matchPersonaDescription']) ?? false,
      'matchCharacterDescription':
          _parseBool(raw['matchCharacterDescription']) ?? false,
      'matchCharacterPersonality':
          _parseBool(raw['matchCharacterPersonality']) ?? false,
      'matchCharacterDepthPrompt':
          _parseBool(raw['matchCharacterDepthPrompt']) ?? false,
      'matchScenario': _parseBool(raw['matchScenario']) ?? false,
      'matchCreatorNotes': _parseBool(raw['matchCreatorNotes']) ?? false,
      'delayUntilRecursion': _parseBool(raw['delayUntilRecursion']) ?? false,
      'probability': (_parseInt(raw['probability']) ?? 100).clamp(0, 100),
      'useProbability':
          _parseBool(raw['useProbability'] ?? raw['use_probability']) ?? true,
      'depth': _parseInt(raw['depth']) ?? 4,
      'group': raw['group'] is List
          ? _stringList(raw['group']).join(', ')
          : '${raw['group'] ?? ''}',
      'groupOverride':
          _parseBool(raw['groupOverride'] ?? raw['group_override']) ?? false,
      'groupWeight':
          _parseInt(raw['groupWeight'] ?? raw['group_weight']) ?? 100,
      'scanDepth': _parseInt(raw['scanDepth'] ?? raw['scan_depth']),
      'caseSensitive': _parseNullableBool(
        raw['caseSensitive'] ?? raw['case_sensitive'],
      ),
      'matchWholeWords': _parseNullableBool(
        raw['matchWholeWords'] ?? raw['match_whole_words'],
      ),
      'useGroupScoring': _parseNullableBool(
        raw['useGroupScoring'] ?? raw['use_group_scoring'],
      ),
      'automationId': '${raw['automationId'] ?? raw['automation_id'] ?? ''}',
      'role': _normalizeOptionalString(raw['role']),
      'sticky': _parseInt(raw['sticky']) ?? 0,
      'cooldown': _parseInt(raw['cooldown']) ?? 0,
      'delay': _parseInt(raw['delay']) ?? 0,
      'triggers': _stringList(raw['triggers']),
      'displayIndex': _parseInt(raw['displayIndex']) ?? uid,
      'characterFilter':
          _extractMap(raw['characterFilter'] ?? raw['character_filter']) ??
          <String, dynamic>{
            'isExclude': false,
            'names': <String>[],
            'tags': <String>[],
          },
    };
    for (final entry in raw.entries) {
      if (!knownKeys.contains(entry.key)) {
        normalized[entry.key] = entry.value;
      }
    }
    return normalized;
  }

  List<Map<String, dynamic>> _ensureUniqueEntryUids(
    List<Map<String, dynamic>> entries,
  ) {
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
      if (used.contains(uid)) {
        maxUid += 1;
        uid = maxUid;
      }
      used.add(uid);
      next['uid'] = uid;
      normalized.add(next);
    }
    return normalized;
  }

  Map<String, dynamic> _buildCharacterMainEntry(
    _CharacterCardData card, {
    required int displayIndex,
  }) {
    final uid = 0;
    final contentBlocks = <String>[];
    void addBlock(String label, String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return;
      }
      contentBlocks.add('$label:\n$normalized');
    }

    addBlock('name', card.displayName);
    addBlock('description', card.description);
    addBlock('personality', card.personality);
    addBlock('scenario', card.scenario);
    addBlock('first_mes', card.firstMes);
    addBlock('mes_example', card.mesExample);
    addBlock('creator_notes', card.creatorNotes);
    addBlock('system_prompt', card.systemPrompt);
    addBlock('post_history_instructions', card.postHistoryInstructions);
    if (card.alternateGreetings.isNotEmpty) {
      addBlock('alternate_greetings', card.alternateGreetings.join('\n\n'));
    }

    return <String, dynamic>{
      'uid': uid,
      'key': card.displayName.trim().isEmpty
          ? const <String>[]
          : <String>[card.displayName.trim()],
      'keysecondary': const <String>[],
      'comment': card.displayName.trim().isEmpty
          ? '导入角色'
          : card.displayName.trim(),
      'content': contentBlocks.join('\n\n'),
      'constant': true,
      'vectorized': false,
      'selective': true,
      'selectiveLogic': 0,
      'addMemo': true,
      'order': 200,
      'position': 0,
      'disable': false,
      'ignoreBudget': false,
      'excludeRecursion': false,
      'preventRecursion': false,
      'matchPersonaDescription': false,
      'matchCharacterDescription': false,
      'matchCharacterPersonality': false,
      'matchCharacterDepthPrompt': false,
      'matchScenario': false,
      'matchCreatorNotes': false,
      'delayUntilRecursion': false,
      'probability': 100,
      'useProbability': true,
      'depth': 4,
      'group': '',
      'groupOverride': false,
      'groupWeight': 100,
      'scanDepth': null,
      'caseSensitive': null,
      'matchWholeWords': null,
      'useGroupScoring': null,
      'automationId': '',
      'role': null,
      'sticky': 0,
      'cooldown': 0,
      'delay': 0,
      'triggers': const <String>[],
      'displayIndex': displayIndex,
      'characterFilter': <String, dynamic>{
        'isExclude': false,
        'names': <String>[],
        'tags': <String>[],
      },
    };
  }

  _WorldBookUiCategory _classifyEntryByRule(Map<String, dynamic> entry) {
    final text = [
      '${entry['comment'] ?? ''}',
      _stringList(entry['key']).join(' '),
      '${entry['content'] ?? ''}',
    ].join('\n').toLowerCase();
    const characterKeywords = <String>[
      'character',
      'persona',
      'personality',
      'appearance',
      'relationship',
      'speech',
      'backstory',
      'identity',
      'trait',
      '角色',
      '人物',
      '性格',
      '外貌',
      '关系',
      '身份',
      '口癖',
      '说话',
      '经历',
      '背景',
      '职业',
    ];
    for (final keyword in characterKeywords) {
      if (text.contains(keyword)) {
        return _WorldBookUiCategory.character;
      }
    }
    return _WorldBookUiCategory.setting;
  }

  List<_CategorizedEntry> _ensureCategorizedEntriesAvoidUids(
    List<_CategorizedEntry> entries, {
    required Set<int> usedUids,
  }) {
    final normalized = <_CategorizedEntry>[];
    var nextUid = usedUids.isEmpty
        ? 0
        : (usedUids.reduce((a, b) => a > b ? a : b) + 1);
    for (final item in entries) {
      final entry = Map<String, dynamic>.from(item.entry);
      var uid = _asInt(entry['uid']);
      if (usedUids.contains(uid)) {
        while (usedUids.contains(nextUid)) {
          nextUid += 1;
        }
        uid = nextUid;
        entry['uid'] = uid;
      }
      usedUids.add(uid);
      if (uid >= nextUid) {
        nextUid = uid + 1;
      }
      normalized.add(_CategorizedEntry(entry: entry, category: item.category));
    }
    return normalized;
  }

  Map<String, dynamic>? _extractWrappedItem(
    Map<String, dynamic> json, {
    required String expectedType,
  }) {
    if ('${json['format'] ?? ''}'.trim().toLowerCase() == 'rst' &&
        '${json['type'] ?? ''}'.trim().toLowerCase() == expectedType &&
        json['item'] is Map<String, dynamic>) {
      return json['item'] as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic>? _extractWrappedSession(Map<String, dynamic> json) {
    if ('${json['format'] ?? ''}'.trim().toLowerCase() == 'rst' &&
        '${json['type'] ?? ''}'.trim().toLowerCase() == 'session' &&
        json['session'] is Map<String, dynamic>) {
      return json['session'] as Map<String, dynamic>;
    }
    return null;
  }

  bool _looksLikeManagedOption(
    Map<String, dynamic> json,
    ManagedOptionType type,
  ) {
    return '${json['type'] ?? ''}'.trim() == type.name &&
        json['sections'] is List;
  }

  Future<Map<String, dynamic>> _readJsonObjectFile(String filePath) async {
    final decoded = await _tryReadJsonObjectFile(filePath);
    if (decoded == null) {
      throw StateError('invalid_json_file');
    }
    return decoded;
  }

  Future<Map<String, dynamic>?> _tryReadJsonObjectFile(String filePath) async {
    try {
      final raw = await File(filePath).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeJsonFile(
    String outputPath,
    Map<String, dynamic> json,
  ) async {
    await File(
      outputPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  String _newId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _uniqueName(String baseName, Set<String> existingNames) {
    if (!existingNames.contains(baseName)) {
      return baseName;
    }
    var index = 2;
    while (true) {
      final candidate = '$baseName ($index)';
      if (!existingNames.contains(candidate)) {
        return candidate;
      }
      index += 1;
    }
  }

  String _fileBaseName(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0) {
      return name;
    }
    return name.substring(0, dotIndex);
  }

  Map<String, dynamic>? _extractMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    return null;
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final normalized = '${raw ?? ''}'.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    return normalized
        .split(RegExp(r'[,，\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  int _readScanDepth(Map<String, dynamic> raw) {
    return (_parseInt(raw['scanDepth'] ?? raw['scan_depth']) ?? 4).clamp(
      0,
      2048,
    );
  }

  List<ManagedOptionSection> _upsertField(
    List<ManagedOptionSection> sections,
    String key,
    String value,
  ) {
    if (sections.isEmpty) {
      return <ManagedOptionSection>[
        ManagedOptionSection(
          title: '基础信息',
          description: '',
          fields: <ManagedOptionField>[
            ManagedOptionField(
              key: key,
              label: key,
              type: ManagedFieldType.multiline,
              value: value,
            ),
          ],
        ),
      ];
    }
    var updated = false;
    final next = sections
        .map(
          (section) => section.copyWith(
            fields: section.fields
                .map((field) {
                  if (field.key != key) {
                    return field;
                  }
                  updated = true;
                  return field.copyWith(value: value, replaceValue: true);
                })
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    if (updated) {
      return next;
    }
    final head = next.first;
    final fields = head.fields.toList(growable: true)
      ..add(
        ManagedOptionField(
          key: key,
          label: key,
          type: ManagedFieldType.multiline,
          value: value,
        ),
      );
    return <ManagedOptionSection>[
      head.copyWith(fields: fields),
      ...next.skip(1),
    ];
  }

  frb.SessionMode _sessionModeFromImport(
    Object? raw, {
    required Object? stWorldBookId,
    required List<ImportWarning> warnings,
  }) {
    final normalized = '$raw'.trim().toLowerCase();
    if (normalized == 'st') {
      return frb.SessionMode.st;
    }
    if (normalized == 'rst') {
      return frb.SessionMode.rst;
    }
    warnings.add(
      const ImportWarning(
        code: 'session_mode_fallback',
        message: '会话模式无法识别，已回退',
      ),
    );
    return _normalizeOptionalString(stWorldBookId) != null
        ? frb.SessionMode.st
        : frb.SessionMode.rst;
  }

  frb.MessageRole? _messageRoleFromWire(Object? raw) {
    final normalized = '$raw'.trim().toLowerCase();
    switch (normalized) {
      case 'system':
        return frb.MessageRole.system;
      case 'user':
        return frb.MessageRole.user;
      case 'assistant':
        return frb.MessageRole.assistant;
      default:
        return null;
    }
  }

  frb.MessageStatus _messageStatusFromWire(Object? raw) {
    final normalized = '$raw'.trim().toLowerCase();
    switch (normalized) {
      case 'pending':
        return frb.MessageStatus.pending;
      case 'streaming':
        return frb.MessageStatus.streaming;
      case 'error':
        return frb.MessageStatus.error;
      case 'completed':
      default:
        return frb.MessageStatus.completed;
    }
  }

  frb.StreamingStatus _streamingStatusFromWire(Object? raw) {
    final normalized = '$raw'.trim().toLowerCase();
    switch (normalized) {
      case 'receiving':
        return frb.StreamingStatus.receiving;
      case 'error':
        return frb.StreamingStatus.error;
      case 'idle':
      default:
        return frb.StreamingStatus.idle;
    }
  }

  _WorldBookUiCategory _categoryFromClassificationWire(Object? raw) {
    final normalized = '$raw'.trim().toLowerCase();
    if (normalized == 'character') {
      return _WorldBookUiCategory.character;
    }
    return _WorldBookUiCategory.setting;
  }

  int _parsePosition(Object? raw) {
    final numeric = _parseInt(raw);
    if (numeric != null) {
      return numeric.clamp(0, 1);
    }
    final normalized = '$raw'.trim().toLowerCase();
    if (normalized.contains('before')) {
      return 0;
    }
    return 1;
  }

  int? _parseInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    final normalized = '$raw'.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  int _asInt(Object? raw) {
    return _parseInt(raw) ?? 0;
  }

  double? _parseDouble(Object? raw) {
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    final normalized = '$raw'.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  bool? _parseBool(Object? raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    final normalized = '$raw'.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }

  bool? _parseNullableBool(Object? raw) {
    if (raw == null) {
      return null;
    }
    return _parseBool(raw);
  }

  String? _normalizeOptionalString(Object? raw) {
    final normalized = '$raw'.trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }

  String _normalizeDateTimeString(Object? raw, {String? fallback}) {
    final normalized = '${raw ?? ''}'.trim();
    if (normalized.isEmpty) {
      return fallback ?? DateTime.now().toUtc().toIso8601String();
    }
    return DateTime.tryParse(normalized)?.toUtc().toIso8601String() ??
        (fallback ?? DateTime.now().toUtc().toIso8601String());
  }

  bool _isHexColor(String raw) {
    return RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(raw);
  }

  Map<String, dynamic>? _extractJsonObjectFromText(String text) {
    final trimmed = text.trim();
    final direct = _tryParseJsonObject(trimmed);
    if (direct != null) {
      return direct;
    }
    final fenced = trimmed
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final fromFence = _tryParseJsonObject(fenced);
    if (fromFence != null) {
      return fromFence;
    }
    final start = fenced.indexOf('{');
    final end = fenced.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return _tryParseJsonObject(fenced.substring(start, end + 1));
    }
    return null;
  }

  Map<String, dynamic>? _tryParseJsonObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  int _readUint32(List<int> bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  String? _tryDecodeBase64(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }
    final padding = normalized.length % 4;
    final candidate = padding == 0
        ? normalized
        : '$normalized${'=' * (4 - padding)}';
    try {
      return utf8.decode(base64.decode(candidate));
    } catch (_) {
      return null;
    }
  }

  String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars)}...';
  }
}

enum _WorldBookUiCategory { character, setting }

class _CategorizedEntry {
  const _CategorizedEntry({required this.entry, required this.category});

  final Map<String, dynamic> entry;
  final _WorldBookUiCategory category;
}

class _CharacterCardData {
  const _CharacterCardData({
    required this.rawJson,
    required this.sourceKind,
    required this.displayName,
    required this.description,
    required this.personality,
    required this.scenario,
    required this.firstMes,
    required this.mesExample,
    required this.creatorNotes,
    required this.systemPrompt,
    required this.postHistoryInstructions,
    required this.alternateGreetings,
    required this.characterBookEntries,
    required this.scanDepth,
  });

  final Map<String, dynamic> rawJson;
  final String sourceKind;
  final String displayName;
  final String description;
  final String personality;
  final String scenario;
  final String firstMes;
  final String mesExample;
  final String creatorNotes;
  final String systemPrompt;
  final String postHistoryInstructions;
  final List<String> alternateGreetings;
  final List<Map<String, dynamic>> characterBookEntries;
  final int scanDepth;

  String get suggestedId => 'wb-${DateTime.now().microsecondsSinceEpoch}';

  _CharacterCardData copyWith({String? sourceKind}) {
    return _CharacterCardData(
      rawJson: rawJson,
      sourceKind: sourceKind ?? this.sourceKind,
      displayName: displayName,
      description: description,
      personality: personality,
      scenario: scenario,
      firstMes: firstMes,
      mesExample: mesExample,
      creatorNotes: creatorNotes,
      systemPrompt: systemPrompt,
      postHistoryInstructions: postHistoryInstructions,
      alternateGreetings: alternateGreetings,
      characterBookEntries: characterBookEntries,
      scanDepth: scanDepth,
    );
  }
}

class _ImportedSession {
  const _ImportedSession({required this.config, required this.document});

  final frb.SessionConfig config;
  final Map<String, dynamic> document;
}

class _NormalizedMessages {
  const _NormalizedMessages({
    this.messages = const <Map<String, dynamic>>[],
    this.messageIdMap = const <String, String>{},
  });

  final List<Map<String, dynamic>> messages;
  final Map<String, String> messageIdMap;
}
