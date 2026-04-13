import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_state.dart';
import '../../../shared/theme/app_colors.dart';
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
  late ManagedOption _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialOption;
    _nameController = TextEditingController(text: widget.initialOption.name);
    _descriptionController = TextEditingController(
      text: widget.initialOption.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      _draft.copyWith(
        name: name,
        description: _descriptionController.text.trim(),
        updatedAt: DateTime.now(),
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
    switch (field.type) {
      case ManagedFieldType.multiline:
        return TextField(
          controller: TextEditingController(text: '${field.value ?? ''}'),
          minLines: 2,
          maxLines: 5,
          readOnly: field.readOnly,
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.text:
        return TextField(
          controller: TextEditingController(text: '${field.value ?? ''}'),
          readOnly: field.readOnly,
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.integer:
        return TextField(
          controller: TextEditingController(text: '${field.value ?? ''}'),
          readOnly: field.readOnly,
          keyboardType: TextInputType.number,
          onChanged: (value) => _updateField(field.key, int.tryParse(value)),
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.decimal:
        return TextField(
          controller: TextEditingController(text: '${field.value ?? ''}'),
          readOnly: field.readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => _updateField(field.key, double.tryParse(value)),
          decoration: InputDecoration(labelText: field.label),
        );
      case ManagedFieldType.select:
      case ManagedFieldType.color:
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
}
