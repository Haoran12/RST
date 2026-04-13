import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bridge/frb_api.dart' as frb;
import '../../../core/models/common.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/providers/config_catalog_providers.dart';
import '../../../core/providers/service_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class SessionManagementPage extends ConsumerStatefulWidget {
  const SessionManagementPage({super.key});

  @override
  ConsumerState<SessionManagementPage> createState() =>
      _SessionManagementPageState();
}

class _SessionManagementPageState extends ConsumerState<SessionManagementPage> {
  late Future<List<frb.SessionSummary>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
  }

  Future<List<frb.SessionSummary>> _loadSessions() async {
    final sessions = await ref.read(sessionServiceProvider).listSessions();
    final currentSessionId = ref.read(currentSessionIdProvider);
    final exists = sessions.any((item) => item.sessionId == currentSessionId);
    if (sessions.isNotEmpty && (!exists || currentSessionId == null)) {
      ref.read(currentSessionIdProvider.notifier).state =
          sessions.first.sessionId;
    }
    return sessions;
  }

  void _reload() {
    setState(() {
      _sessionsFuture = _loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSessionId = ref.watch(currentSessionIdProvider);
    ref.listen<int>(workspaceReloadTickProvider, (previous, next) {
      _reload();
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: FutureBuilder<List<frb.SessionSummary>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return EmptyStateView(
              title: '会话加载失败',
              description: '${snapshot.error}',
              actionLabel: '重试',
              onAction: _reload,
            );
          }

          final sessions = snapshot.data ?? const <frb.SessionSummary>[];
          final cards = <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrimaryPillButton(
                    label: '新建会话',
                    onPressed: () => _openCreateDialog(context),
                  ),
                  SecondaryOutlineButton(label: '刷新', onPressed: _reload),
                ],
              ),
            ),
          ];

          if (sessions.isEmpty) {
            cards.add(
              EmptyStateView(
                title: '暂无会话',
                description: '先创建一个会话，再进入聊天和会话设置。',
                actionLabel: '新建会话',
                onAction: () => _openCreateDialog(context),
              ),
            );
          } else {
            for (final session in sessions) {
              final selected = session.sessionId == currentSessionId;
              cards.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ref.read(currentSessionIdProvider.notifier).state =
                          session.sessionId;
                    },
                    child: GlassPanelCard(
                      backgroundColor: selected
                          ? AppColors.surfaceActive.withValues(alpha: 0.92)
                          : null,
                      borderColor: selected
                          ? AppColors.accentSecondary
                          : AppColors.borderSubtle,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.sessionName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: '编辑',
                            onPressed: () =>
                                _openEditDialog(context, session.sessionId),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '删除',
                            onPressed: () => _deleteSession(
                              context,
                              session.sessionId,
                              session.sessionName,
                            ),
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
              );
            }
          }

          return ListView(children: cards);
        },
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final apiOptions = await ref.read(apiConfigCatalogProvider.future);
    final presetOptions = await ref.read(presetCatalogProvider.future);
    if (!context.mounted) {
      return;
    }
    final worldBookOptions = ref.read(worldBookOptionsProvider);
    final sessionService = ref.read(sessionServiceProvider);

    const sessionName = '新会话';
    frb.SessionMode selectedMode = frb.SessionMode.rst;
    String selectedApiId = apiOptions.isNotEmpty
        ? apiOptions.first.apiId
        : ref.read(apiServiceProvider).loadStartupRuntime().apiConfig.apiId;
    String selectedPresetId = presetOptions.isNotEmpty
        ? presetOptions.first.presetId
        : ref
              .read(apiServiceProvider)
              .loadStartupRuntime()
              .presetConfig
              .presetId;
    String? selectedWorldBookId = worldBookOptions.isNotEmpty
        ? worldBookOptions.first.id
        : null;

    final saved = await _openSessionEditor(
      context,
      title: '新建会话',
      actionLabel: '创建',
      initialDraft: _SessionEditorDraft(
        sessionName: sessionName,
        mode: selectedMode,
        apiConfigId: selectedApiId,
        presetId: selectedPresetId,
        worldBookId: selectedWorldBookId,
      ),
      apiOptions: _toEntries(
        apiOptions,
        selector: (item) => item.apiId,
        labelSelector: (item) => item.name,
      ),
      presetOptions: _toEntries(
        presetOptions,
        selector: (item) => item.presetId,
        labelSelector: (item) => item.name,
      ),
      worldBookOptions: _toEntries(
        worldBookOptions,
        selector: (item) => item.id,
        labelSelector: (item) => item.name,
      ),
    );

    if (saved == null) {
      return;
    }

    final created = await sessionService.createSession(
      sessionName: saved.sessionName,
      mode: saved.mode == frb.SessionMode.rst
          ? SessionMode.rst
          : SessionMode.st,
      mainApiConfigId: saved.apiConfigId,
      presetId: saved.presetId,
      stWorldBookId: saved.mode == frb.SessionMode.st
          ? saved.worldBookId
          : null,
    );
    ref.read(currentSessionIdProvider.notifier).state = created.sessionId;
    ref.read(workspaceReloadTickProvider.notifier).state++;
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    _reload();
  }

  Future<void> _openEditDialog(BuildContext context, String sessionId) async {
    final sessionService = ref.read(sessionServiceProvider);
    final loaded = await sessionService.loadSession(sessionId);
    if (!context.mounted) {
      return;
    }

    final apiOptions = await ref.read(apiConfigCatalogProvider.future);
    final presetOptions = await ref.read(presetCatalogProvider.future);
    if (!context.mounted) {
      return;
    }
    final worldBookOptions = ref.read(worldBookOptionsProvider);

    final sessionName = loaded.config.sessionName;
    frb.SessionMode selectedMode = loaded.config.mode;
    String selectedApiId = loaded.config.mainApiConfigId;
    String selectedPresetId = loaded.config.presetId;
    String? selectedWorldBookId = loaded.config.stWorldBookId;

    final saved = await _openSessionEditor(
      context,
      title: '编辑会话',
      actionLabel: '保存',
      initialDraft: _SessionEditorDraft(
        sessionName: sessionName,
        mode: selectedMode,
        apiConfigId: selectedApiId,
        presetId: selectedPresetId,
        worldBookId: selectedWorldBookId,
      ),
      apiOptions: _toEntries(
        apiOptions,
        selector: (item) => item.apiId,
        labelSelector: (item) => item.name,
        fallbackId: loaded.config.mainApiConfigId,
      ),
      presetOptions: _toEntries(
        presetOptions,
        selector: (item) => item.presetId,
        labelSelector: (item) => item.name,
        fallbackId: loaded.config.presetId,
      ),
      worldBookOptions: _toEntries(
        worldBookOptions,
        selector: (item) => item.id,
        labelSelector: (item) => item.name,
      ),
    );

    if (saved == null) {
      return;
    }

    final config = loaded.config;
    await sessionService.saveSession(
      frb.SessionConfig(
        sessionId: config.sessionId,
        sessionName: saved.sessionName,
        mode: saved.mode,
        mainApiConfigId: saved.apiConfigId,
        presetId: saved.presetId,
        stWorldBookId: saved.mode == frb.SessionMode.st
            ? saved.worldBookId
            : null,
        createdAt: config.createdAt,
        updatedAt: config.updatedAt,
      ),
    );
    ref.read(workspaceReloadTickProvider.notifier).state++;
    _reload();
  }

  Future<_SessionEditorDraft?> _openSessionEditor(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required _SessionEditorDraft initialDraft,
    required List<_OptionEntry> apiOptions,
    required List<_OptionEntry> presetOptions,
    required List<_OptionEntry> worldBookOptions,
  }) async {
    final saved = await Navigator.of(context).push<_SessionEditorDraft>(
      MaterialPageRoute<_SessionEditorDraft>(
        fullscreenDialog: true,
        builder: (context) => _SessionEditorPage(
          title: title,
          actionLabel: actionLabel,
          initialDraft: initialDraft,
          apiOptions: apiOptions,
          presetOptions: presetOptions,
          worldBookOptions: worldBookOptions,
        ),
      ),
    );
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    return saved;
  }

  Future<void> _deleteSession(
    BuildContext context,
    String sessionId,
    String sessionName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除“$sessionName”？相关聊天记录会一起移除。'),
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

    await ref.read(sessionServiceProvider).deleteSession(sessionId);
    if (ref.read(currentSessionIdProvider) == sessionId) {
      ref.read(currentSessionIdProvider.notifier).state = null;
    }
    ref.read(workspaceReloadTickProvider.notifier).state++;
    _reload();
  }

  List<_OptionEntry> _toEntries<T>(
    List<T> options, {
    required String Function(T item) selector,
    required String Function(T item) labelSelector,
    String? fallbackId,
    String? fallbackLabel,
  }) {
    final items = options
        .map(
          (item) =>
              _OptionEntry(id: selector(item), label: labelSelector(item)),
        )
        .toList(growable: true);
    if (fallbackId != null && !items.any((item) => item.id == fallbackId)) {
      items.add(
        _OptionEntry(id: fallbackId, label: fallbackLabel ?? fallbackId),
      );
    }
    return items;
  }
}

class _SessionEditorDraft {
  const _SessionEditorDraft({
    required this.sessionName,
    required this.mode,
    required this.apiConfigId,
    required this.presetId,
    this.worldBookId,
  });

  final String sessionName;
  final frb.SessionMode mode;
  final String apiConfigId;
  final String presetId;
  final String? worldBookId;
}

class _SessionEditorPage extends StatefulWidget {
  const _SessionEditorPage({
    required this.title,
    required this.actionLabel,
    required this.initialDraft,
    required this.apiOptions,
    required this.presetOptions,
    required this.worldBookOptions,
  });

  final String title;
  final String actionLabel;
  final _SessionEditorDraft initialDraft;
  final List<_OptionEntry> apiOptions;
  final List<_OptionEntry> presetOptions;
  final List<_OptionEntry> worldBookOptions;

  @override
  State<_SessionEditorPage> createState() => _SessionEditorPageState();
}

class _SessionEditorPageState extends State<_SessionEditorPage> {
  late final TextEditingController _nameController;
  late frb.SessionMode _selectedMode;
  late String _selectedApiId;
  late String _selectedPresetId;
  String? _selectedWorldBookId;
  late final String _initialName;
  late final frb.SessionMode _initialMode;
  late final String _initialApiId;
  late final String _initialPresetId;
  late final String? _initialWorldBookId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialDraft.sessionName,
    );
    _selectedMode = widget.initialDraft.mode;
    _initialMode = widget.initialDraft.mode;
    _selectedApiId = widget.initialDraft.apiConfigId;
    _initialApiId = widget.initialDraft.apiConfigId;
    _selectedPresetId = widget.initialDraft.presetId;
    _initialPresetId = widget.initialDraft.presetId;
    _selectedWorldBookId = widget.initialDraft.worldBookId;
    _initialWorldBookId = widget.initialDraft.worldBookId;
    _initialName = widget.initialDraft.sessionName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<_SessionEditorDraft>(
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
            TextButton(onPressed: _submit, child: Text(widget.actionLabel)),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: GlassPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: '会话名称'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<frb.SessionMode>(
                        initialValue: _selectedMode,
                        items: const [
                          DropdownMenuItem(
                            value: frb.SessionMode.rst,
                            child: Text('RST'),
                          ),
                          DropdownMenuItem(
                            value: frb.SessionMode.st,
                            child: Text('ST'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedMode = value;
                          });
                        },
                        decoration: const InputDecoration(labelText: '模式'),
                      ),
                      const SizedBox(height: 12),
                      _OptionSelector(
                        label: 'API配置',
                        value: _selectedApiId,
                        options: widget.apiOptions,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedApiId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _OptionSelector(
                        label: '预设',
                        value: _selectedPresetId,
                        options: widget.presetOptions,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedPresetId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _OptionSelector(
                        label: '世界书（仅 ST）',
                        value: _selectedWorldBookId,
                        options: widget.worldBookOptions,
                        allowNull: true,
                        onChanged: (value) {
                          setState(() {
                            _selectedWorldBookId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _submit,
                        child: Text(widget.actionLabel),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会话名称不能为空')));
      return;
    }

    Navigator.of(context).pop(
      _SessionEditorDraft(
        sessionName: name,
        mode: _selectedMode,
        apiConfigId: _selectedApiId,
        presetId: _selectedPresetId,
        worldBookId: _selectedWorldBookId,
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
        content: const Text('你已经修改了会话信息，现在返回会丢失本次填写。'),
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
        _selectedMode != _initialMode ||
        _selectedApiId != _initialApiId ||
        _selectedPresetId != _initialPresetId ||
        _selectedWorldBookId != _initialWorldBookId;
  }
}

class _OptionSelector extends StatelessWidget {
  const _OptionSelector({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allowNull = false,
  });

  final String label;
  final String? value;
  final List<_OptionEntry> options;
  final ValueChanged<String?> onChanged;
  final bool allowNull;

  @override
  Widget build(BuildContext context) {
    final values = options.map((item) => item.id).toSet();
    final selected = value != null && values.contains(value) ? value : null;

    final dropdownItems = <DropdownMenuItem<String?>>[];
    if (allowNull) {
      dropdownItems.add(
        const DropdownMenuItem<String?>(value: null, child: Text('不绑定')),
      );
    }
    dropdownItems.addAll(
      options.map(
        (item) =>
            DropdownMenuItem<String?>(value: item.id, child: Text(item.label)),
      ),
    );

    return DropdownButtonFormField<String?>(
      initialValue: selected,
      items: dropdownItems,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _OptionEntry {
  const _OptionEntry({required this.id, required this.label});

  final String id;
  final String label;
}
