import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/workspace_config.dart';
import '../../../core/providers/app_state.dart';
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrimaryPillButton(
                  label: '新建预设',
                  onPressed: () => _openEditor(context, ref),
                ),
                SecondaryOutlineButton(
                  label: '刷新',
                  onPressed: () =>
                      ref.read(presetCatalogProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '编辑',
                    onPressed: () => _openEditor(context, ref, source: preset),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () => _deletePreset(context, ref, preset),
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
    StoredPresetConfig? source,
  }) async {
    final draft = source ?? ref.read(apiServiceProvider).buildPresetDraft();
    final saved = await Navigator.of(context).push<StoredPresetConfig>(
      MaterialPageRoute<StoredPresetConfig>(
        fullscreenDialog: true,
        builder: (context) => _PresetEditorPage(
          title: source == null ? '新建预设' : '编辑预设',
          initialValue: draft,
        ),
      ),
    );
    ref.read(appTabProvider.notifier).state = AppTab.chat;
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

class _PresetEditorPage extends StatefulWidget {
  const _PresetEditorPage({required this.title, required this.initialValue});

  final String title;
  final StoredPresetConfig initialValue;

  @override
  State<_PresetEditorPage> createState() => _PresetEditorPageState();
}

class _PresetEditorPageState extends State<_PresetEditorPage> {
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
  late final String _initialName;
  late final String _initialDescription;
  late final String _initialMainPrompt;
  late final String _initialTemperature;
  late final String _initialTopP;
  late final String _initialPresencePenalty;
  late final String _initialFrequencyPenalty;
  late final String _initialMaxTokens;
  late final String _initialStopSequences;
  late final String _initialReasoning;
  late final String _initialVerbosity;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _nameController = TextEditingController(text: value.name);
    _initialName = value.name;
    _descriptionController = TextEditingController(
      text: value.description ?? '',
    );
    _initialDescription = value.description ?? '';
    _mainPromptController = TextEditingController(text: value.mainPrompt);
    _initialMainPrompt = value.mainPrompt;
    _temperatureController = TextEditingController(
      text: _stringifyDouble(value.temperature),
    );
    _initialTemperature = _stringifyDouble(value.temperature);
    _topPController = TextEditingController(text: _stringifyDouble(value.topP));
    _initialTopP = _stringifyDouble(value.topP);
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
    return PopScope<StoredPresetConfig>(
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
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
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
          title: Text(widget.title),
          actions: [
            TextButton(onPressed: _submit, child: const Text('保存')),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: GlassPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        decoration: const InputDecoration(
                          labelText: 'Main Prompt',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildResponsivePair(
                        TextField(
                          controller: _temperatureController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Temperature',
                          ),
                        ),
                        TextField(
                          controller: _topPController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Top P'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildResponsivePair(
                        TextField(
                          controller: _presencePenaltyController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Presence Penalty',
                          ),
                        ),
                        TextField(
                          controller: _frequencyPenaltyController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Frequency Penalty',
                          ),
                        ),
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
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildResponsivePair(
                        TextField(
                          controller: _reasoningController,
                          decoration: const InputDecoration(
                            labelText: 'Reasoning Effort',
                          ),
                        ),
                        TextField(
                          controller: _verbosityController,
                          decoration: const InputDecoration(
                            labelText: 'Verbosity',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _submit, child: const Text('保存')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsivePair(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [left, const SizedBox(height: 10), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称不能为空')));
      return;
    }
    Navigator.of(context).pop(
      widget.initialValue.copyWith(
        name: name,
        description: _normalize(_descriptionController.text),
        clearDescription: _normalize(_descriptionController.text) == null,
        mainPrompt: _mainPromptController.text.trim(),
        temperature: _tryParseDouble(_temperatureController.text),
        clearTemperature: _temperatureController.text.trim().isEmpty,
        topP: _tryParseDouble(_topPController.text),
        clearTopP: _topPController.text.trim().isEmpty,
        presencePenalty: _tryParseDouble(_presencePenaltyController.text),
        clearPresencePenalty: _presencePenaltyController.text.trim().isEmpty,
        frequencyPenalty: _tryParseDouble(_frequencyPenaltyController.text),
        clearFrequencyPenalty: _frequencyPenaltyController.text.trim().isEmpty,
        maxCompletionTokens: int.tryParse(_maxTokensController.text.trim()),
        clearMaxCompletionTokens: _maxTokensController.text.trim().isEmpty,
        stopSequences: _stopSequencesController.text
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        reasoningEffort: _normalize(_reasoningController.text),
        clearReasoningEffort: _normalize(_reasoningController.text) == null,
        verbosity: _normalize(_verbosityController.text),
        clearVerbosity: _normalize(_verbosityController.text) == null,
      ),
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

  Future<bool> _handleAttemptDismiss() async {
    if (!_isDirty()) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了预设内容，现在返回会丢失本次填写。'),
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
    return _nameController.text != _initialName ||
        _descriptionController.text != _initialDescription ||
        _mainPromptController.text != _initialMainPrompt ||
        _temperatureController.text != _initialTemperature ||
        _topPController.text != _initialTopP ||
        _presencePenaltyController.text != _initialPresencePenalty ||
        _frequencyPenaltyController.text != _initialFrequencyPenalty ||
        _maxTokensController.text != _initialMaxTokens ||
        _stopSequencesController.text != _initialStopSequences ||
        _reasoningController.text != _initialReasoning ||
        _verbosityController.text != _initialVerbosity;
  }
}
