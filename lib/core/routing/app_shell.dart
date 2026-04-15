import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge/frb_api.dart' as frb;
import '../../features/chat/presentation/chat_page.dart';
import '../../features/log/presentation/log_page.dart';
import '../../features/session/presentation/session_management_page.dart';
import '../../features/session/presentation/session_settings_editor_page.dart';
import '../../features/settings/presentation/api_config_management_page.dart';
import '../../features/settings/presentation/preset_management_page.dart';
import '../../features/settings/presentation/resource_management_page.dart';
import '../../features/settings/presentation/world_book_management_page.dart';
import '../models/workspace_config.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/glass_panel_card.dart';
import '../providers/app_state.dart';
import '../providers/config_catalog_providers.dart';
import '../providers/service_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  static final _items = <_DrawerNavItem>[
    _DrawerNavItem(
      tab: AppTab.chat,
      label: '聊天',
      icon: Icons.forum_outlined,
      page: const ChatPage(),
    ),
    _DrawerNavItem(
      tab: AppTab.sessionManagement,
      label: '会话管理',
      icon: Icons.chat_bubble_outline_rounded,
      page: const SessionManagementPage(),
    ),
    _DrawerNavItem(
      tab: AppTab.worldBook,
      label: '世界书',
      icon: Icons.menu_book_outlined,
      page: const WorldBookManagementPage(),
    ),
    _DrawerNavItem(
      tab: AppTab.preset,
      label: '预设',
      icon: Icons.auto_awesome_motion_outlined,
      page: const PresetManagementPage(),
    ),
    _DrawerNavItem(
      tab: AppTab.apiConfig,
      label: 'API配置',
      icon: Icons.cloud_sync_outlined,
      page: const ApiConfigManagementPage(),
    ),
    _DrawerNavItem(
      tab: AppTab.appearance,
      label: '外观',
      icon: Icons.palette_outlined,
      page: ResourceManagementPage(
        title: '外观',
        emptyTitle: '暂无外观方案',
        emptyDescription: '创建后可绑定到当前会话。',
        optionType: ManagedOptionType.appearance,
        optionsProvider: appearanceOptionsProvider,
      ),
    ),
    _DrawerNavItem(
      tab: AppTab.log,
      label: '日志',
      icon: Icons.receipt_long_outlined,
      page: const LogPage(),
    ),
  ];

  static final _tabToIndex = <AppTab, int>{
    for (var i = 0; i < _items.length; i++) _items[i].tab: i,
  };

  static final _currentSessionNameProvider = FutureProvider<String>((
    ref,
  ) async {
    ref.watch(workspaceReloadTickProvider);
    final sessionService = ref.watch(sessionServiceProvider);
    final sessions = await sessionService.listSessions();
    if (sessions.isEmpty) {
      return '暂无会话';
    }

    final currentSessionId = ref.watch(currentSessionIdProvider);
    if (currentSessionId == null || currentSessionId.isEmpty) {
      return sessions.first.sessionName;
    }

    for (final session in sessions) {
      if (session.sessionId == currentSessionId) {
        return session.sessionName;
      }
    }
    return sessions.first.sessionName;
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Android 系统返回层级（由高到低）：
  /// 1. 子页面路由（Navigator.push 打开的详细设置页）先返回上一页；
  ///    这一层由 Navigator 在本回调前处理。
  /// 2. 若抽屉已打开，优先关闭抽屉。
  /// 3. 若当前不在聊天页，切回聊天页。
  /// 4. 聊天页再次返回，交给系统退出到桌面。
  void _handleRootBack(AppTab currentTab) {
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
      return;
    }
    if (currentTab != AppTab.chat) {
      ref.read(appTabProvider.notifier).state = AppTab.chat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(appTabProvider);
    final currentIndex = AppShell._tabToIndex[currentTab] ?? 0;
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final sessionBackgroundMap = ref.watch(sessionBackgroundImageProvider);
    final backgroundImagePath =
        currentTab == AppTab.chat && currentSessionId != null
        ? sessionBackgroundMap[currentSessionId]
        : null;

    return PopScope<void>(
      canPop: currentTab == AppTab.chat,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleRootBack(currentTab);
      },
      child: AppScaffold(
        scaffoldKey: _scaffoldKey,
        backgroundImagePath: backgroundImagePath,
        headerCenter: const _CurrentSessionHeaderTitle(),
        headerTrailing: const _SessionQuickSettingsTrigger(),
        drawer: Drawer(
          backgroundColor: AppColors.backgroundElevated,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassPanelCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RST',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: AppShell._items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = AppShell._items[index];
                        return _DrawerExpandableSection(
                          label: item.label,
                          icon: item.icon,
                          selected: index == currentIndex,
                          onTap: () {
                            Navigator.of(context).pop();
                            ref.read(appTabProvider.notifier).state = item.tab;
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(AppShell._items[currentIndex].tab),
          child: AppShell._items[currentIndex].page,
        ),
      ),
    );
  }
}

class _CurrentSessionHeaderTitle extends ConsumerWidget {
  const _CurrentSessionHeaderTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(appTabProvider);
    final status = currentTab == AppTab.chat
        ? ref.watch(chatTopStatusProvider)
        : ChatTopStatus.calm;
    final sessionNameAsync = ref.watch(AppShell._currentSessionNameProvider);
    final sessionName = sessionNameAsync.when(
      data: (value) => value,
      loading: () => '会话加载中',
      error: (error, stackTrace) => '会话加载失败',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sessionName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _TopStatusIndicator(status: status),
        ],
      ),
    );
  }
}

class _TopStatusIndicator extends StatelessWidget {
  const _TopStatusIndicator({required this.status});

  final ChatTopStatus status;

  @override
  Widget build(BuildContext context) {
    final (tooltip, borderColor, backgroundColor) = switch (status) {
      ChatTopStatus.calm => ('平静', AppColors.success, AppColors.surfaceOverlay),
      ChatTopStatus.waiting => (
        '等待响应',
        AppColors.accentSecondary,
        AppColors.surfaceOverlay,
      ),
      ChatTopStatus.error => (
        '程序异常',
        AppColors.error,
        AppColors.surfaceOverlay,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (status) {
            ChatTopStatus.calm => const Icon(
              Icons.check_rounded,
              key: ValueKey<String>('top-calm'),
              size: 14,
              color: AppColors.success,
            ),
            ChatTopStatus.waiting => const SizedBox(
              key: ValueKey<String>('top-waiting'),
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentSecondary,
              ),
            ),
            ChatTopStatus.error => const Icon(
              Icons.error_outline_rounded,
              key: ValueKey<String>('top-error'),
              size: 14,
              color: AppColors.error,
            ),
          },
        ),
      ),
    );
  }
}

Future<void> _showSessionQuickSettingsBottomSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.backgroundElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const FractionallySizedBox(
      heightFactor: 1,
      child: _SessionQuickSettingsSheet(),
    ),
  );
}

class _DrawerExpandableSection extends StatefulWidget {
  const _DrawerExpandableSection({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DrawerExpandableSection> createState() =>
      _DrawerExpandableSectionState();
}

class _DrawerExpandableSectionState extends State<_DrawerExpandableSection> {
  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selected
        ? AppColors.borderStrong
        : AppColors.borderSubtle;
    final background = widget.selected
        ? AppColors.surfaceOverlay.withValues(alpha: 0.72)
        : AppColors.surfaceCard.withValues(alpha: 0.84);
    final iconColor = widget.selected
        ? AppColors.accentPrimary
        : AppColors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                      color: AppColors.surfaceOverlay,
                    ),
                    child: Icon(widget.icon, size: 19, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionQuickSettingsTrigger extends ConsumerWidget {
  const _SessionQuickSettingsTrigger();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: '当前会话设置',
      onPressed: () => _showSessionQuickSettingsBottomSheet(context),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceOverlay,
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332F7CFF),
              blurRadius: 18,
              spreadRadius: 1,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.chat_bubble_rounded, size: 18),
      ),
    );
  }
}

class _SessionQuickSettingsSheet extends ConsumerStatefulWidget {
  const _SessionQuickSettingsSheet();

  @override
  ConsumerState<_SessionQuickSettingsSheet> createState() =>
      _SessionQuickSettingsSheetState();
}

class _SessionQuickSettingsSheetState
    extends ConsumerState<_SessionQuickSettingsSheet> {
  bool _loading = true;
  String? _error;
  frb.SessionConfig? _config;
  SessionSettingsDraft? _draft;
  int _editorVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentSession();
  }

  Future<void> _loadCurrentSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessionService = ref.read(sessionServiceProvider);
      final sessions = await sessionService.listSessions();
      if (sessions.isEmpty) {
        setState(() {
          _config = null;
          _draft = null;
          _editorVersion++;
          _loading = false;
        });
        return;
      }

      var currentSessionId = ref.read(currentSessionIdProvider);
      final exists = sessions.any((item) => item.sessionId == currentSessionId);
      if (!exists || currentSessionId == null) {
        currentSessionId = sessions.first.sessionId;
        ref.read(currentSessionIdProvider.notifier).state = currentSessionId;
      }

      final loaded = await sessionService.loadSession(currentSessionId);
      final config = loaded.config;
      final schedulerMap = ref.read(sessionSchedulerModeProvider);
      final appearanceMap = ref.read(sessionAppearanceProvider);
      final backgroundMap = ref.read(sessionBackgroundImageProvider);
      final rstDataMap = ref.read(sessionRstDataProvider);
      final appearanceOptions = ref.read(appearanceOptionsProvider);
      final defaultAppearanceId = appearanceOptions.isNotEmpty
          ? appearanceOptions.first.id
          : 'appearance-default';
      final startupRuntime = ref.read(apiServiceProvider).loadStartupRuntime();
      final rstData = rstDataMap[config.sessionId];

      setState(() {
        _config = config;
        _draft = SessionSettingsDraft(
          sessionName: config.sessionName,
          userDescription:
              rstData?.userDescription ?? startupRuntime.defaultUserDescription,
          worldDescription: rstData?.scene ?? startupRuntime.defaultScene,
          characterDescription: rstData?.lores ?? startupRuntime.defaultLores,
          schedulerMode:
              schedulerMap[config.sessionId] ?? _deriveScheduler(config),
          apiConfigId: config.mainApiConfigId,
          presetId: config.presetId,
          worldBookId: config.stWorldBookId,
          appearanceId: appearanceMap[config.sessionId] ?? defaultAppearanceId,
          backgroundImagePath: backgroundMap[config.sessionId] ?? '',
        );
        _editorVersion++;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  SchedulerMode _deriveScheduler(frb.SessionConfig config) {
    if (config.mode == frb.SessionMode.rst) {
      return SchedulerMode.rst;
    }
    return SchedulerMode.direct;
  }

  frb.SessionMode _modeFromScheduler(SchedulerMode mode) {
    if (mode == SchedulerMode.rst) {
      return frb.SessionMode.rst;
    }
    return frb.SessionMode.st;
  }

  Future<void> _save(SessionSettingsDraft draft) async {
    final config = _config;
    if (config == null) {
      return;
    }
    final mode = _modeFromScheduler(draft.schedulerMode);
    final saved = await ref
        .read(sessionServiceProvider)
        .saveSession(
          frb.SessionConfig(
            sessionId: config.sessionId,
            sessionName: draft.sessionName,
            mode: mode,
            mainApiConfigId: draft.apiConfigId,
            presetId: draft.presetId,
            stWorldBookId: mode == frb.SessionMode.st
                ? draft.worldBookId
                : null,
            createdAt: config.createdAt,
            updatedAt: config.updatedAt,
          ),
        );

    ref
        .read(sessionSchedulerModeProvider.notifier)
        .state = <String, SchedulerMode>{
      ...ref.read(sessionSchedulerModeProvider),
      saved.sessionId: draft.schedulerMode,
    };
    ref.read(sessionAppearanceProvider.notifier).state = <String, String>{
      ...ref.read(sessionAppearanceProvider),
      saved.sessionId: draft.appearanceId,
    };

    final normalizedBackgroundPath = draft.backgroundImagePath.trim();
    final backgroundState = <String, String>{
      ...ref.read(sessionBackgroundImageProvider),
    };
    if (normalizedBackgroundPath.isEmpty) {
      backgroundState.remove(saved.sessionId);
    } else {
      backgroundState[saved.sessionId] = normalizedBackgroundPath;
    }
    ref.read(sessionBackgroundImageProvider.notifier).state = backgroundState;

    ref.read(sessionRstDataProvider.notifier).state = <String, SessionRstData>{
      ...ref.read(sessionRstDataProvider),
      saved.sessionId: SessionRstData(
        userDescription: draft.userDescription.trim(),
        scene: draft.worldDescription.trim(),
        lores: draft.characterDescription.trim(),
      ),
    };
    ref.read(workspaceReloadTickProvider.notifier).state++;

    if (!mounted) {
      return;
    }
    setState(() {
      _config = saved;
      _draft = draft;
    });
  }

  void _attemptCloseToChat() {
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final apiOptions = ref.watch(apiConfigCatalogProvider);
    final presetOptions = ref.watch(presetCatalogProvider);
    final worldBookOptions = ref.watch(worldBookOptionsProvider);
    final appearanceOptions = ref.watch(appearanceOptionsProvider);
    late final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_config == null || _draft == null) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '返回聊天',
                  onPressed: () => _attemptCloseToChat(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Text('当前会话设置', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            const GlassPanelCard(child: Text('暂无可设置会话，请先到“会话管理”创建会话。')),
          ],
        ),
      );
    } else {
      final config = _config!;
      final draft = _draft!;
      final apiEntries = _ensureStoredOption<StoredApiConfig>(
        selectedId: draft.apiConfigId,
        source: apiOptions.valueOrNull ?? const <StoredApiConfig>[],
        idSelector: (item) => item.apiId,
        nameSelector: (item) => item.name,
      );
      final presetEntries = _ensureStoredOption<StoredPresetConfig>(
        selectedId: draft.presetId,
        source: presetOptions.valueOrNull ?? const <StoredPresetConfig>[],
        idSelector: (item) => item.presetId,
        nameSelector: (item) => item.name,
      );
      final worldEntries = _ensureManagedOption(
        draft.worldBookId,
        worldBookOptions,
      );
      final appearanceEntries = _ensureManagedOption(
        draft.appearanceId,
        appearanceOptions,
      );

      body = SessionSettingsEditorPage(
        key: ValueKey<String>('${config.sessionId}-$_editorVersion'),
        title: '当前会话设置',
        actionLabel: '保存设置',
        initialDraft: draft,
        apiOptions: apiEntries,
        presetOptions: presetEntries,
        worldBookOptions: worldEntries,
        appearanceOptions: appearanceEntries,
        popAfterSubmit: false,
        enableDetailJump: true,
        onSubmit: _save,
      );
    }

    return body;
  }

  List<SessionSettingsOptionEntry> _ensureStoredOption<T>({
    required String? selectedId,
    required List<T> source,
    required String Function(T item) idSelector,
    required String Function(T item) nameSelector,
  }) {
    if (selectedId == null || selectedId.isEmpty) {
      return source
          .map(
            (item) => SessionSettingsOptionEntry(
              id: idSelector(item),
              label: nameSelector(item),
            ),
          )
          .toList(growable: false);
    }
    final entries = source
        .map(
          (item) => SessionSettingsOptionEntry(
            id: idSelector(item),
            label: nameSelector(item),
          ),
        )
        .toList(growable: true);
    if (entries.any((item) => item.id == selectedId)) {
      return entries;
    }
    return <SessionSettingsOptionEntry>[
      SessionSettingsOptionEntry(id: selectedId, label: '$selectedId (未在列表)'),
      ...entries,
    ];
  }

  List<SessionSettingsOptionEntry> _ensureManagedOption(
    String? selectedId,
    List<ManagedOption> source,
  ) {
    final entries = source
        .map(
          (item) => SessionSettingsOptionEntry(id: item.id, label: item.name),
        )
        .toList(growable: true);
    if (selectedId == null || selectedId.isEmpty) {
      return entries;
    }
    if (entries.any((item) => item.id == selectedId)) {
      return entries;
    }
    return <SessionSettingsOptionEntry>[
      SessionSettingsOptionEntry(id: selectedId, label: '$selectedId (未在列表)'),
      ...entries,
    ];
  }
}

class _DrawerNavItem {
  const _DrawerNavItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.page,
  });

  final AppTab tab;
  final String label;
  final IconData icon;
  final Widget page;
}
