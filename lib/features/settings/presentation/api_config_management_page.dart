import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/provider_specs.dart';
import '../../../core/models/workspace_config.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/providers/config_catalog_providers.dart';
import '../../../core/providers/service_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class ApiConfigManagementPage extends ConsumerWidget {
  const ApiConfigManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(apiConfigCatalogProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrimaryPillButton(
                      label: '新建配置',
                      onPressed: () => _openEditor(context, ref),
                    ),
                    SecondaryOutlineButton(
                      label: '刷新',
                      onPressed: () =>
                          ref.read(apiConfigCatalogProvider.notifier).refresh(),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: '导入',
                  onPressed: () => _import(context, ref),
                  icon: const Icon(Icons.file_download_outlined),
                ),
                IconButton(
                  tooltip: '导出',
                  onPressed: () => _export(context, ref),
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              ],
            ),
          ),
          ...configs.when(
            data: (items) => _buildList(context, ref, items),
            loading: () => const <Widget>[
              Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => <Widget>[
              EmptyStateView(
                title: 'API配置加载失败',
                description: '$error',
                actionLabel: '重试',
                onAction: () =>
                    ref.read(apiConfigCatalogProvider.notifier).refresh(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildList(
    BuildContext context,
    WidgetRef ref,
    List<StoredApiConfig> configs,
  ) {
    if (configs.isEmpty) {
      return <Widget>[
        EmptyStateView(
          title: '暂无 API 配置',
          description: '先创建一个 API 配置，再绑定到会话。',
          actionLabel: '新建配置',
          onAction: () => _openEditor(context, ref),
        ),
      ];
    }

    return configs
        .map(
          (config) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassPanelCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ProviderBadge(
                              label: config.providerType.label,
                              tone: _providerTone(config.providerType),
                            ),
                            _ProviderBadge(
                              label: config.providerType.shortDescription,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          config.baseUrl,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '编辑',
                    onPressed: () => _openEditor(context, ref, source: config),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () => _deleteConfig(context, ref, config),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  static Color _providerTone(ProviderType providerType) {
    return switch (providerType) {
      ProviderType.openai => AppColors.accentPrimary,
      ProviderType.openaiCompatible => AppColors.accentSecondary,
      ProviderType.anthropic => AppColors.warning,
      ProviderType.gemini => const Color(0xFF79D66F),
      ProviderType.deepseek => const Color(0xFF57A7FF),
      ProviderType.openrouter => const Color(0xFFF06A93),
    };
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    StoredApiConfig? source,
  }) async {
    final draft = source ?? ref.read(apiServiceProvider).buildApiConfigDraft();
    final saved = await Navigator.of(context).push<StoredApiConfig>(
      MaterialPageRoute<StoredApiConfig>(
        fullscreenDialog: true,
        builder: (context) => ApiConfigEditorPage(
          title: source == null ? '新建 API 配置' : '编辑 API 配置',
          initialValue: draft,
        ),
      ),
    );
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    if (saved == null) {
      return;
    }
    await ref.read(apiConfigCatalogProvider.notifier).save(saved);
  }

  Future<void> _deleteConfig(
    BuildContext context,
    WidgetRef ref,
    StoredApiConfig config,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 API 配置'),
        content: Text('确定删除“${config.name}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(apiConfigCatalogProvider.notifier).delete(config.apiId);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    // TODO: 实现导入功能
    AppNotice.show(
      context,
      message: '导入功能即将上线',
      tone: AppNoticeTone.info,
      category: 'apiconfig_import_placeholder',
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    // TODO: 实现导出功能
    AppNotice.show(
      context,
      message: '导出功能即将上线',
      tone: AppNoticeTone.info,
      category: 'apiconfig_export_placeholder',
    );
  }
}

class ApiConfigEditorPage extends ConsumerStatefulWidget {
  const ApiConfigEditorPage({
    super.key,
    required this.title,
    required this.initialValue,
  });

  final String title;
  final StoredApiConfig initialValue;

  @override
  ConsumerState<ApiConfigEditorPage> createState() =>
      ApiConfigEditorPageState();
}

class ApiConfigEditorPageState extends ConsumerState<ApiConfigEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _requestPathController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _headersController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _topPController;
  late final TextEditingController _topKController;
  late final TextEditingController _presencePenaltyController;
  late final TextEditingController _frequencyPenaltyController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _stopSequencesController;
  late final TextEditingController _reasoningController;
  late final TextEditingController _verbosityController;
  late ProviderType _providerType;
  bool? _streamValue;
  bool _obscureApiKey = false;
  bool _fetchingModels = false;
  String? _modelFetchError;
  List<String> _availableModels = <String>[];
  late ProviderType _initialProviderType;
  late String _initialName;
  late String _initialBaseUrl;
  late String _initialRequestPath;
  late String _initialApiKey;
  late String _initialModel;
  late String _initialTimeout;
  late String _initialHeaders;
  late bool? _initialStreamValue;
  late String _initialTemperature;
  late String _initialTopP;
  late String _initialTopK;
  late String _initialPresencePenalty;
  late String _initialFrequencyPenalty;
  late String _initialMaxTokens;
  late String _initialStopSequences;
  late String _initialReasoning;
  late String _initialVerbosity;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _providerType = value.providerType;
    _initialProviderType = value.providerType;
    _nameController = TextEditingController(text: value.name);
    _initialName = value.name;
    _baseUrlController = TextEditingController(text: value.baseUrl);
    _initialBaseUrl = value.baseUrl;
    _requestPathController = TextEditingController(text: value.requestPath);
    _initialRequestPath = value.requestPath;
    _apiKeyController = TextEditingController(text: value.apiKeyCiphertext);
    _initialApiKey = value.apiKeyCiphertext;
    _modelController = TextEditingController(text: value.defaultModel);
    _initialModel = value.defaultModel;
    _timeoutController = TextEditingController(
      text: value.requestTimeoutMs?.toString() ?? '',
    );
    _initialTimeout = value.requestTimeoutMs?.toString() ?? '';
    _headersController = TextEditingController(
      text: value.customHeaders.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n'),
    );
    _initialHeaders = value.customHeaders.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    _streamValue = value.stream;
    _initialStreamValue = value.stream;
    _temperatureController = TextEditingController(
      text: _stringifyDouble(value.temperature),
    );
    _initialTemperature = _stringifyDouble(value.temperature);
    _topPController = TextEditingController(text: _stringifyDouble(value.topP));
    _initialTopP = _stringifyDouble(value.topP);
    _topKController = TextEditingController(text: value.topK?.toString() ?? '');
    _initialTopK = value.topK?.toString() ?? '';
    _presencePenaltyController = TextEditingController(
      text: _stringifyDouble(value.presencePenalty),
    );
    _initialPresencePenalty = _stringifyDouble(value.presencePenalty);
    _frequencyPenaltyController = TextEditingController(
      text: _stringifyDouble(value.frequencyPenalty),
    );
    _initialFrequencyPenalty = _stringifyDouble(value.frequencyPenalty);
    _maxTokensController = TextEditingController(
      text: value.maxCompletionTokens?.toString() ?? '',
    );
    _initialMaxTokens = value.maxCompletionTokens?.toString() ?? '';
    _stopSequencesController = TextEditingController(
      text: value.stopSequences.join('\n'),
    );
    _initialStopSequences = value.stopSequences.join('\n');
    _reasoningController = TextEditingController(
      text: value.reasoningEffort ?? '',
    );
    _initialReasoning = value.reasoningEffort ?? '';
    _verbosityController = TextEditingController(text: value.verbosity ?? '');
    _initialVerbosity = value.verbosity ?? '';
    if (value.defaultModel.trim().isNotEmpty) {
      _availableModels = <String>[value.defaultModel.trim()];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _requestPathController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _timeoutController.dispose();
    _headersController.dispose();
    _temperatureController.dispose();
    _topPController.dispose();
    _topKController.dispose();
    _presencePenaltyController.dispose();
    _frequencyPenaltyController.dispose();
    _maxTokensController.dispose();
    _stopSequencesController.dispose();
    _reasoningController.dispose();
    _verbosityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specCatalogAsync = ref.watch(providerSpecCatalogProvider);
    final specCatalog = specCatalogAsync.valueOrNull;
    final providerChoices =
        specCatalog?.providers
            .map((provider) => provider.providerType)
            .toList(growable: false) ??
        ProviderType.values;
    final selectedSpec = specCatalog?.specFor(_providerType);
    return PopScope<StoredApiConfig>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _handleAttemptDismiss();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: FractionallySizedBox(
        heightFactor: 1,
        child: Container(
          decoration: const BoxDecoration(color: AppColors.backgroundElevated),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: '返回聊天',
                          onPressed: () async {
                            final shouldClose = await _handleAttemptDismiss();
                            if (!mounted || !shouldClose) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EditorSection(
                            title: '连接信息',
                            child: Column(
                              children: [
                                TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: '名称',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ProviderType>(
                                  initialValue: _providerType,
                                  isExpanded: true,
                                  items: providerChoices
                                      .map(
                                        (
                                          provider,
                                        ) => DropdownMenuItem<ProviderType>(
                                          value: provider,
                                          child: Text(
                                            '${provider.label} · ${provider.shortDescription}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value == null ||
                                        value == _providerType) {
                                      return;
                                    }
                                    _selectProvider(value);
                                  },
                                  decoration: const InputDecoration(
                                    labelText: '供应商 / 协议',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _ProviderInfoBanner(
                                  providerType: _providerType,
                                  providerSpec: selectedSpec,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _EditorSection(
                            title: '连接验证',
                            child: Column(
                              children: [
                                TextField(
                                  controller: _baseUrlController,
                                  keyboardType: TextInputType.url,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Base URL',
                                    helperText: '会按当前供应商自动预填默认入口。',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _requestPathController,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Request Path',
                                    helperText: '供应商切换时会同步推荐默认路径，可再手动覆盖。',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _apiKeyController,
                                  obscureText: _obscureApiKey,
                                  keyboardType: TextInputType.visiblePassword,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText: 'API Key',
                                    suffixIcon: IconButton(
                                      tooltip: _obscureApiKey
                                          ? '显示 API Key'
                                          : '隐藏 API Key',
                                      onPressed: () {
                                        setState(() {
                                          _obscureApiKey = !_obscureApiKey;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureApiKey
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _timeoutController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: '请求超时（毫秒）',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: SecondaryOutlineButton(
                                          label: _fetchingModels
                                              ? '同步中...'
                                              : '同步模型',
                                          onPressed: _fetchingModels
                                              ? null
                                              : _fetchModels,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_modelFetchError != null) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          _modelFetchError!,
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '复制错误信息',
                                        onPressed: () async {
                                          final message = _modelFetchError!;
                                          await Clipboard.setData(
                                            ClipboardData(text: message),
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          AppNotice.show(
                                            context,
                                            message: '错误信息已复制',
                                            tone: AppNoticeTone.success,
                                            category: 'copy_error_message',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.copy_all_outlined,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _EditorSection(
                            title: '模型选择',
                            child: Column(
                              children: [
                                if (_availableModels.isNotEmpty) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '可用模型',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color: AppColors.surfaceOverlay,
                                            border: Border.all(
                                              color: AppColors.borderSubtle,
                                            ),
                                          ),
                                          child: Text(
                                            '${_availableModels.length}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _availableModels.contains(
                                          _modelController.text.trim(),
                                        )
                                        ? _modelController.text.trim()
                                        : null,
                                    items: _availableModels
                                        .map(
                                          (model) => DropdownMenuItem<String>(
                                            value: model,
                                            child: Text(
                                              model,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _modelController.text = value;
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      labelText: '从列表选择模型',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                TextField(
                                  controller: _modelController,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Model',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _EditorSection(
                            title: '高级项',
                            child: Column(
                              children: [
                                if (selectedSpec != null &&
                                    selectedSpec.parameters.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ..._buildParameterFields(
                                    context,
                                    selectedSpec.parameters,
                                  ),
                                ],
                                if (selectedSpec == null) ...[
                                  const SizedBox(height: 12),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: CircularProgressIndicator(),
                                  ),
                                ],
                                TextField(
                                  controller: _headersController,
                                  minLines: 2,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    labelText: 'Custom Headers',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundElevated,
                  border: Border(
                    top: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final shouldClose = await _handleAttemptDismiss();
                          if (!mounted || !shouldClose) {
                            return;
                          }
                          Navigator.of(this.context).pop();
                        },
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: selectedSpec == null
                            ? null
                            : () {
                                final name = _nameController.text.trim();
                                if (name.isEmpty) {
                                  return;
                                }
                                final activeSpec = selectedSpec;
                                Navigator.of(context).pop(
                                  widget.initialValue.copyWith(
                                    name: name,
                                    providerType: _providerType,
                                    baseUrl: _baseUrlController.text.trim(),
                                    requestPath: _requestPathController.text
                                        .trim(),
                                    apiKeyCiphertext: _apiKeyController.text
                                        .trim(),
                                    defaultModel: _modelController.text.trim(),
                                    requestTimeoutMs: int.tryParse(
                                      _timeoutController.text.trim(),
                                    ),
                                    clearRequestTimeoutMs: _timeoutController
                                        .text
                                        .trim()
                                        .isEmpty,
                                    customHeaders: _parseHeaders(
                                      _headersController.text,
                                    ),
                                    stream: _streamValue,
                                    clearStream:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.stream,
                                        ) ||
                                        _streamValue == null,
                                    temperature: _tryParseDouble(
                                      _temperatureController.text,
                                    ),
                                    clearTemperature:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.temperature,
                                        ) ||
                                        _temperatureController.text
                                            .trim()
                                            .isEmpty,
                                    topP: _tryParseDouble(_topPController.text),
                                    clearTopP:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.topP,
                                        ) ||
                                        _topPController.text.trim().isEmpty,
                                    topK: int.tryParse(
                                      _topKController.text.trim(),
                                    ),
                                    clearTopK:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.topK,
                                        ) ||
                                        _topKController.text.trim().isEmpty,
                                    presencePenalty: _tryParseDouble(
                                      _presencePenaltyController.text,
                                    ),
                                    clearPresencePenalty:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.presencePenalty,
                                        ) ||
                                        _presencePenaltyController.text
                                            .trim()
                                            .isEmpty,
                                    frequencyPenalty: _tryParseDouble(
                                      _frequencyPenaltyController.text,
                                    ),
                                    clearFrequencyPenalty:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.frequencyPenalty,
                                        ) ||
                                        _frequencyPenaltyController.text
                                            .trim()
                                            .isEmpty,
                                    maxCompletionTokens: int.tryParse(
                                      _maxTokensController.text.trim(),
                                    ),
                                    clearMaxCompletionTokens:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.maxCompletionTokens,
                                        ) ||
                                        _maxTokensController.text
                                            .trim()
                                            .isEmpty,
                                    stopSequences:
                                        _supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.stopSequences,
                                        )
                                        ? _stopSequencesController.text
                                              .split('\n')
                                              .map((item) => item.trim())
                                              .where((item) => item.isNotEmpty)
                                              .toList(growable: false)
                                        : const <String>[],
                                    reasoningEffort: _normalize(
                                      _reasoningController.text,
                                    ),
                                    clearReasoningEffort:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.reasoningEffort,
                                        ) ||
                                        _normalize(_reasoningController.text) ==
                                            null,
                                    verbosity: _normalize(
                                      _verbosityController.text,
                                    ),
                                    clearVerbosity:
                                        !_supportsParameter(
                                          activeSpec,
                                          ApiParameterKey.verbosity,
                                        ) ||
                                        _normalize(_verbosityController.text) ==
                                            null,
                                  ),
                                );
                              },
                        child: const Text('保存配置'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _handleAttemptDismiss() async {
    if (!_isDirty()) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了 API 配置，现在关闭会丢失本次填写内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  bool _isDirty() {
    return _providerType != _initialProviderType ||
        _nameController.text != _initialName ||
        _baseUrlController.text != _initialBaseUrl ||
        _requestPathController.text != _initialRequestPath ||
        _apiKeyController.text != _initialApiKey ||
        _modelController.text != _initialModel ||
        _timeoutController.text != _initialTimeout ||
        _headersController.text != _initialHeaders ||
        _streamValue != _initialStreamValue ||
        _temperatureController.text != _initialTemperature ||
        _topPController.text != _initialTopP ||
        _topKController.text != _initialTopK ||
        _presencePenaltyController.text != _initialPresencePenalty ||
        _frequencyPenaltyController.text != _initialFrequencyPenalty ||
        _maxTokensController.text != _initialMaxTokens ||
        _stopSequencesController.text != _initialStopSequences ||
        _reasoningController.text != _initialReasoning ||
        _verbosityController.text != _initialVerbosity;
  }

  Future<void> _fetchModels() async {
    final apiService = ref.read(apiServiceProvider);
    setState(() {
      _fetchingModels = true;
      _modelFetchError = null;
    });
    try {
      final models = await apiService.fetchAvailableModels(
        providerType: _providerType,
        baseUrl: _baseUrlController.text.trim(),
        requestPath: _requestPathController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        customHeaders: _parseHeaders(_headersController.text),
        requestTimeoutMs: int.tryParse(_timeoutController.text.trim()),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels = models;
        final current = _modelController.text.trim();
        if (current.isEmpty || !_availableModels.contains(current)) {
          _modelController.text = _availableModels.first;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _modelFetchError = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _fetchingModels = false;
        });
      }
    }
  }

  void _selectProvider(ProviderType selected) {
    setState(() {
      final previous = _providerType;
      _providerType = selected;
      _modelFetchError = null;
      _availableModels = _seedModelsFromCurrentInput();

      if (_shouldReplaceWithProviderDefault(
        currentValue: _baseUrlController.text,
        previous: previous,
        selected: selected,
        selector: _providerDefaultBaseUrl,
      )) {
        _baseUrlController.text = _providerDefaultBaseUrl(selected);
      }

      if (_shouldReplaceWithProviderDefault(
        currentValue: _requestPathController.text,
        previous: previous,
        selected: selected,
        selector: _providerDefaultRequestPath,
      )) {
        _requestPathController.text = _providerDefaultRequestPath(selected);
      }

      if (_shouldReplaceWithProviderDefault(
        currentValue: _modelController.text,
        previous: previous,
        selected: selected,
        selector: _providerDefaultModel,
      )) {
        _modelController.text = _providerDefaultModel(selected);
      }
    });
  }

  List<String> _seedModelsFromCurrentInput() {
    final current = _modelController.text.trim();
    if (current.isEmpty) {
      return <String>[];
    }
    return <String>[current];
  }

  String _providerDefaultBaseUrl(ProviderType provider) {
    final catalog = ref.read(providerSpecCatalogProvider).valueOrNull;
    if (catalog == null) {
      return provider.defaultBaseUrl;
    }
    return catalog.specFor(provider).defaultBaseUrl;
  }

  String _providerDefaultRequestPath(ProviderType provider) {
    final catalog = ref.read(providerSpecCatalogProvider).valueOrNull;
    if (catalog == null) {
      return provider.defaultRequestPath;
    }
    return catalog.specFor(provider).defaultRequestPath;
  }

  String _providerDefaultModel(ProviderType provider) {
    final catalog = ref.read(providerSpecCatalogProvider).valueOrNull;
    if (catalog == null) {
      return provider.defaultModel;
    }
    return catalog.specFor(provider).defaultModel;
  }

  bool _supportsParameter(ProviderSpec? providerSpec, ApiParameterKey key) {
    return providerSpec?.supports(key) == true;
  }

  List<Widget> _buildParameterFields(
    BuildContext context,
    List<ProviderParameterSpec> parameters,
  ) {
    final widgets = <Widget>[];
    for (var index = 0; index < parameters.length; index++) {
      widgets.add(_buildParameterField(context, parameters[index]));
      if (index != parameters.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Widget _buildParameterField(
    BuildContext context,
    ProviderParameterSpec parameter,
  ) {
    const decorationBase = InputDecoration(helperText: null, hintText: null);
    final decoration = decorationBase.copyWith(labelText: parameter.label);
    switch (parameter.key) {
      case ApiParameterKey.stream:
        return DropdownButtonFormField<bool?>(
          initialValue: _streamValue,
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('默认')),
            DropdownMenuItem<bool?>(value: true, child: Text('开启')),
            DropdownMenuItem<bool?>(value: false, child: Text('关闭')),
          ],
          onChanged: (value) {
            setState(() {
              _streamValue = value;
            });
          },
          decoration: decoration,
        );
      case ApiParameterKey.temperature:
        return TextField(
          controller: _temperatureController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoration,
        );
      case ApiParameterKey.topP:
        return TextField(
          controller: _topPController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoration,
        );
      case ApiParameterKey.topK:
        return TextField(
          controller: _topKController,
          keyboardType: TextInputType.number,
          decoration: decoration,
        );
      case ApiParameterKey.presencePenalty:
        return TextField(
          controller: _presencePenaltyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoration,
        );
      case ApiParameterKey.frequencyPenalty:
        return TextField(
          controller: _frequencyPenaltyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoration,
        );
      case ApiParameterKey.maxCompletionTokens:
        return TextField(
          controller: _maxTokensController,
          keyboardType: TextInputType.number,
          decoration: decoration,
        );
      case ApiParameterKey.stopSequences:
        return TextField(
          controller: _stopSequencesController,
          minLines: 2,
          maxLines: 5,
          decoration: decoration,
        );
      case ApiParameterKey.reasoningEffort:
        return TextField(
          controller: _reasoningController,
          decoration: decoration,
        );
      case ApiParameterKey.verbosity:
        return TextField(
          controller: _verbosityController,
          decoration: decoration,
        );
    }
  }

  Map<String, String> _parseHeaders(String raw) {
    final next = <String, String>{};
    for (final line in raw.split('\n')) {
      final normalized = line.trim();
      if (normalized.isEmpty) {
        continue;
      }
      final separatorIndex = normalized.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }
      final key = normalized.substring(0, separatorIndex).trim();
      final value = normalized.substring(separatorIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      next[key] = value;
    }
    return next;
  }

  bool _shouldReplaceWithProviderDefault({
    required String currentValue,
    required ProviderType previous,
    required ProviderType selected,
    required String Function(ProviderType provider) selector,
  }) {
    final trimmed = currentValue.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    if (trimmed == selector(previous)) {
      return true;
    }
    return trimmed == selector(selected);
  }

  String _stringifyDouble(double? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  double? _tryParseDouble(String raw) {
    return double.tryParse(raw.trim());
  }

  String? _normalize(String raw) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ProviderInfoBanner extends StatelessWidget {
  const _ProviderInfoBanner({required this.providerType, this.providerSpec});

  final ProviderType providerType;
  final ProviderSpec? providerSpec;

  @override
  Widget build(BuildContext context) {
    final tone = _providerColor(providerType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            tone.withValues(alpha: 0.18),
            AppColors.surfaceOverlay.withValues(alpha: 0.32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: tone.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            providerSpec?.label ?? providerType.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            providerSpec?.notes.isNotEmpty == true
                ? providerSpec!.notes.first
                : _providerInfoText(providerType),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.label, this.tone});

  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

Color _providerColor(ProviderType providerType) {
  return switch (providerType) {
    ProviderType.openai => AppColors.accentPrimary,
    ProviderType.openaiCompatible => AppColors.accentSecondary,
    ProviderType.anthropic => AppColors.warning,
    ProviderType.gemini => const Color(0xFF79D66F),
    ProviderType.deepseek => const Color(0xFF57A7FF),
    ProviderType.openrouter => const Color(0xFFF06A93),
  };
}

String _providerInfoText(ProviderType providerType) {
  return switch (providerType) {
    ProviderType.openai =>
      '使用 OpenAI Responses API。请求会按原生 Responses 结构发送，适合官方最新模型能力。',
    ProviderType.openaiCompatible =>
      '使用标准 Chat Completions 协议。会按 SillyTavern 常见兼容格式发送 messages、max_tokens、reasoning_effort 与 verbosity。',
    ProviderType.anthropic =>
      '使用 Claude Messages API。鉴权会切换成 x-api-key，并自动追加 anthropic-version。',
    ProviderType.gemini =>
      '使用 Google AI Studio 流式生成接口。API key 会放在 query 中，系统提示会映射为 systemInstruction。',
    ProviderType.deepseek =>
      '按 DeepSeek 的 Chat Completions 方式发送，整体保持 OpenAI-compatible 风格，便于和 SillyTavern 对齐。',
    ProviderType.openrouter =>
      '走 OpenRouter 聚合路由，并自动附加 SillyTavern 常见的 HTTP-Referer 与 X-Title 标识头。',
  };
}
