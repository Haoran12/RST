import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:yaml/yaml.dart';

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${preset.entries.length} 个条目',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _PresetEditorPage(
          title: source == null ? '新建预设' : '编辑预设',
          initialValue: draft,
        ),
      ),
    );
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
    if (confirmed == true) {
      await ref.read(presetCatalogProvider.notifier).delete(preset.presetId);
    }
  }
}

class _PresetEditorPage extends ConsumerStatefulWidget {
  const _PresetEditorPage({required this.title, required this.initialValue});

  final String title;
  final StoredPresetConfig initialValue;

  @override
  ConsumerState<_PresetEditorPage> createState() => _PresetEditorPageState();
}

class _PresetEditorPageState extends ConsumerState<_PresetEditorPage> {
  late final TextEditingController _nameController;
  late StoredPresetConfig _draft;
  late StoredPresetConfig _baseline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialValue;
    _baseline = widget.initialValue;
    _nameController = TextEditingController(text: widget.initialValue.name);
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _handleAttemptDismiss();
        if (mounted && shouldClose) {
          Navigator.of(this.context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回预设列表',
            onPressed: () async {
              final shouldClose = await _handleAttemptDismiss();
              if (mounted && shouldClose) {
                Navigator.of(this.context).pop();
              }
            },
            icon: const Icon(Icons.menu_rounded),
          ),
          title: Text(widget.title),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    Expanded(child: _buildEntries(context)),
                    const SizedBox(height: 12),
                    _buildSaveBar(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GlassPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预设名称',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: _inputDecoration('输入预设名称'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '拖拽卡片即可调整 Prompt Builder 的实际顺序。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PrimaryPillButton(label: '新增条目', onPressed: _addEntry),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntries(BuildContext context) {
    return GlassPanelCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: _draft.entries.length,
        onReorder: _reorderEntries,
        itemBuilder: (context, index) {
          final entry = _draft.entries[index];
          return Padding(
            key: ValueKey(entry.entryId),
            padding: const EdgeInsets.only(bottom: 10),
            child: _PresetEntryCard(
              entry: entry,
              index: index,
              onEdit: () => _openEntryEditor(index),
              onCopy: () => _copyEntry(index),
              onDelete: entry.isBuiltin ? null : () => _deleteEntry(index),
              onEnabledChanged: (value) {
                _updateEntry(index, entry.copyWith(enabled: value));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return GlassPanelCard(
      backgroundColor: AppColors.surfaceOverlay.withValues(alpha: 0.88),
      borderColor: AppColors.borderStrong.withValues(alpha: 0.45),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isDirty() ? '当前草稿有未保存修改' : '当前内容已保存',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isDirty()
                    ? AppColors.accentSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEntryEditor(int index) async {
    final entry = _draft.entries[index];
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _PresetEntryEditorPage(
          entry: entry,
          onChanged: (updated) => _updateEntry(index, updated),
        ),
      ),
    );
  }

  Future<void> _copyEntry(int index) async {
    final source = _draft.entries[index];
    final presets = await ref.read(presetCatalogProvider.future);
    if (!mounted) {
      return;
    }
    final target = await showDialog<_CopyTarget>(
      context: context,
      builder: (context) => _CopyEntryDialog(
        currentPresetId: _draft.presetId,
        currentPresetName: _draft.name,
        presets: presets,
      ),
    );
    if (target == null || !mounted) {
      return;
    }

    if (target.presetId == _draft.presetId) {
      if (source.isBuiltin) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前预设已包含该系统内置条目，不重复复制。')));
        return;
      }
      final entries = _draft.entries.toList(growable: true);
      entries.insert(index + 1, _cloneEntry(source));
      setState(() {
        _draft = _draft.copyWith(entries: entries);
      });
      return;
    }

    final targetPreset = presets.firstWhere(
      (item) => item.presetId == target.presetId,
    );
    final updatedPreset = _copyEntryToPreset(targetPreset, source);
    await ref.read(presetCatalogProvider.notifier).save(updatedPreset);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('条目已复制到“${target.presetName}”')));
    }
  }

  Future<void> _deleteEntry(int index) async {
    final entry = _draft.entries[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('确定删除“${entry.title}”？'),
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
    final entries = _draft.entries.toList(growable: true)..removeAt(index);
    setState(() {
      _draft = _draft.copyWith(entries: entries);
    });
  }

  void _addEntry() {
    final entries = _draft.entries.toList(growable: true)
      ..add(
        StoredPresetEntry(
          entryId: 'entry-${DateTime.now().microsecondsSinceEpoch}',
          title: '新条目',
          role: StoredPresetEntryRole.system,
          content: '',
        ),
      );
    setState(() {
      _draft = _draft.copyWith(entries: entries);
    });
    _openEntryEditor(entries.length - 1);
  }

  void _updateEntry(int index, StoredPresetEntry entry) {
    if (index < 0 || index >= _draft.entries.length) {
      return;
    }
    final entries = _draft.entries.toList(growable: true);
    entries[index] = entry;
    setState(() {
      _draft = _draft.copyWith(entries: entries);
    });
  }

  void _reorderEntries(int oldIndex, int newIndex) {
    final entries = _draft.entries.toList(growable: true);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);
    setState(() {
      _draft = _draft.copyWith(entries: entries);
    });
  }

  void _handleNameChanged() {
    if (_nameController.text == _draft.name) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(name: _nameController.text);
    });
  }

  Future<void> _save() async {
    if (_draft.name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('预设名称不能为空')));
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final saved = await ref
          .read(presetCatalogProvider.notifier)
          .save(
            _draft.copyWith(
              name: _draft.name.trim(),
              entries: normalizeStoredPresetEntries(
                _draft.entries,
                legacyMainPrompt: _draft.mainPrompt,
              ),
            ),
          );
      _baseline = saved;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<bool> _handleAttemptDismiss() async {
    if (!_isDirty()) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('当前预设还有未保存的内容，返回后会丢失本次修改。'),
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

  bool _isDirty() =>
      jsonEncode(_draft.toJson()) != jsonEncode(_baseline.toJson());

  StoredPresetEntry _cloneEntry(StoredPresetEntry source) {
    return source.copyWith(
      entryId: 'entry-${DateTime.now().microsecondsSinceEpoch}',
      clearBuiltinKey: true,
    );
  }

  StoredPresetConfig _copyEntryToPreset(
    StoredPresetConfig target,
    StoredPresetEntry source,
  ) {
    final entries = target.entries.toList(growable: true);
    if (source.isBuiltin) {
      final index = entries.indexWhere(
        (item) => item.builtinKey == source.builtinKey,
      );
      final copied = source.copyWith(
        entryId: index >= 0 ? entries[index].entryId : source.entryId,
      );
      if (index >= 0) {
        entries[index] = copied;
      } else {
        entries.add(copied);
      }
    } else {
      entries.add(_cloneEntry(source));
    }
    return target.copyWith(entries: entries);
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceOverlay.withValues(alpha: 0.52),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
    );
  }
}

class _PresetEntryCard extends StatelessWidget {
  const _PresetEntryCard({
    required this.entry,
    required this.index,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onEnabledChanged,
  });

  final StoredPresetEntry entry;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      backgroundColor: entry.enabled
          ? AppColors.surfaceCard.withValues(alpha: 0.92)
          : AppColors.surfaceOverlay.withValues(alpha: 0.55),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.surfaceOverlay.withValues(alpha: 0.6),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.drag_indicator_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (entry.isBuiltin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.accentPrimary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        child: Text(
                          '系统内置',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.accentTertiary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry.role.displayLabel} · ${entry.enabled ? '已启用' : '已停用'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑条目',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '复制条目',
            onPressed: onCopy,
            icon: const Icon(Icons.content_copy_outlined),
          ),
          IconButton(
            tooltip: entry.isBuiltin ? '系统内置条目不可删除' : '删除条目',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: onDelete == null
                  ? AppColors.error.withValues(alpha: 0.35)
                  : AppColors.error,
            ),
          ),
          Switch.adaptive(value: entry.enabled, onChanged: onEnabledChanged),
        ],
      ),
    );
  }
}

class _PresetEntryEditorPage extends StatefulWidget {
  const _PresetEntryEditorPage({required this.entry, required this.onChanged});

  final StoredPresetEntry entry;
  final ValueChanged<StoredPresetEntry> onChanged;

  @override
  State<_PresetEntryEditorPage> createState() => _PresetEntryEditorPageState();
}

class _PresetEntryEditorPageState extends State<_PresetEntryEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late StoredPresetEntry _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.entry;
    _titleController = TextEditingController(text: widget.entry.title);
    _contentController = TextEditingController(text: widget.entry.content);
    _titleController.addListener(_handleTitleChanged);
    _contentController.addListener(_handleContentChanged);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_handleTitleChanged)
      ..dispose();
    _contentController
      ..removeListener(_handleContentChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _EditorContentStatus.analyze(_contentController.text);
    return Scaffold(
      appBar: AppBar(
        title: Text(_draft.title.trim().isEmpty ? '编辑条目' : _draft.title),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                GlassPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('条目标题'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: _entryDecoration('输入条目标题'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GlassPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Role'),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickRole,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.surfaceOverlay.withValues(
                              alpha: 0.52,
                            ),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(_draft.role.displayLabel)),
                              const Icon(Icons.unfold_more_rounded),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GlassPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('内容')),
                          TextButton(
                            onPressed: status.canFormat ? _formatContent : null,
                            child: const Text('格式化'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(label: status.kindLabel),
                          _StatusChip(label: status.pairLabel),
                          const _StatusChip(label: '内容自动保存到草稿'),
                        ],
                      ),
                      if (status.message != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          status.message!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: status.hasIssue
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        height: 420,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderSubtle),
                          color: AppColors.surfaceOverlay.withValues(
                            alpha: 0.42,
                          ),
                        ),
                        child: TextField(
                          controller: _contentController,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                          ),
                          decoration: const InputDecoration(
                            hintText: '在这里编辑条目内容',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
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
    );
  }

  Future<void> _pickRole() async {
    final selected = await showModalBottomSheet<StoredPresetEntryRole>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: StoredPresetEntryRole.values
              .map(
                (role) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassPanelCard(
                    padding: EdgeInsets.zero,
                    borderColor: role == _draft.role
                        ? AppColors.borderStrong
                        : AppColors.borderSubtle,
                    child: ListTile(
                      title: Text(role.displayLabel),
                      trailing: role == _draft.role
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.accentSecondary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(role),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(role: selected);
    });
    widget.onChanged(_draft);
  }

  void _handleTitleChanged() {
    if (_titleController.text == _draft.title) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(title: _titleController.text);
    });
    widget.onChanged(_draft);
  }

  void _handleContentChanged() {
    if (_contentController.text == _draft.content) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(content: _contentController.text);
    });
    widget.onChanged(_draft);
  }

  void _formatContent() {
    final formatted = _EditorContentStatus.format(_contentController.text);
    if (formatted == null) {
      return;
    }
    _contentController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  InputDecoration _entryDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceOverlay.withValues(alpha: 0.52),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
    );
  }
}

class _CopyTarget {
  const _CopyTarget({required this.presetId, required this.presetName});

  final String presetId;
  final String presetName;
}

class _CopyEntryDialog extends StatefulWidget {
  const _CopyEntryDialog({
    required this.currentPresetId,
    required this.currentPresetName,
    required this.presets,
  });

  final String currentPresetId;
  final String currentPresetName;
  final List<StoredPresetConfig> presets;

  @override
  State<_CopyEntryDialog> createState() => _CopyEntryDialogState();
}

class _CopyEntryDialogState extends State<_CopyEntryDialog> {
  late String _selectedPresetId;

  @override
  void initState() {
    super.initState();
    _selectedPresetId = widget.currentPresetId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('复制到预设'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionTile(
                presetId: widget.currentPresetId,
                title: Text('${widget.currentPresetName}（当前预设）'),
              ),
              ...widget.presets
                  .where((item) => item.presetId != widget.currentPresetId)
                  .map(
                    (preset) => _buildOptionTile(
                      presetId: preset.presetId,
                      title: Text(preset.name),
                      subtitle: Text(preset.presetId),
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
            final name = _selectedPresetId == widget.currentPresetId
                ? widget.currentPresetName
                : widget.presets
                      .firstWhere((item) => item.presetId == _selectedPresetId)
                      .name;
            Navigator.of(
              context,
            ).pop(_CopyTarget(presetId: _selectedPresetId, presetName: name));
          },
          child: const Text('确认复制'),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String presetId,
    required Widget title,
    Widget? subtitle,
  }) {
    final selected = presetId == _selectedPresetId;
    return ListTile(
      onTap: () {
        setState(() {
          _selectedPresetId = presetId;
        });
      },
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppColors.accentSecondary : AppColors.textMuted,
      ),
      title: title,
      subtitle: subtitle,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.surfaceOverlay.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

enum _ContentKind { plain, json, yaml }

class _EditorContentStatus {
  const _EditorContentStatus({
    required this.kind,
    required this.canFormat,
    required this.hasIssue,
    this.message,
  });

  final _ContentKind kind;
  final bool canFormat;
  final bool hasIssue;
  final String? message;

  String get kindLabel => switch (kind) {
    _ContentKind.json => '识别为 JSON',
    _ContentKind.yaml => '识别为 YAML',
    _ContentKind.plain => '普通文本',
  };

  String get pairLabel => hasIssue ? '引号 / 括号待检查' : '引号 / 括号正常';

  static _EditorContentStatus analyze(String text) {
    final pairIssue = _pairIssue(text);
    final trimmed = text.trim();
    if (_looksLikeJson(trimmed)) {
      try {
        jsonDecode(trimmed);
        return _EditorContentStatus(
          kind: _ContentKind.json,
          canFormat: true,
          hasIssue: pairIssue != null,
          message: pairIssue ?? '可使用格式化按钮整理缩进。',
        );
      } catch (_) {}
    }
    if (_looksLikeYaml(trimmed)) {
      try {
        loadYaml(trimmed);
        return _EditorContentStatus(
          kind: _ContentKind.yaml,
          canFormat: true,
          hasIssue: pairIssue != null,
          message: pairIssue ?? '已识别为 YAML，可整理缩进。',
        );
      } catch (_) {}
    }
    return _EditorContentStatus(
      kind: _ContentKind.plain,
      canFormat: false,
      hasIssue: pairIssue != null,
      message: pairIssue ?? '未识别为 JSON / YAML，但仍可按普通文本使用。',
    );
  }

  static String? format(String text) {
    final trimmed = text.trim();
    if (_looksLikeJson(trimmed)) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
      } catch (_) {}
    }
    if (_looksLikeYaml(trimmed)) {
      try {
        return json2yaml(_yamlToPlain(loadYaml(trimmed)));
      } catch (_) {}
    }
    return null;
  }

  static bool _looksLikeJson(String text) {
    return (text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'));
  }

  static bool _looksLikeYaml(String text) {
    return text.startsWith('---') ||
        text.contains(': ') ||
        text.contains(':\n') ||
        text.contains('\n- ');
  }

  static dynamic _yamlToPlain(dynamic input) {
    if (input is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        input.entries.map(
          (entry) => MapEntry('${entry.key}', _yamlToPlain(entry.value)),
        ),
      );
    }
    if (input is YamlList) {
      return input.map(_yamlToPlain).toList(growable: false);
    }
    return input;
  }

  static String? _pairIssue(String text) {
    final stack = <String>[];
    var inSingle = false;
    var inDouble = false;
    var escaped = false;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (!inSingle && char == '"') {
        inDouble = !inDouble;
        continue;
      }
      if (!inDouble && char == "'") {
        inSingle = !inSingle;
        continue;
      }
      if (inSingle || inDouble) {
        continue;
      }
      if (char == '{' || char == '[' || char == '(') {
        stack.add(char);
      } else if (char == '}' || char == ']' || char == ')') {
        if (stack.isEmpty) {
          return '检测到未配对的右括号。';
        }
        final last = stack.removeLast();
        if ((last == '{' && char != '}') ||
            (last == '[' && char != ']') ||
            (last == '(' && char != ')')) {
          return '括号类型不匹配。';
        }
      }
    }
    if (inSingle || inDouble) {
      return '检测到未闭合的引号。';
    }
    if (stack.isNotEmpty) {
      return '检测到未闭合的括号。';
    }
    return null;
  }
}
