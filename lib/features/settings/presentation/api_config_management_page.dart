import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/workspace_config.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/providers/config_catalog_providers.dart';
import '../../../core/providers/service_providers.dart';
import '../../../shared/theme/app_colors.dart';
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
            child: Wrap(
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
                children: [
                  Expanded(
                    child: Text(
                      config.name,
                      style: Theme.of(context).textTheme.titleMedium,
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

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    StoredApiConfig? source,
  }) async {
    final draft = source ?? ref.read(apiServiceProvider).buildApiConfigDraft();
    final saved = await Navigator.of(context).push<StoredApiConfig>(
      MaterialPageRoute<StoredApiConfig>(
        fullscreenDialog: true,
        builder: (context) => _ApiConfigEditorDialog(
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
}

class _ApiConfigEditorDialog extends ConsumerStatefulWidget {
  const _ApiConfigEditorDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final StoredApiConfig initialValue;

  @override
  ConsumerState<_ApiConfigEditorDialog> createState() =>
      _ApiConfigEditorDialogState();
}

class _ApiConfigEditorDialogState
    extends ConsumerState<_ApiConfigEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _requestPathController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _headersController;
  late ProviderType _providerType;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '模型平台',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<ProviderType>(
                                  segments: const [
                                    ButtonSegment<ProviderType>(
                                      value: ProviderType.openaiCompatible,
                                      label: Text('OpenAI-Compatible'),
                                      icon: Icon(Icons.hub_outlined),
                                    ),
                                    ButtonSegment<ProviderType>(
                                      value: ProviderType.openai,
                                      label: Text('OpenAI'),
                                      icon: Icon(Icons.auto_awesome_outlined),
                                    ),
                                  ],
                                  selected: <ProviderType>{_providerType},
                                  onSelectionChanged: (selection) {
                                    final selected = selection.first;
                                    setState(() {
                                      _providerType = selected;
                                      _modelFetchError = null;
                                      _availableModels =
                                          _seedModelsFromCurrentInput();
                                      if (_requestPathController.text
                                          .trim()
                                          .isEmpty) {
                                        _requestPathController.text =
                                            selected == ProviderType.openai
                                            ? '/v1/responses'
                                            : '/v1/chat/completions';
                                      }
                                    });
                                  },
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
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _requestPathController,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Request Path',
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
                                              ? '获取中...'
                                              : '获取模型列表',
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('错误信息已复制'),
                                            ),
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
                            child: TextField(
                              controller: _headersController,
                              minLines: 2,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Custom Headers',
                              ),
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
                        onPressed: () {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            return;
                          }
                          Navigator.of(context).pop(
                            widget.initialValue.copyWith(
                              name: name,
                              providerType: _providerType,
                              baseUrl: _baseUrlController.text.trim(),
                              requestPath: _requestPathController.text.trim(),
                              apiKeyCiphertext: _apiKeyController.text.trim(),
                              defaultModel: _modelController.text.trim(),
                              requestTimeoutMs: int.tryParse(
                                _timeoutController.text.trim(),
                              ),
                              clearRequestTimeoutMs: _timeoutController.text
                                  .trim()
                                  .isEmpty,
                              customHeaders: _parseHeaders(
                                _headersController.text,
                              ),
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
        _headersController.text != _initialHeaders;
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

  List<String> _seedModelsFromCurrentInput() {
    final current = _modelController.text.trim();
    if (current.isEmpty) {
      return <String>[];
    }
    return <String>[current];
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
