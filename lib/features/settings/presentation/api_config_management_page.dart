import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/workspace_config.dart';
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
          GlassPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API配置', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('管理 Provider、模型与鉴权信息，保存后会直接影响实际请求。'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PrimaryPillButton(
                      label: '新建配置',
                      onPressed: () => _openEditor(context, ref),
                    ),
                    const SizedBox(width: 8),
                    SecondaryOutlineButton(
                      label: '刷新',
                      onPressed: () =>
                          ref.read(apiConfigCatalogProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _providerLabel(config.providerType),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${config.baseUrl}${config.requestPath}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'model: ${config.defaultModel} · key: ${config.apiKeyHint ?? "未设置"}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SecondaryOutlineButton(
                        label: '编辑',
                        onPressed: () =>
                            _openEditor(context, ref, source: config),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _deleteConfig(context, ref, config),
                        child: const Text(
                          '删除',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
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
    final saved = await showDialog<StoredApiConfig>(
      context: context,
      builder: (context) => _ApiConfigEditorDialog(
        title: source == null ? '新建 API 配置' : '编辑 API 配置',
        initialValue: draft,
      ),
    );
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

  String _providerLabel(ProviderType type) {
    return switch (type) {
      ProviderType.openai => 'OpenAI Responses',
      ProviderType.openaiCompatible => 'OpenAI-Compatible Chat Completions',
    };
  }
}

class _ApiConfigEditorDialog extends StatefulWidget {
  const _ApiConfigEditorDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final StoredApiConfig initialValue;

  @override
  State<_ApiConfigEditorDialog> createState() => _ApiConfigEditorDialogState();
}

class _ApiConfigEditorDialogState extends State<_ApiConfigEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _requestPathController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _headersController;
  late ProviderType _providerType;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _providerType = value.providerType;
    _nameController = TextEditingController(text: value.name);
    _baseUrlController = TextEditingController(text: value.baseUrl);
    _requestPathController = TextEditingController(text: value.requestPath);
    _apiKeyController = TextEditingController(text: value.apiKeyCiphertext);
    _modelController = TextEditingController(text: value.defaultModel);
    _timeoutController = TextEditingController(
      text: value.requestTimeoutMs?.toString() ?? '',
    );
    _headersController = TextEditingController(
      text: value.customHeaders.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n'),
    );
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ProviderType>(
                initialValue: _providerType,
                items: const [
                  DropdownMenuItem(
                    value: ProviderType.openaiCompatible,
                    child: Text('OpenAI-Compatible'),
                  ),
                  DropdownMenuItem(
                    value: ProviderType.openai,
                    child: Text('OpenAI'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _providerType = value;
                    if (_requestPathController.text.trim().isEmpty) {
                      _requestPathController.text =
                          _providerType == ProviderType.openai
                          ? '/v1/responses'
                          : '/v1/chat/completions';
                    }
                  });
                },
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(labelText: 'Base URL'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _requestPathController,
                decoration: const InputDecoration(labelText: 'Request Path'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API Key'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _timeoutController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '请求超时（毫秒）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _headersController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Custom Headers',
                  helperText: '每行一个，格式为 Header: Value',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
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
                requestTimeoutMs: int.tryParse(_timeoutController.text.trim()),
                clearRequestTimeoutMs: _timeoutController.text.trim().isEmpty,
                customHeaders: _parseHeaders(_headersController.text),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
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
