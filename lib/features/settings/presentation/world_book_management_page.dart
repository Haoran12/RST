import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_state.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/world_book_injection.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../../shared/widgets/auto_save_mixin.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import '../../../shared/widgets/structured_text_editor.dart';

const String _worldBookCategoryFieldKey = 'worldbook_ui_categories';
const String _worldBookScanDepthFieldKey = 'worldbook_scan_depth';

enum _WorldBookCategory {
  character('人物'),
  setting('其他设定'),
  memory('世界记忆');

  const _WorldBookCategory(this.label);
  final String label;
}

class _EntryDraft {
  const _EntryDraft({required this.data, required this.category});

  final Map<String, dynamic> data;
  final _WorldBookCategory category;

  _EntryDraft copyWith({
    Map<String, dynamic>? data,
    _WorldBookCategory? category,
  }) {
    return _EntryDraft(
      data: data ?? this.data,
      category: category ?? this.category,
    );
  }
}

class WorldBookManagementPage extends ConsumerWidget {
  const WorldBookManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(worldBookOptionsProvider);
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
                      label: '新建世界书',
                      onPressed: () => _create(context, ref),
                    ),
                    SecondaryOutlineButton(
                      label: '刷新',
                      onPressed: () => _refresh(context, ref),
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
          if (options.isEmpty)
            EmptyStateView(
              title: '暂无世界书',
              description: '',
              actionLabel: '新建世界书',
              onAction: () => _create(context, ref),
            )
          else
            ...options.map((option) => _buildCard(context, ref, option)),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, ManagedOption option) {
    final entries = _loadEntries(option);
    final c1 = entries
        .where((e) => e.category == _WorldBookCategory.character)
        .length;
    final c2 = entries
        .where((e) => e.category == _WorldBookCategory.setting)
        .length;
    final c3 = entries
        .where((e) => e.category == _WorldBookCategory.memory)
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanelCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '人物 $c1 · 其他设定 $c2 · 世界记忆 $c3',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '编辑',
              onPressed: () => _edit(context, ref, option),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: () => _delete(context, ref, option),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final init = buildManagedOptionTemplate(
      ManagedOptionType.worldBook,
      id: 'wb-${DateTime.now().millisecondsSinceEpoch}',
      name: '新建世界书',
      description: '',
    );
    final saved = await Navigator.of(context).push<ManagedOption>(
      MaterialPageRoute<ManagedOption>(
        fullscreenDialog: true,
        builder: (_) => WorldBookEditorPage(title: '新建世界书', initial: init),
      ),
    );
    if (saved == null) {
      return;
    }
    final notifier = ref.read(worldBookOptionsProvider.notifier);
    final next = <ManagedOption>[saved, ...notifier.state];
    notifier.state = next;
    if (!context.mounted) {
      return;
    }
    await _persistWorldBookCatalog(context, ref, next);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ManagedOption option,
  ) async {
    final saved = await Navigator.of(context).push<ManagedOption>(
      MaterialPageRoute<ManagedOption>(
        fullscreenDialog: true,
        builder: (_) => WorldBookEditorPage(title: '编辑世界书', initial: option),
      ),
    );
    if (saved == null) {
      return;
    }
    final notifier = ref.read(worldBookOptionsProvider.notifier);
    final next = notifier.state
        .map((item) => item.id == saved.id ? saved : item)
        .toList(growable: false);
    notifier.state = next;
    if (!context.mounted) {
      return;
    }
    await _persistWorldBookCatalog(context, ref, next);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ManagedOption option,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        title: const Text('删除世界书'),
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
    final notifier = ref.read(worldBookOptionsProvider.notifier);
    final next = notifier.state
        .where((item) => item.id != option.id)
        .toList(growable: false);
    notifier.state = next;
    if (!context.mounted) {
      return;
    }
    await _persistWorldBookCatalog(context, ref, next);
  }

  Future<void> _persistWorldBookCatalog(
    BuildContext context,
    WidgetRef ref,
    List<ManagedOption> options,
  ) async {
    try {
      await ref.read(apiServiceProvider).saveWorldBookCatalog(options);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '世界书保存失败: $error',
        tone: AppNoticeTone.error,
        category: 'worldbook_save_failed',
      );
    }
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      final loaded = await ref.read(apiServiceProvider).loadWorldBookCatalog();
      if (!context.mounted) {
        return;
      }
      if (loaded != null) {
        ref.read(worldBookOptionsProvider.notifier).state = loaded;
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '刷新失败: $error',
        tone: AppNoticeTone.error,
        category: 'worldbook_refresh_failed',
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    // TODO: 实现导入功能
    AppNotice.show(
      context,
      message: '导入功能即将上线',
      tone: AppNoticeTone.info,
      category: 'worldbook_import_placeholder',
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    // TODO: 实现导出功能
    AppNotice.show(
      context,
      message: '导出功能即将上线',
      tone: AppNoticeTone.info,
      category: 'worldbook_export_placeholder',
    );
  }
}

class WorldBookEditorPage extends StatefulWidget {
  const WorldBookEditorPage({
    super.key,
    required this.title,
    required this.initial,
  });

  final String title;
  final ManagedOption initial;

  @override
  State<WorldBookEditorPage> createState() => WorldBookEditorPageState();
}

class WorldBookEditorPageState extends State<WorldBookEditorPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, AutoSaveMixin {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _scanDepth = TextEditingController(
    text: '${_loadScanDepth(widget.initial)}',
  );
  late final TabController _tabs = TabController(
    length: _WorldBookCategory.values.length,
    vsync: this,
  );
  late List<_EntryDraft> _entries = _loadEntries(widget.initial);
  late final String _initialSignature = _signature(
    widget.initial.name,
    _entries,
  );

  @override
  bool get hasUnsavedChanges =>
      _signature(_name.text, _entries) != _initialSignature;

  @override
  Future<void> performAutoSave() async {
    if (!hasUnsavedChanges) return;
    _saveAndPop(pop: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _scanDepth.dispose();
    _tabs.dispose();
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
        final shouldClose = await _confirmDiscard();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final shouldClose = await _confirmDiscard();
              if (!mounted || !shouldClose) {
                return;
              }
              Navigator.of(this.context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(widget.title),
          actions: [TextButton(onPressed: _save, child: const Text('保存'))],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  children: [
                    GlassPanelCard(
                      child: Column(
                        children: [
                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: '世界书名称',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('扫描深度'),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                height: 36,
                                child: TextField(
                                  controller: _scanDepth,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: GlassPanelCard(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          children: [
                            TabBar(
                              controller: _tabs,
                              tabs: _WorldBookCategory.values
                                  .map((item) => Tab(text: item.label))
                                  .toList(growable: false),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TabBarView(
                                controller: _tabs,
                                children: _WorldBookCategory.values
                                    .map((item) => _buildTab(item))
                                    .toList(growable: false),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildTab(_WorldBookCategory category) {
    final rows = _entries
        .where((item) => item.category == category)
        .toList(growable: false);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: '新增条目',
            onPressed: () => _add(category),
            icon: const Icon(Icons.add),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? const EmptyStateView(
                  title: '暂无条目',
                  description: '',
                  actionLabel: '',
                  onAction: null,
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final entry = rows[index];
                    final uid = _asInt(entry.data['uid']);
                    return GlassPanelCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      backgroundColor: entry.data['disable'] == true
                          ? AppColors.surfaceOverlay.withValues(alpha: 0.55)
                          : AppColors.surfaceCard.withValues(alpha: 0.92),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _entryTitle(entry.data),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontSize: 14, height: 1.15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'uid $uid · order ${_asInt(entry.data['order'])} · position ${_asInt(entry.data['position'])}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _MiniIcon(
                            tip: '编辑条目',
                            icon: Icons.edit_outlined,
                            onTap: () => _edit(uid),
                          ),
                          _MiniIcon(
                            tip: '复制条目',
                            icon: Icons.content_copy_outlined,
                            onTap: () => _copy(uid),
                          ),
                          _MiniIcon(
                            tip: '删除条目',
                            icon: Icons.delete_outline_rounded,
                            onTap: () => _delete(uid),
                            color: AppColors.error,
                          ),
                          Transform.scale(
                            scale: 0.78,
                            child: Switch.adaptive(
                              value: !(entry.data['disable'] == true),
                              onChanged: (value) => _toggle(uid, value),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _add(_WorldBookCategory category) {
    final uid = _nextUid(_entries);
    final entry = _EntryDraft(data: _defaultEntry(uid), category: category);
    setState(() {
      _entries = <_EntryDraft>[..._entries, entry];
    });
    _edit(uid);
  }

  Future<void> _edit(int uid) async {
    final index = _entries.indexWhere(
      (item) => _asInt(item.data['uid']) == uid,
    );
    if (index < 0) {
      return;
    }
    final updated = await Navigator.of(context).push<_EntryDraft>(
      MaterialPageRoute<_EntryDraft>(
        builder: (_) => _EntryEditorPage(initial: _entries[index]),
      ),
    );
    if (updated == null) {
      return;
    }
    setState(() {
      final next = _entries.toList(growable: true);
      next[index] = updated;
      _entries = next;
    });
  }

  void _copy(int uid) {
    final index = _entries.indexWhere(
      (item) => _asInt(item.data['uid']) == uid,
    );
    if (index < 0) {
      return;
    }
    final nextUid = _nextUid(_entries);
    final copied = Map<String, dynamic>.from(_entries[index].data);
    copied['uid'] = nextUid;
    copied['displayIndex'] = nextUid;
    setState(() {
      final next = _entries.toList(growable: true)
        ..insert(index + 1, _entries[index].copyWith(data: copied));
      _entries = next;
    });
  }

  void _delete(int uid) {
    setState(() {
      _entries = _entries
          .where((item) => _asInt(item.data['uid']) != uid)
          .toList(growable: false);
    });
  }

  void _toggle(int uid, bool enabled) {
    final index = _entries.indexWhere(
      (item) => _asInt(item.data['uid']) == uid,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      final next = _entries.toList(growable: true);
      final data = Map<String, dynamic>.from(next[index].data);
      data['disable'] = !enabled;
      next[index] = next[index].copyWith(data: data);
      _entries = next;
    });
  }

  void _save() {
    _saveAndPop(pop: true);
  }

  void _saveAndPop({required bool pop}) {
    final name = _name.text.trim();
    if (name.isEmpty) {
      if (mounted && pop) {
        AppNotice.show(
          context,
          message: '世界书名称不能为空',
          tone: AppNoticeTone.warning,
          category: 'worldbook_name_required',
        );
      }
      return;
    }

    final entries = <String, dynamic>{};
    final categories = <String, String>{};
    for (var i = 0; i < _entries.length; i += 1) {
      final data = Map<String, dynamic>.from(_entries[i].data);
      final uid = _asInt(data['uid']);
      data['displayIndex'] = i;
      entries['$uid'] = data;
      categories['$uid'] = _entries[i].category.name;
    }
    final worldbookJson = jsonEncode(<String, dynamic>{'entries': entries});
    final categoryJson = jsonEncode(categories);
    final scanDepthValue = _asInt(_scanDepth.text).clamp(0, 2048);

    var sections = widget.initial.sections;
    sections = _upsertField(sections, worldBookJsonFieldKey, worldbookJson);
    sections = _upsertField(sections, _worldBookCategoryFieldKey, categoryJson);
    sections = _upsertField(
      sections,
      _worldBookScanDepthFieldKey,
      '$scanDepthValue',
    );

    final saved = widget.initial.copyWith(
      name: name,
      sections: sections,
      updatedAt: DateTime.now(),
    );

    if (pop && mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_signature(_name.text, _entries) == _initialSignature) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
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
}

class _EntryEditorPage extends StatefulWidget {
  const _EntryEditorPage({required this.initial});

  final _EntryDraft initial;

  @override
  State<_EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<_EntryEditorPage>
    with WidgetsBindingObserver, AutoSaveMixin {
  late _EntryDraft _draft = widget.initial;
  late final TextEditingController _comment = TextEditingController(
    text: '${_draft.data['comment'] ?? ''}',
  );
  late final TextEditingController _key = TextEditingController(
    text: _listToCsv(_draft.data['key']),
  );
  late final TextEditingController _keysecondary = TextEditingController(
    text: _listToCsv(_draft.data['keysecondary']),
  );
  late final TextEditingController _probabilityPercent = TextEditingController(
    text: _getProbabilityPercentText(_draft.data),
  );
  late final String _initialSignature = _entrySignature(_draft);

  static String _getProbabilityPercentText(Map<String, dynamic> data) {
    final useProbability = data['useProbability'] != false;
    if (useProbability) {
      return '100';
    }
    final probability = _asInt(data['probability']).clamp(0, 100);
    return '$probability';
  }

  @override
  bool get hasUnsavedChanges =>
      _entrySignature(_buildResult()) != _initialSignature;

  @override
  Future<void> performAutoSave() async {
    if (!hasUnsavedChanges || !mounted) return;
    Navigator.of(context).pop(_buildResult());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _comment.dispose();
    _key.dispose();
    _keysecondary.dispose();
    _probabilityPercent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _asInt(_draft.data['uid']);
    return PopScope<_EntryDraft>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _confirmDiscard();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop(_buildResult());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final shouldClose = await _confirmDiscard();
              if (!mounted || !shouldClose) {
                return;
              }
              Navigator.of(this.context).pop(_buildResult());
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(_entryTitle(_draft.data)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  GlassPanelCard(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('uid: $uid'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<_WorldBookCategory>(
                          initialValue: _draft.category,
                          items: _WorldBookCategory.values
                              .map(
                                (item) => DropdownMenuItem<_WorldBookCategory>(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(
                              () => _draft = _draft.copyWith(category: value),
                            );
                          },
                          decoration: const InputDecoration(labelText: 'tab'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _comment,
                          decoration: const InputDecoration(
                            labelText: 'comment',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _key,
                          decoration: const InputDecoration(labelText: 'key'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _keysecondary,
                          decoration: const InputDecoration(
                            labelText: 'keysecondary',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanelCard(
                    child: StructuredTextEditor(
                      initialText: '${_draft.data['content'] ?? ''}',
                      hintText: 'content',
                      onChanged: (value) {
                        final next = Map<String, dynamic>.from(_draft.data);
                        next['content'] = value;
                        setState(() => _draft = _draft.copyWith(data: next));
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanelCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _draft.data['constant'] == true,
                          onChanged: (v) => _setBool('constant', v),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('constant'),
                        ),
                        Row(
                          children: [
                            const Expanded(child: Text('概率 (%)')),
                            SizedBox(
                              width: 100,
                              height: 36,
                              child: TextField(
                                controller: _probabilityPercent,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  hintText: '0.1-100',
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanelCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('高级选项'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAdvancedOptions(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setBool(String key, bool value) {
    final next = Map<String, dynamic>.from(_draft.data);
    next[key] = value;
    setState(() => _draft = _draft.copyWith(data: next));
  }

  Future<void> _openAdvancedOptions() async {
    final updated = await Navigator.of(context).push<_EntryDraft>(
      MaterialPageRoute<_EntryDraft>(
        builder: (_) => _EntryAdvancedOptionsPage(initial: _draft),
      ),
    );
    if (updated != null) {
      setState(() => _draft = updated);
    }
  }

  _EntryDraft _buildResult() {
    final next = Map<String, dynamic>.from(_draft.data);
    next['comment'] = _comment.text.trim();
    next['key'] = _csvToList(_key.text);
    next['keysecondary'] = _csvToList(_keysecondary.text);
    final percentValue = _parseProbabilityPercent(_probabilityPercent.text);
    if (percentValue > 99) {
      next['useProbability'] = false;
      next['probability'] = 100;
    } else {
      next['useProbability'] = true;
      next['probability'] = percentValue.round();
    }
    return _draft.copyWith(data: next);
  }

  Future<bool> _confirmDiscard() async {
    final currentSignature = _entrySignature(_buildResult());
    if (currentSignature == _initialSignature) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
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

  static int _parseProbabilityPercent(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 100;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return 100;
    return parsed.clamp(0.0, 100.0).round();
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.tip,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String tip;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        tooltip: tip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        icon: Icon(icon, color: color),
      ),
    );
  }
}

class _EntryAdvancedOptionsPage extends StatefulWidget {
  const _EntryAdvancedOptionsPage({required this.initial});

  final _EntryDraft initial;

  @override
  State<_EntryAdvancedOptionsPage> createState() =>
      _EntryAdvancedOptionsPageState();
}

class _EntryAdvancedOptionsPageState extends State<_EntryAdvancedOptionsPage> {
  late Map<String, dynamic> _data = Map<String, dynamic>.from(
    widget.initial.data,
  );
  late final TextEditingController _order = TextEditingController(
    text: '${_asInt(_data['order'])}',
  );
  late final TextEditingController _position = TextEditingController(
    text: '${_asInt(_data['position'])}',
  );
  late final TextEditingController _depth = TextEditingController(
    text: '${_asInt(_data['depth'])}',
  );
  late final TextEditingController _probability = TextEditingController(
    text: '${_asInt(_data['probability'])}',
  );
  late final TextEditingController _group = TextEditingController(
    text: '${_data['group'] ?? ''}',
  );
  late final TextEditingController _scanDepth = TextEditingController(
    text: '${_data['scanDepth'] ?? ''}',
  );
  late final TextEditingController _selectiveLogic = TextEditingController(
    text: '${_asInt(_data['selectiveLogic'])}',
  );
  late final TextEditingController _groupWeight = TextEditingController(
    text: '${_asInt(_data['groupWeight'])}',
  );
  late final TextEditingController _sticky = TextEditingController(
    text: '${_asInt(_data['sticky'])}',
  );
  late final TextEditingController _cooldown = TextEditingController(
    text: '${_asInt(_data['cooldown'])}',
  );
  late final TextEditingController _delay = TextEditingController(
    text: '${_asInt(_data['delay'])}',
  );
  late final TextEditingController _automationId = TextEditingController(
    text: '${_data['automationId'] ?? ''}',
  );

  @override
  void dispose() {
    _order.dispose();
    _position.dispose();
    _depth.dispose();
    _probability.dispose();
    _group.dispose();
    _scanDepth.dispose();
    _selectiveLogic.dispose();
    _groupWeight.dispose();
    _sticky.dispose();
    _cooldown.dispose();
    _delay.dispose();
    _automationId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('高级选项'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                GlassPanelCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _data['disable'] == true,
                        onChanged: (v) => _setBool('disable', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('disable'),
                      ),
                      SwitchListTile(
                        value: _data['selective'] != false,
                        onChanged: (v) => _setBool('selective', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('selective'),
                      ),
                      SwitchListTile(
                        value: _data['preventRecursion'] == true,
                        onChanged: (v) => _setBool('preventRecursion', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('preventRecursion'),
                      ),
                      SwitchListTile(
                        value: _data['vectorized'] == true,
                        onChanged: (v) => _setBool('vectorized', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('vectorized'),
                      ),
                      SwitchListTile(
                        value: _data['addMemo'] != false,
                        onChanged: (v) => _setBool('addMemo', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('addMemo'),
                      ),
                      SwitchListTile(
                        value: _data['ignoreBudget'] == true,
                        onChanged: (v) => _setBool('ignoreBudget', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ignoreBudget'),
                      ),
                      SwitchListTile(
                        value: _data['excludeRecursion'] == true,
                        onChanged: (v) => _setBool('excludeRecursion', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('excludeRecursion'),
                      ),
                      SwitchListTile(
                        value: _data['groupOverride'] == true,
                        onChanged: (v) => _setBool('groupOverride', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('groupOverride'),
                      ),
                      SwitchListTile(
                        value: _data['delayUntilRecursion'] == true,
                        onChanged: (v) => _setBool('delayUntilRecursion', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('delayUntilRecursion'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GlassPanelCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _data['matchPersonaDescription'] == true,
                        onChanged: (v) =>
                            _setBool('matchPersonaDescription', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('matchPersonaDescription'),
                      ),
                      SwitchListTile(
                        value: _data['matchCharacterDescription'] == true,
                        onChanged: (v) =>
                            _setBool('matchCharacterDescription', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('matchCharacterDescription'),
                      ),
                      SwitchListTile(
                        value: _data['matchCharacterPersonality'] == true,
                        onChanged: (v) =>
                            _setBool('matchCharacterPersonality', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('matchCharacterPersonality'),
                      ),
                      SwitchListTile(
                        value: _data['matchCharacterDepthPrompt'] == true,
                        onChanged: (v) =>
                            _setBool('matchCharacterDepthPrompt', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('matchCharacterDepthPrompt'),
                      ),
                      SwitchListTile(
                        value: _data['matchScenario'] == true,
                        onChanged: (v) => _setBool('matchScenario', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('matchScenario'),
                      ),
                      SwitchListTile(
                        value: _data['matchCreatorNotes'] == true,
                        onChanged: (v) => _setBool('matchCreatorNotes', v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('matchCreatorNotes'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GlassPanelCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _order,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'order'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _position,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'position',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _depth,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'depth'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _probability,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'probability',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _group,
                        decoration: const InputDecoration(labelText: 'group'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _scanDepth,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'scanDepth (留空使用世界书默认值)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _selectiveLogic,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'selectiveLogic',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _groupWeight,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'groupWeight',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GlassPanelCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _sticky,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'sticky'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cooldown,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'cooldown',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _delay,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'delay'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _automationId,
                        decoration: const InputDecoration(
                          labelText: 'automationId',
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

  void _setBool(String key, bool value) {
    final next = Map<String, dynamic>.from(_data);
    next[key] = value;
    setState(() => _data = next);
  }

  _EntryDraft _buildResult() {
    final next = Map<String, dynamic>.from(_data);
    next['order'] = _asInt(_order.text);
    next['position'] = _asInt(_position.text);
    next['depth'] = _asInt(_depth.text);
    next['probability'] = _asInt(_probability.text).clamp(0, 100);
    next['group'] = _group.text.trim();
    final scanDepthText = _scanDepth.text.trim();
    next['scanDepth'] = scanDepthText.isEmpty ? null : _asInt(scanDepthText);
    next['selectiveLogic'] = _asInt(_selectiveLogic.text);
    next['groupWeight'] = _asInt(_groupWeight.text);
    next['sticky'] = _asInt(_sticky.text);
    next['cooldown'] = _asInt(_cooldown.text);
    next['delay'] = _asInt(_delay.text);
    next['automationId'] = _automationId.text.trim();
    return widget.initial.copyWith(data: next);
  }
}

List<_EntryDraft> _loadEntries(ManagedOption option) {
  final parsed = parseWorldBookEntries(option);
  final categoryMap = _loadCategoryMap(option);
  final rows = parsed
      .map(
        (item) => _EntryDraft(
          data: Map<String, dynamic>.from(item),
          category: _categoryFromName(categoryMap['${_asInt(item['uid'])}']),
        ),
      )
      .toList(growable: false);
  rows.sort(
    (a, b) => _asInt(
      a.data['displayIndex'],
    ).compareTo(_asInt(b.data['displayIndex'])),
  );
  return rows;
}

Map<String, String> _loadCategoryMap(ManagedOption option) {
  final raw = option.fieldValue(_worldBookCategoryFieldKey);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', '$value'));
      }
    } catch (_) {}
  }
  return const <String, String>{};
}

int _loadScanDepth(ManagedOption option) {
  final raw = option.fieldValue(_worldBookScanDepthFieldKey);
  if (raw is String && raw.trim().isNotEmpty) {
    return _asInt(raw);
  }
  return 4;
}

List<ManagedOptionSection> _upsertField(
  List<ManagedOptionSection> sections,
  String key,
  String value,
) {
  if (sections.isEmpty) {
    return <ManagedOptionSection>[
      ManagedOptionSection(
        title: '基础信息',
        description: '',
        fields: <ManagedOptionField>[
          ManagedOptionField(
            key: key,
            label: key,
            type: ManagedFieldType.multiline,
            value: value,
          ),
        ],
      ),
    ];
  }
  var updated = false;
  final next = sections
      .map(
        (section) => section.copyWith(
          fields: section.fields
              .map((field) {
                if (field.key != key) {
                  return field;
                }
                updated = true;
                return field.copyWith(value: value, replaceValue: true);
              })
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
  if (updated) {
    return next;
  }
  final head = next.first;
  final fields = head.fields.toList(growable: true)
    ..add(
      ManagedOptionField(
        key: key,
        label: key,
        type: ManagedFieldType.multiline,
        value: value,
      ),
    );
  return <ManagedOptionSection>[head.copyWith(fields: fields), ...next.skip(1)];
}

Map<String, dynamic> _defaultEntry(int uid) {
  return <String, dynamic>{
    'uid': uid,
    'key': <String>[],
    'keysecondary': <String>[],
    'comment': '条目 $uid',
    'content': '',
    'constant': false,
    'vectorized': false,
    'selective': true,
    'selectiveLogic': 0,
    'addMemo': true,
    'order': 100,
    'position': 0,
    'disable': false,
    'ignoreBudget': false,
    'excludeRecursion': false,
    'preventRecursion': false,
    'matchPersonaDescription': false,
    'matchCharacterDescription': false,
    'matchCharacterPersonality': false,
    'matchCharacterDepthPrompt': false,
    'matchScenario': false,
    'matchCreatorNotes': false,
    'delayUntilRecursion': false,
    'probability': 100,
    'useProbability': true,
    'depth': 4,
    'group': '',
    'groupOverride': false,
    'groupWeight': 100,
    'scanDepth': null,
    'caseSensitive': null,
    'matchWholeWords': null,
    'useGroupScoring': null,
    'automationId': '',
    'role': null,
    'sticky': 0,
    'cooldown': 0,
    'delay': 0,
    'triggers': <String>[],
    'displayIndex': uid,
    'characterFilter': <String, dynamic>{
      'isExclude': false,
      'names': <String>[],
      'tags': <String>[],
    },
  };
}

_WorldBookCategory _categoryFromName(String? raw) {
  for (final value in _WorldBookCategory.values) {
    if (value.name == raw) {
      return value;
    }
  }
  return _WorldBookCategory.setting;
}

int _nextUid(List<_EntryDraft> entries) {
  var maxUid = -1;
  for (final entry in entries) {
    final uid = _asInt(entry.data['uid']);
    if (uid > maxUid) {
      maxUid = uid;
    }
  }
  return maxUid + 1;
}

String _entryTitle(Map<String, dynamic> entry) {
  final comment = '${entry['comment'] ?? ''}'.trim();
  if (comment.isNotEmpty) {
    return comment;
  }
  final key = entry['key'];
  if (key is List && key.isNotEmpty) {
    return '${key.first}';
  }
  return 'uid ${_asInt(entry['uid'])}';
}

String _entrySignature(_EntryDraft entry) {
  return jsonEncode(entry.data);
}

String _signature(String name, List<_EntryDraft> entries) {
  final normalized = entries
      .map(
        (entry) => <String, dynamic>{
          'category': entry.category.name,
          'data': entry.data,
        },
      )
      .toList(growable: false);
  return '$name::${jsonEncode(normalized)}';
}

String _listToCsv(Object? raw) {
  if (raw is! List) {
    return '';
  }
  return raw.map((item) => '$item').join(', ');
}

List<String> _csvToList(String raw) {
  return raw
      .split(RegExp(r'[,，\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _asInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse('$raw'.trim()) ?? 0;
}
