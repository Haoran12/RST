import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/workspace_config.dart';
import '../../../core/providers/config_catalog_providers.dart';
import '../../../core/providers/service_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class PresetManagementPage extends ConsumerWidget {
  const PresetManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetCatalogProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ListView(
        children: [
          GlassPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('预设', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('管理主提示词与生成参数，保存后会被当前会话真实使用。'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PrimaryPillButton(
                      label: '新建预设',
                      onPressed: () => _openEditor(context, ref),
                    ),
                    const SizedBox(width: 8),
                    SecondaryOutlineButton(
                      label: '刷新',
                      onPressed: () =>
                          ref.read(presetCatalogProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...presets.when(
            data: (items) => _buildList(context, ref, items),
            loading: () => const <Widget>[
              Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => <Widget>[
              EmptyStateView(
                title: '预设加载失败',
                description: '$error',
                actionLabel: '重试',
                onAction: () =>
                    ref.read(presetCatalogProvider.notifier).refresh(),
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
    List<StoredPresetConfig> presets,
  ) {
    if (presets.isEmpty) {
      return <Widget>[
        EmptyStateView(
          title: '暂无预设',
          description: '先创建一个预设，再绑定到会话。',
          actionLabel: '新建预设',
          onAction: () => _openEditor(context, ref),
        ),
      ];
    }

    return presets
        .map(
          (preset) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassPanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (preset.description != null &&
                      preset.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(preset.description!),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    preset.mainPrompt,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _summary(preset),
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
                            _openEditor(context, ref, source: preset),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _deletePreset(context, ref, preset),
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

  String _summary(StoredPresetConfig preset) {
    final parts = <String>['id: ${preset.presetId}'];
    if (preset.temperature != null) {
      parts.add('temp: ${preset.temperature}');
    }
    if (preset.topP != null) {
      parts.add('top_p: ${preset.topP}');
    }
    if (preset.maxCompletionTokens != null) {
      parts.add('max: ${preset.maxCompletionTokens}');
    }
    if (preset.reasoningEffort != null && preset.reasoningEffort!.isNotEmpty) {
      parts.add('reasoning: ${preset.reasoningEffort}');
    }
    if (preset.stopSequences.isNotEmpty) {
      parts.add('stop: ${preset.stopSequences.length}');
    }
    return parts.join(' · ');
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    StoredPresetConfig? source,
  }) async {
    final draft = source ?? ref.read(apiServiceProvider).buildPresetDraft();
    final saved = await showDialog<StoredPresetConfig>(
      context: context,
      builder: (context) => _PresetEditorDialog(
        title: source == null ? '新建预设' : '编辑预设',
        initialValue: draft,
      ),
    );
    if (saved == null) {
      return;
    }
    await ref.read(presetCatalogProvider.notifier).save(saved);
  }

  Future<void> _deletePreset(
    BuildContext context,
    WidgetRef ref,
    StoredPresetConfig preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定删除“${preset.name}”？'),
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
    await ref.read(presetCatalogProvider.notifier).delete(preset.presetId);
  }
}

class _PresetEditorDialog extends StatefulWidget {
  const _PresetEditorDialog({required this.title, required this.initialValue});

  final String title;
  final StoredPresetConfig initialValue;

  @override
  State<_PresetEditorDialog> createState() => _PresetEditorDialogState();
}

class _PresetEditorDialogState extends State<_PresetEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _mainPromptController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _topPController;
  late final TextEditingController _presencePenaltyController;
  late final TextEditingController _frequencyPenaltyController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _stopSequencesController;
  late final TextEditingController _reasoningController;
  late final TextEditingController _verbosityController;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _nameController = TextEditingController(text: value.name);
    _descriptionController = TextEditingController(
      text: value.description ?? '',
    );
    _mainPromptController = TextEditingController(text: value.mainPrompt);
    _temperatureController = TextEditingController(
      text: _stringifyDouble(value.temperature),
    );
    _topPController = TextEditingController(text: _stringifyDouble(value.topP));
    _presencePenaltyController = TextEditingController(
      text: _stringifyDouble(value.presencePenalty),
    );
    _frequencyPenaltyController = TextEditingController(
      text: _stringifyDouble(value.frequencyPenalty),
    );
    _maxTokensController = TextEditingController(
      text: value.maxCompletionTokens?.toString() ?? '',
    );
    _stopSequencesController = TextEditingController(
      text: value.stopSequences.join('\n'),
    );
    _reasoningController = TextEditingController(
      text: value.reasoningEffort ?? '',
    );
    _verbosityController = TextEditingController(text: value.verbosity ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _mainPromptController.dispose();
    _temperatureController.dispose();
    _topPController.dispose();
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
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '描述'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mainPromptController,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Main Prompt'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _temperatureController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Temperature',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _topPController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Top P'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _presencePenaltyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Presence Penalty',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _frequencyPenaltyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Frequency Penalty',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _maxTokensController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Completion Tokens',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _stopSequencesController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Stop Sequences',
                  helperText: '每行一个停止序列',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reasoningController,
                      decoration: const InputDecoration(
                        labelText: 'Reasoning Effort',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _verbosityController,
                      decoration: const InputDecoration(labelText: 'Verbosity'),
                    ),
                  ),
                ],
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
                description: _normalize(_descriptionController.text),
                clearDescription:
                    _normalize(_descriptionController.text) == null,
                mainPrompt: _mainPromptController.text.trim(),
                temperature: _tryParseDouble(_temperatureController.text),
                clearTemperature: _temperatureController.text.trim().isEmpty,
                topP: _tryParseDouble(_topPController.text),
                clearTopP: _topPController.text.trim().isEmpty,
                presencePenalty: _tryParseDouble(
                  _presencePenaltyController.text,
                ),
                clearPresencePenalty: _presencePenaltyController.text
                    .trim()
                    .isEmpty,
                frequencyPenalty: _tryParseDouble(
                  _frequencyPenaltyController.text,
                ),
                clearFrequencyPenalty: _frequencyPenaltyController.text
                    .trim()
                    .isEmpty,
                maxCompletionTokens: int.tryParse(
                  _maxTokensController.text.trim(),
                ),
                clearMaxCompletionTokens: _maxTokensController.text
                    .trim()
                    .isEmpty,
                stopSequences: _stopSequencesController.text
                    .split('\n')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList(growable: false),
                reasoningEffort: _normalize(_reasoningController.text),
                clearReasoningEffort:
                    _normalize(_reasoningController.text) == null,
                verbosity: _normalize(_verbosityController.text),
                clearVerbosity: _normalize(_verbosityController.text) == null,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
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
