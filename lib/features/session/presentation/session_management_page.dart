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
import 'session_settings_editor_page.dart';

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
    final startupRuntime = ref.read(apiServiceProvider).loadStartupRuntime();
    final apiOptions = await ref.read(apiConfigCatalogProvider.future);
    final presetOptions = await ref.read(presetCatalogProvider.future);
    if (!context.mounted) {
      return;
    }
    final worldBookOptions = ref.read(worldBookOptionsProvider);
    final appearanceOptions = ref.read(appearanceOptionsProvider);
    final sessionService = ref.read(sessionServiceProvider);

    final initialDraft = SessionSettingsDraft(
      sessionName: '新会话',
      userDescription: startupRuntime.defaultUserDescription,
      worldDescription: startupRuntime.defaultScene,
      characterDescription: startupRuntime.defaultLores,
      schedulerMode: SchedulerMode.rst,
      apiConfigId: apiOptions.isNotEmpty
          ? apiOptions.first.apiId
          : startupRuntime.apiConfig.apiId,
      presetId: presetOptions.isNotEmpty
          ? presetOptions.first.presetId
          : startupRuntime.presetConfig.presetId,
      worldBookId: worldBookOptions.isNotEmpty
          ? worldBookOptions.first.id
          : null,
      appearanceId: appearanceOptions.isNotEmpty
          ? appearanceOptions.first.id
          : 'appearance-default',
      backgroundImagePath: '',
    );

    final saved = await _openSessionEditor(
      context,
      title: '新建会话',
      actionLabel: '创建',
      initialDraft: initialDraft,
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
      appearanceOptions: _toEntries(
        appearanceOptions,
        selector: (item) => item.id,
        labelSelector: (item) => item.name,
      ),
    );
    if (saved == null) {
      return;
    }

    final mode = _modeFromScheduler(saved.schedulerMode);
    final created = await sessionService.createSession(
      sessionName: saved.sessionName,
      mode: mode == frb.SessionMode.rst ? SessionMode.rst : SessionMode.st,
      mainApiConfigId: saved.apiConfigId,
      presetId: saved.presetId,
      stWorldBookId: mode == frb.SessionMode.st ? saved.worldBookId : null,
    );
    _applySessionScopedSettings(sessionId: created.sessionId, draft: saved);
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
    final startupRuntime = ref.read(apiServiceProvider).loadStartupRuntime();
    final apiOptions = await ref.read(apiConfigCatalogProvider.future);
    final presetOptions = await ref.read(presetCatalogProvider.future);
    if (!context.mounted) {
      return;
    }
    final worldBookOptions = ref.read(worldBookOptionsProvider);
    final appearanceOptions = ref.read(appearanceOptionsProvider);

    final config = loaded.config;
    final schedulerMap = ref.read(sessionSchedulerModeProvider);
    final appearanceMap = ref.read(sessionAppearanceProvider);
    final backgroundMap = ref.read(sessionBackgroundImageProvider);
    final rstDataMap = ref.read(sessionRstDataProvider);
    final appearanceFallback = appearanceOptions.isNotEmpty
        ? appearanceOptions.first.id
        : 'appearance-default';
    final rstData = rstDataMap[config.sessionId];

    final initialDraft = SessionSettingsDraft(
      sessionName: config.sessionName,
      userDescription:
          rstData?.userDescription ?? startupRuntime.defaultUserDescription,
      worldDescription: rstData?.scene ?? startupRuntime.defaultScene,
      characterDescription: rstData?.lores ?? startupRuntime.defaultLores,
      schedulerMode: schedulerMap[config.sessionId] ?? _deriveScheduler(config),
      apiConfigId: config.mainApiConfigId,
      presetId: config.presetId,
      worldBookId: config.stWorldBookId,
      appearanceId: appearanceMap[config.sessionId] ?? appearanceFallback,
      backgroundImagePath: backgroundMap[config.sessionId] ?? '',
    );

    final saved = await _openSessionEditor(
      context,
      title: '编辑会话',
      actionLabel: '保存',
      initialDraft: initialDraft,
      apiOptions: _toEntries(
        apiOptions,
        selector: (item) => item.apiId,
        labelSelector: (item) => item.name,
        fallbackId: config.mainApiConfigId,
      ),
      presetOptions: _toEntries(
        presetOptions,
        selector: (item) => item.presetId,
        labelSelector: (item) => item.name,
        fallbackId: config.presetId,
      ),
      worldBookOptions: _toEntries(
        worldBookOptions,
        selector: (item) => item.id,
        labelSelector: (item) => item.name,
        fallbackId: config.stWorldBookId,
      ),
      appearanceOptions: _toEntries(
        appearanceOptions,
        selector: (item) => item.id,
        labelSelector: (item) => item.name,
        fallbackId: initialDraft.appearanceId,
      ),
    );
    if (saved == null) {
      return;
    }

    final mode = _modeFromScheduler(saved.schedulerMode);
    await sessionService.saveSession(
      frb.SessionConfig(
        sessionId: config.sessionId,
        sessionName: saved.sessionName,
        mode: mode,
        mainApiConfigId: saved.apiConfigId,
        presetId: saved.presetId,
        stWorldBookId: mode == frb.SessionMode.st ? saved.worldBookId : null,
        createdAt: config.createdAt,
        updatedAt: config.updatedAt,
      ),
    );
    _applySessionScopedSettings(sessionId: config.sessionId, draft: saved);
    ref.read(workspaceReloadTickProvider.notifier).state++;
    _reload();
  }

  Future<SessionSettingsDraft?> _openSessionEditor(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required SessionSettingsDraft initialDraft,
    required List<SessionSettingsOptionEntry> apiOptions,
    required List<SessionSettingsOptionEntry> presetOptions,
    required List<SessionSettingsOptionEntry> worldBookOptions,
    required List<SessionSettingsOptionEntry> appearanceOptions,
  }) async {
    final saved = await Navigator.of(context).push<SessionSettingsDraft>(
      MaterialPageRoute<SessionSettingsDraft>(
        fullscreenDialog: true,
        builder: (context) => SessionSettingsEditorPage(
          title: title,
          actionLabel: actionLabel,
          initialDraft: initialDraft,
          apiOptions: apiOptions,
          presetOptions: presetOptions,
          worldBookOptions: worldBookOptions,
          appearanceOptions: appearanceOptions,
        ),
      ),
    );
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    return saved;
  }

  void _applySessionScopedSettings({
    required String sessionId,
    required SessionSettingsDraft draft,
  }) {
    ref
        .read(sessionSchedulerModeProvider.notifier)
        .state = <String, SchedulerMode>{
      ...ref.read(sessionSchedulerModeProvider),
      sessionId: draft.schedulerMode,
    };
    ref.read(sessionAppearanceProvider.notifier).state = <String, String>{
      ...ref.read(sessionAppearanceProvider),
      sessionId: draft.appearanceId,
    };

    final background = draft.backgroundImagePath.trim();
    final backgroundMap = <String, String>{
      ...ref.read(sessionBackgroundImageProvider),
    };
    if (background.isEmpty) {
      backgroundMap.remove(sessionId);
    } else {
      backgroundMap[sessionId] = background;
    }
    ref.read(sessionBackgroundImageProvider.notifier).state = backgroundMap;

    ref.read(sessionRstDataProvider.notifier).state = <String, SessionRstData>{
      ...ref.read(sessionRstDataProvider),
      sessionId: SessionRstData(
        userDescription: draft.userDescription.trim(),
        scene: draft.worldDescription.trim(),
        lores: draft.characterDescription.trim(),
      ),
    };
  }

  SchedulerMode _deriveScheduler(frb.SessionConfig config) {
    if (config.mode == frb.SessionMode.rst) {
      return SchedulerMode.rst;
    }
    return SchedulerMode.direct;
  }

  frb.SessionMode _modeFromScheduler(SchedulerMode schedulerMode) {
    if (schedulerMode == SchedulerMode.rst) {
      return frb.SessionMode.rst;
    }
    return frb.SessionMode.st;
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

  List<SessionSettingsOptionEntry> _toEntries<T>(
    List<T> options, {
    required String Function(T item) selector,
    required String Function(T item) labelSelector,
    String? fallbackId,
    String? fallbackLabel,
  }) {
    final items = options
        .map(
          (item) => SessionSettingsOptionEntry(
            id: selector(item),
            label: labelSelector(item),
          ),
        )
        .toList(growable: true);
    if (fallbackId == null || fallbackId.isEmpty) {
      return items;
    }
    if (items.any((item) => item.id == fallbackId)) {
      return items;
    }
    items.insert(
      0,
      SessionSettingsOptionEntry(
        id: fallbackId,
        label: fallbackLabel ?? '$fallbackId (未在列表)',
      ),
    );
    return items;
  }
}
