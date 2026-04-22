import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/workspace_config.dart';
import '../../../core/providers/config_catalog_providers.dart';
import '../../../core/providers/service_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/theme_tokens.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import '../../../shared/widgets/structured_text_editor.dart';

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
            child: Row(
              children: [
                Wrap(
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
                              ?.copyWith(
                                color: AppThemeTokens.textSecondary(context),
                              ),
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
        builder: (context) => PresetEditorPage(
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
      useRootNavigator: false,
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

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      const jsonType = XTypeGroup(label: 'json', extensions: <String>['json']);
      final selected = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[jsonType],
        confirmButtonText: '导入预设',
      );
      if (selected == null || !context.mounted) {
        return;
      }

      final existing = await ref.read(presetCatalogProvider.future);
      final result = await ref
          .read(importExportServiceProvider)
          .importPresetFromFile(
            filePath: selected.path,
            existingPresets: existing,
          );
      await ref.read(presetCatalogProvider.notifier).save(result.value);
      if (!context.mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: result.hasWarnings
            ? '导入完成，含 ${result.warnings.length} 条警告'
            : '导入成功',
        tone: result.hasWarnings
            ? AppNoticeTone.warning
            : AppNoticeTone.success,
        category: 'preset_import_result',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '导入失败: $error',
        tone: AppNoticeTone.error,
        category: 'preset_import_failed',
      );
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final presets = await ref.read(presetCatalogProvider.future);
    if (!context.mounted) {
      return;
    }
    if (presets.isEmpty) {
      AppNotice.show(
        context,
        message: '没有可导出的预设',
        tone: AppNoticeTone.warning,
        category: 'preset_export_empty',
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    final target = await _pickPreset(context, presets);
    if (target == null || !context.mounted) {
      return;
    }

    try {
      const jsonType = XTypeGroup(label: 'json', extensions: <String>['json']);
      final location = await getSaveLocation(
        acceptedTypeGroups: const <XTypeGroup>[jsonType],
        suggestedName: '${target.name}.rst-preset.json',
        confirmButtonText: '导出预设',
      );
      if (location == null || !context.mounted) {
        return;
      }
      await ref
          .read(importExportServiceProvider)
          .exportPresetToFile(preset: target, outputPath: location.path);
      if (!context.mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '导出成功',
        tone: AppNoticeTone.success,
        category: 'preset_export_success',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '导出失败: $error',
        tone: AppNoticeTone.error,
        category: 'preset_export_failed',
      );
    }
  }

  Future<StoredPresetConfig?> _pickPreset(
    BuildContext context,
    List<StoredPresetConfig> presets,
  ) async {
    if (presets.length == 1) {
      return presets.first;
    }
    return showDialog<StoredPresetConfig>(
      context: context,
      useRootNavigator: false,
      builder: (context) => SimpleDialog(
        title: const Text('选择预设'),
        children: presets
            .map(
              (preset) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(preset),
                child: Text(preset.name),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class PresetEditorPage extends ConsumerStatefulWidget {
  const PresetEditorPage({
    super.key,
    required this.title,
    required this.initialValue,
  });

  final String title;
  final StoredPresetConfig initialValue;

  @override
  ConsumerState<PresetEditorPage> createState() => PresetEditorPageState();
}

class PresetEditorPageState extends ConsumerState<PresetEditorPage> {
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppThemeTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: _inputDecoration('输入预设名称'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryPillButton(label: '新增条目', onPressed: _addEntry),
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
              onEdit: _isLockedInteractiveInput(entry)
                  ? null
                  : () => _openEntryEditor(index),
              onCopy: () => _copyEntry(index),
              onDelete: entry.isBuiltin ? null : () => _deleteEntry(index),
              onEnabledChanged: _isLockedInteractiveInput(entry)
                  ? null
                  : (value) {
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
      backgroundColor: AppThemeTokens.panel(
        context,
      ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.96 : 0.88),
      borderColor: AppThemeTokens.borderStrong(context).withValues(alpha: 0.45),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isDirty() ? '当前草稿有未保存修改' : '当前内容已保存',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isDirty()
                    ? AppColors.accentSecondary
                    : AppThemeTokens.textSecondary(context),
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
    if (_isLockedInteractiveInput(entry)) {
      return;
    }
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
      useRootNavigator: false,
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
        AppNotice.show(
          context,
          message: '当前预设已包含该系统内置条目，不重复复制。',
          tone: AppNoticeTone.warning,
          category: 'preset_builtin_duplicate',
        );
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
      AppNotice.show(
        context,
        message: '条目已复制到“${target.presetName}”',
        tone: AppNoticeTone.success,
        category: 'preset_entry_copied',
      );
    }
  }

  Future<void> _deleteEntry(int index) async {
    final entry = _draft.entries[index];
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
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
      AppNotice.show(
        context,
        message: '预设名称不能为空',
        tone: AppNoticeTone.warning,
        category: 'preset_name_required',
      );
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
        AppNotice.show(
          context,
          message: '保存失败: $error',
          tone: AppNoticeTone.error,
          category: 'preset_save_failed',
        );
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
      useRootNavigator: false,
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

  bool _isLockedInteractiveInput(StoredPresetEntry entry) {
    return entry.builtinKey == PresetBuiltinEntryKeys.interactiveInput;
  }

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
      hintStyle: TextStyle(color: AppThemeTokens.textMuted(context)),
      filled: true,
      fillColor: AppThemeTokens.fieldFill(
        context,
      ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.9 : 0.52),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppThemeTokens.border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppThemeTokens.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppThemeTokens.borderStrong(context)),
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
  final VoidCallback? onEdit;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      backgroundColor: entry.enabled
          ? AppThemeTokens.card(
              context,
            ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.98 : 0.92)
          : AppThemeTokens.panel(
              context,
            ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.76 : 0.55),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(
              width: 28,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppThemeTokens.panel(context).withValues(
                  alpha: AppThemeTokens.isLight(context) ? 0.9 : 0.6,
                ),
                border: Border.all(color: AppThemeTokens.border(context)),
              ),
              child: const Icon(Icons.drag_indicator_rounded, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontSize: 14, height: 1.15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _EntryMetaPill(
                  label: entry.role.displayLabel,
                  accentColor: entry.enabled
                      ? AppThemeTokens.textSecondary(context)
                      : AppThemeTokens.textMuted(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactIconButton(
                tooltip: onEdit == null ? '该条目不可编辑' : '编辑条目',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
              _CompactIconButton(
                tooltip: '复制条目',
                icon: Icons.content_copy_outlined,
                onPressed: onCopy,
              ),
              _CompactIconButton(
                tooltip: entry.isBuiltin ? '该条目不可删除' : '删除条目',
                icon: Icons.delete_outline_rounded,
                iconColor: onDelete == null
                    ? AppColors.error.withValues(alpha: 0.28)
                    : AppColors.error,
                onPressed: onDelete,
              ),
              Transform.scale(
                scale: 0.78,
                child: Switch.adaptive(
                  value: entry.enabled,
                  onChanged: onEnabledChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryMetaPill extends StatelessWidget {
  const _EntryMetaPill({required this.label, this.accentColor});

  final String label;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tint = accentColor ?? AppThemeTokens.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: tint.withValues(alpha: 0.12),
        border: Border.all(color: tint.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: tint, fontSize: 11),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        splashRadius: 16,
        iconSize: 16,
        icon: Icon(icon, color: iconColor),
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
  late StoredPresetEntry _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.entry;
    _titleController = TextEditingController(text: widget.entry.title);
    _titleController.addListener(_handleTitleChanged);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_handleTitleChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                            color: AppThemeTokens.fieldFill(context).withValues(
                              alpha: AppThemeTokens.isLight(context)
                                  ? 0.9
                                  : 0.52,
                            ),
                            border: Border.all(
                              color: AppThemeTokens.border(context),
                            ),
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
                      const Text('内容'),
                      const SizedBox(height: 12),
                      StructuredTextEditor(
                        initialText: _draft.content,
                        hintText: '在这里编辑条目内容',
                        onChanged: _handleContentChanged,
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
      backgroundColor: AppThemeTokens.background(context),
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
                        ? AppThemeTokens.borderStrong(context)
                        : AppThemeTokens.border(context),
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

  void _handleContentChanged(String text) {
    if (text == _draft.content) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(content: text);
    });
    widget.onChanged(_draft);
  }

  InputDecoration _entryDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppThemeTokens.textMuted(context)),
      filled: true,
      fillColor: AppThemeTokens.fieldFill(
        context,
      ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.9 : 0.52),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppThemeTokens.border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppThemeTokens.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppThemeTokens.borderStrong(context)),
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
        color: selected
            ? AppColors.accentSecondary
            : AppThemeTokens.textMuted(context),
      ),
      title: title,
      subtitle: subtitle,
    );
  }
}
