import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bridge/frb_api.dart' as frb;
import '../../../core/models/common.dart';
import '../../../core/providers/app_state.dart';
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
            GlassPanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('会话管理', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('创建、重命名、删除会话，并选择当前会话。'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PrimaryPillButton(
                        label: '新建会话',
                        onPressed: () => _openCreateDialog(context),
                      ),
                      const SizedBox(width: 8),
                      SecondaryOutlineButton(
                        label: '打开当前聊天',
                        onPressed: sessions.isEmpty
                            ? null
                            : () {
                                final targetSessionId =
                                    currentSessionId ??
                                    sessions.first.sessionId;
                                ref
                                        .read(currentSessionIdProvider.notifier)
                                        .state =
                                    targetSessionId;
                                ref.read(appTabProvider.notifier).state =
                                    AppTab.chat;
                              },
                      ),
                      const SizedBox(width: 8),
                      SecondaryOutlineButton(label: '刷新', onPressed: _reload),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
                  child: GlassPanelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.sessionName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (selected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSecondary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.accentSecondary,
                                  ),
                                ),
                                child: const Text(
                                  '当前会话',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'id: ${session.sessionId} · mode: ${session.mode.name.toUpperCase()}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'updated: ${_formatTime(session.updatedAt)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            PrimaryPillButton(
                              label: '进入聊天',
                              onPressed: () {
                                ref
                                        .read(currentSessionIdProvider.notifier)
                                        .state =
                                    session.sessionId;
                                ref.read(appTabProvider.notifier).state =
                                    AppTab.chat;
                              },
                            ),
                            const SizedBox(width: 8),
                            SecondaryOutlineButton(
                              label: selected ? '已选中' : '设为当前',
                              onPressed: selected
                                  ? null
                                  : () {
                                      ref
                                          .read(
                                            currentSessionIdProvider.notifier,
                                          )
                                          .state = session
                                          .sessionId;
                                    },
                            ),
                            const SizedBox(width: 8),
                            SecondaryOutlineButton(
                              label: '编辑',
                              onPressed: () =>
                                  _openEditDialog(context, session.sessionId),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _deleteSession(
                                context,
                                session.sessionId,
                                session.sessionName,
                              ),
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
              );
            }
          }

          return ListView(children: cards);
        },
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final runtime = ref.read(apiServiceProvider).loadStartupRuntime();
    final apiOptions = ref.read(apiConfigOptionsProvider);
    final presetOptions = ref.read(presetOptionsProvider);
    final worldBookOptions = ref.read(worldBookOptionsProvider);
    final sessionService = ref.read(sessionServiceProvider);

    final nameController = TextEditingController(text: '新会话');
    frb.SessionMode selectedMode = frb.SessionMode.rst;
    String selectedApiId = apiOptions.isNotEmpty
        ? apiOptions.first.id
        : runtime.apiConfig.apiId;
    String selectedPresetId = presetOptions.isNotEmpty
        ? presetOptions.first.id
        : runtime.presetConfig.presetId;
    String? selectedWorldBookId = worldBookOptions.isNotEmpty
        ? worldBookOptions.first.id
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('新建会话'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '会话名称'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<frb.SessionMode>(
                  initialValue: selectedMode,
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
                    setLocalState(() {
                      selectedMode = value;
                    });
                  },
                  decoration: const InputDecoration(labelText: '模式'),
                ),
                const SizedBox(height: 10),
                _OptionSelector(
                  label: 'API配置',
                  value: selectedApiId,
                  options: _toEntries(
                    apiOptions,
                    fallbackId: runtime.apiConfig.apiId,
                  ),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      selectedApiId = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _OptionSelector(
                  label: '预设',
                  value: selectedPresetId,
                  options: _toEntries(
                    presetOptions,
                    fallbackId: runtime.presetConfig.presetId,
                  ),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      selectedPresetId = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _OptionSelector(
                  label: '世界书（仅 ST）',
                  value: selectedWorldBookId,
                  options: _toEntries(worldBookOptions),
                  allowNull: true,
                  onChanged: (value) => setLocalState(() {
                    selectedWorldBookId = value;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final created = await sessionService.createSession(
      sessionName: name,
      mode: selectedMode == frb.SessionMode.rst
          ? SessionMode.rst
          : SessionMode.st,
      mainApiConfigId: selectedApiId,
      presetId: selectedPresetId,
      stWorldBookId: selectedMode == frb.SessionMode.st
          ? selectedWorldBookId
          : null,
    );
    ref.read(currentSessionIdProvider.notifier).state = created.sessionId;
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    _reload();
  }

  Future<void> _openEditDialog(BuildContext context, String sessionId) async {
    final sessionService = ref.read(sessionServiceProvider);
    final runtime = ref.read(apiServiceProvider).loadStartupRuntime();
    final loaded = await sessionService.loadSession(sessionId);
    if (!context.mounted) {
      return;
    }

    final apiOptions = ref.read(apiConfigOptionsProvider);
    final presetOptions = ref.read(presetOptionsProvider);
    final worldBookOptions = ref.read(worldBookOptionsProvider);

    final nameController = TextEditingController(
      text: loaded.config.sessionName,
    );
    frb.SessionMode selectedMode = loaded.config.mode;
    String selectedApiId = loaded.config.mainApiConfigId;
    String selectedPresetId = loaded.config.presetId;
    String? selectedWorldBookId = loaded.config.stWorldBookId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('编辑会话'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '会话名称'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<frb.SessionMode>(
                  initialValue: selectedMode,
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
                    setLocalState(() {
                      selectedMode = value;
                    });
                  },
                  decoration: const InputDecoration(labelText: '模式'),
                ),
                const SizedBox(height: 10),
                _OptionSelector(
                  label: 'API配置',
                  value: selectedApiId,
                  options: _toEntries(
                    apiOptions,
                    fallbackId: runtime.apiConfig.apiId,
                    fallbackLabel: runtime.apiConfig.name,
                  ),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      selectedApiId = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _OptionSelector(
                  label: '预设',
                  value: selectedPresetId,
                  options: _toEntries(
                    presetOptions,
                    fallbackId: runtime.presetConfig.presetId,
                    fallbackLabel: runtime.presetConfig.name,
                  ),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      selectedPresetId = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _OptionSelector(
                  label: '世界书（仅 ST）',
                  value: selectedWorldBookId,
                  options: _toEntries(worldBookOptions),
                  allowNull: true,
                  onChanged: (value) => setLocalState(() {
                    selectedWorldBookId = value;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final config = loaded.config;
    await sessionService.saveSession(
      frb.SessionConfig(
        sessionId: config.sessionId,
        sessionName: name,
        mode: selectedMode,
        mainApiConfigId: selectedApiId,
        presetId: selectedPresetId,
        stWorldBookId: selectedMode == frb.SessionMode.st
            ? selectedWorldBookId
            : null,
        createdAt: config.createdAt,
        updatedAt: config.updatedAt,
      ),
    );
    _reload();
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
    _reload();
  }

  List<_OptionEntry> _toEntries(
    List<ManagedOption> options, {
    String? fallbackId,
    String? fallbackLabel,
  }) {
    final items = options
        .map((item) => _OptionEntry(id: item.id, label: item.name))
        .toList(growable: true);
    if (fallbackId != null && !items.any((item) => item.id == fallbackId)) {
      items.add(
        _OptionEntry(id: fallbackId, label: fallbackLabel ?? fallbackId),
      );
    }
    return items;
  }

  String _formatTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
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
