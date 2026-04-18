import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_state.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class ResourceManagementPage extends ConsumerWidget {
  const ResourceManagementPage({
    super.key,
    required this.title,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.optionType,
    required this.optionsProvider,
  });

  final String title;
  final String emptyTitle;
  final String emptyDescription;
  final ManagedOptionType optionType;
  final StateProvider<List<ManagedOption>> optionsProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(optionsProvider);

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
                  label: '新建',
                  onPressed: () => _createOption(context, ref),
                ),
              ],
            ),
          ),
          if (options.isEmpty)
            EmptyStateView(
              title: emptyTitle,
              description: emptyDescription,
              actionLabel: '新建',
              onAction: () => _createOption(context, ref),
            )
          else
            ...options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPanelCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: '编辑',
                        onPressed: () => _editOption(context, ref, option),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _deleteOption(context, ref, option),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createOption(BuildContext context, WidgetRef ref) async {
    final initial = buildManagedOptionTemplate(
      optionType,
      id: '${optionType.name}-${DateTime.now().millisecondsSinceEpoch}',
      name: '新建${_typeLabel(optionType)}',
      description: '请填写描述信息。',
    );
    final created = await Navigator.of(context).push<ManagedOption>(
      MaterialPageRoute<ManagedOption>(
        fullscreenDialog: true,
        builder: (context) =>
            _ManagedOptionEditorPage(title: '新建$title', initialOption: initial),
      ),
    );
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    if (created == null) {
      return;
    }

    final notifier = ref.read(optionsProvider.notifier);
    notifier.state = <ManagedOption>[created, ...notifier.state];
  }

  Future<void> _editOption(
    BuildContext context,
    WidgetRef ref,
    ManagedOption option,
  ) async {
    final edited = await Navigator.of(context).push<ManagedOption>(
      MaterialPageRoute<ManagedOption>(
        fullscreenDialog: true,
        builder: (context) =>
            _ManagedOptionEditorPage(title: '编辑$title', initialOption: option),
      ),
    );
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    if (edited == null) {
      return;
    }

    final notifier = ref.read(optionsProvider.notifier);
    notifier.state = notifier.state
        .map((item) => item.id == edited.id ? edited : item)
        .toList(growable: false);
  }

  Future<void> _deleteOption(
    BuildContext context,
    WidgetRef ref,
    ManagedOption option,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除$title'),
        content: Text('确定删除“${option.name}”？'),
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

    final notifier = ref.read(optionsProvider.notifier);
    notifier.state = notifier.state
        .where((item) => item.id != option.id)
        .toList(growable: false);
  }

  String _typeLabel(ManagedOptionType type) {
    return switch (type) {
      ManagedOptionType.worldBook => '世界书',
      ManagedOptionType.preset => '预设',
      ManagedOptionType.apiConfig => 'API配置',
      ManagedOptionType.appearance => '外观方案',
    };
  }
}

class _ManagedOptionEditorPage extends StatefulWidget {
  const _ManagedOptionEditorPage({
    required this.title,
    required this.initialOption,
  });

  final String title;
  final ManagedOption initialOption;

  @override
  State<_ManagedOptionEditorPage> createState() =>
      _ManagedOptionEditorPageState();
}

class _ManagedOptionEditorPageState extends State<_ManagedOptionEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final Map<String, TextEditingController> _fieldControllers =
      <String, TextEditingController>{};
  late ManagedOption _draft;
  late final String _initialName;
  late final String _initialDescription;
  late final String _initialFieldSignature;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialOption;
    _nameController = TextEditingController(text: widget.initialOption.name);
    _initialName = widget.initialOption.name;
    _descriptionController = TextEditingController(
      text: widget.initialOption.description,
    );
    _initialDescription = widget.initialOption.description;
    _initialFieldSignature = _fieldValueSignature(widget.initialOption);
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<ManagedOption>(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 12),
                      ..._draft.sections.map(_buildSection),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('保存'),
                        ),
                      ),
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

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotice.show(
        context,
        message: '名称不能为空',
        tone: AppNoticeTone.warning,
        category: 'resource_name_required',
      );
      return;
    }
    Navigator.of(context).pop(
      _normalizeNumericFields(
        _draft.copyWith(
          name: name,
          description: _descriptionController.text.trim(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Widget _buildSection(ManagedOptionSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanelCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ...section.fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildField(field),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(ManagedOptionField field) {
    final textController = _fieldControllerFor(field);

    switch (field.type) {
      case ManagedFieldType.multiline:
        return TextField(
          controller: textController,
          minLines: 2,
          maxLines: 5,
          readOnly: field.readOnly,
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.text:
        return TextField(
          controller: textController,
          readOnly: field.readOnly,
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.integer:
        return TextField(
          controller: textController,
          readOnly: field.readOnly,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
          ],
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.decimal:
        return _buildDecimalField(field, textController);
      case ManagedFieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: '${field.value ?? ''}',
          items: field.choices
              .map(
                (choice) => DropdownMenuItem<String>(
                  value: choice.value,
                  child: Text(choice.label),
                ),
              )
              .toList(growable: false),
          onChanged: field.readOnly
              ? null
              : (value) {
                  if (value != null) {
                    _updateField(field.key, value);
                  }
                },
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.color:
        return _buildColorField(field, textController);
      case ManagedFieldType.toggle:
        return SwitchListTile(
          value: (field.value as bool?) ?? false,
          onChanged: field.readOnly
              ? null
              : (value) => _updateField(field.key, value),
          title: Text(field.label),
          contentPadding: EdgeInsets.zero,
        );
    }
  }

  void _updateField(String key, Object? value) {
    setState(() {
      _draft = _draft.updateField(key, value);
    });
  }

  Widget _buildDecimalField(
    ManagedOptionField field,
    TextEditingController controller,
  ) {
    final min = field.min;
    final max = field.max;
    final step = field.step;
    final sliderEnabled = !field.readOnly && min != null && max != null;

    double sliderValue = min ?? 0;
    if (sliderEnabled) {
      final fromText = _parseDecimal(controller.text);
      final fromField = _parseDecimal('${field.value ?? ''}');
      sliderValue = (fromText ?? fromField ?? min).clamp(min, max);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          readOnly: field.readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
          ],
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(labelText: field.label),
        ),
        if (sliderEnabled) ...[
          const SizedBox(height: 8),
          Slider(
            min: min,
            max: max,
            value: sliderValue,
            divisions: _sliderDivisions(min, max, step),
            label: _formatDecimal(sliderValue, step: step),
            onChanged: (value) {
              final normalized = _formatDecimal(value, step: step);
              controller.value = TextEditingValue(
                text: normalized,
                selection: TextSelection.collapsed(offset: normalized.length),
              );
              _updateField(field.key, normalized);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildColorField(
    ManagedOptionField field,
    TextEditingController controller,
  ) {
    final colorPreview = _parseHexColor(controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          readOnly: field.readOnly,
          keyboardType: TextInputType.visiblePassword,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
          ],
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: '#RRGGBB 或 #AARRGGBB',
            suffixIcon: Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorPreview ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const SizedBox(width: 22, height: 22),
              ),
            ),
          ),
        ),
        if (field.choices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: field.choices
                .map((choice) {
                  final selected =
                      controller.text.trim().toUpperCase() ==
                      choice.value.trim().toUpperCase();
                  return ChoiceChip(
                    label: Text(choice.label),
                    selected: selected,
                    onSelected: field.readOnly
                        ? null
                        : (_) {
                            controller.value = TextEditingValue(
                              text: choice.value,
                              selection: TextSelection.collapsed(
                                offset: choice.value.length,
                              ),
                            );
                            _updateField(field.key, choice.value);
                          },
                  );
                })
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  double? _parseDecimal(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  int? _sliderDivisions(double min, double max, double? step) {
    if (step == null || step <= 0) {
      return null;
    }
    final raw = (max - min) / step;
    final rounded = raw.round();
    final isAligned = (raw - rounded).abs() < 1e-6;
    if (!isAligned || rounded <= 0 || rounded > 1000) {
      return null;
    }
    return rounded;
  }

  String _formatDecimal(double value, {double? step}) {
    final precision = _decimalPrecision(step);
    var text = value.toStringAsFixed(precision);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return text;
  }

  int _decimalPrecision(double? step) {
    if (step == null || step <= 0) {
      return 3;
    }
    var text = step.toString();
    if (text.contains('e') || text.contains('E')) {
      text = step.toStringAsFixed(8);
    }
    if (!text.contains('.')) {
      return 0;
    }
    final decimals = text.split('.').last.replaceFirst(RegExp(r'0+$'), '');
    return decimals.isEmpty ? 0 : decimals.length.clamp(0, 6);
  }

  Color? _parseHexColor(String raw) {
    var normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    }
    if (normalized.length == 6) {
      normalized = 'FF$normalized';
    }
    if (normalized.length != 8) {
      return null;
    }
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) {
      return null;
    }
    return Color(value);
  }

  TextEditingController _fieldControllerFor(ManagedOptionField field) {
    final existing = _fieldControllers[field.key];
    if (existing != null) {
      return existing;
    }
    final created = TextEditingController(text: '${field.value ?? ''}');
    _fieldControllers[field.key] = created;
    return created;
  }

  ManagedOption _normalizeNumericFields(ManagedOption source) {
    final nextSections = source.sections
        .map(
          (section) => section.copyWith(
            fields: section.fields
                .map((field) {
                  if (field.type == ManagedFieldType.integer &&
                      field.value is String) {
                    final raw = (field.value as String).trim();
                    if (raw.isEmpty) {
                      return field.copyWith(value: null, replaceValue: true);
                    }
                    final parsed = int.tryParse(raw);
                    return parsed == null
                        ? field
                        : field.copyWith(value: parsed, replaceValue: true);
                  }
                  if (field.type == ManagedFieldType.decimal &&
                      field.value is String) {
                    final raw = (field.value as String).trim();
                    if (raw.isEmpty) {
                      return field.copyWith(value: null, replaceValue: true);
                    }
                    final parsed = double.tryParse(raw.replaceAll(',', '.'));
                    return parsed == null
                        ? field
                        : field.copyWith(value: parsed, replaceValue: true);
                  }
                  return field;
                })
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    return source.copyWith(sections: nextSections, updatedAt: DateTime.now());
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
        content: const Text('你已经修改了内容，现在返回会丢失本次填写。'),
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
        _fieldValueSignature(_draft) != _initialFieldSignature;
  }

  String _fieldValueSignature(ManagedOption option) {
    final values = <String>[];
    for (final section in option.sections) {
      for (final field in section.fields) {
        values.add('${field.key}=${field.value}');
      }
    }
    return values.join('||');
  }
}
