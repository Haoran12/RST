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
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.icon,
    required this.optionType,
    required this.optionsProvider,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyDescription;
  final IconData icon;
  final ManagedOptionType optionType;
  final StateProvider<List<ManagedOption>> optionsProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(optionsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ListView(
        children: [
          GlassPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PrimaryPillButton(
                      label: '新建',
                      onPressed: () => _createOption(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(option.description),
                      const SizedBox(height: 8),
                      Text(
                        'id: ${option.id} · sections: ${option.sections.length} · updated: ${_formatTime(option.updatedAt)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SecondaryOutlineButton(
                            label: '编辑',
                            onPressed: () => _editOption(context, ref, option),
                          ),
                          TextButton(
                            onPressed: () => _deleteOption(context, ref, option),
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
    final created = await showDialog<ManagedOption>(
      context: context,
      builder: (context) => _ManagedOptionEditorDialog(
        title: '新建$title',
        initialOption: initial,
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
    final edited = await showDialog<ManagedOption>(
      context: context,
      builder: (context) => _ManagedOptionEditorDialog(
        title: '编辑$title',
        initialOption: option,
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

  String _formatTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _ManagedOptionEditorDialog extends StatefulWidget {
  const _ManagedOptionEditorDialog({
    required this.title,
    required this.initialOption,
  });

  final String title;
  final ManagedOption initialOption;

  @override
  State<_ManagedOptionEditorDialog> createState() =>
      _ManagedOptionEditorDialogState();
}

class _ManagedOptionEditorDialogState extends State<_ManagedOptionEditorDialog> {
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              _draft.copyWith(
                name: name,
                description: _descriptionController.text.trim(),
                updatedAt: DateTime.now(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
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
            const SizedBox(height: 4),
            Text(
              section.description,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
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
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helperText,
          ),
        );
      case ManagedFieldType.text:
        return TextField(
          controller: TextEditingController(text: '${field.value ?? ''}'),
          readOnly: field.readOnly,
          onChanged: (value) => _updateField(field.key, value),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helperText,
          ),
        );
      case ManagedFieldType.integer:
        return TextField(
          controller: TextEditingController(text: '${field.value ?? ''}'),
          readOnly: field.readOnly,
          keyboardType: TextInputType.number,
          onChanged: (value) => _updateField(field.key, int.tryParse(value)),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helperText,
          ),
        );
      case ManagedFieldType.decimal:
        return TextField(
          controller: TextEditingController(text: '${field.value ?? ''}'),
          readOnly: field.readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => _updateField(field.key, double.tryParse(value)),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helperText,
          ),
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
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helperText,
          ),
        );
      case ManagedFieldType.toggle:
        return SwitchListTile(
          value: (field.value as bool?) ?? false,
          onChanged: field.readOnly
              ? null
              : (value) => _updateField(field.key, value),
          title: Text(field.label),
          subtitle: field.helperText == null ? null : Text(field.helperText!),
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
