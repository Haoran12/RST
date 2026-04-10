import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge/frb_api.dart' as frb;
import '../../features/chat/presentation/chat_page.dart';
import '../../features/log/presentation/log_page.dart';
import '../../features/session/presentation/session_management_page.dart';
import '../../features/settings/presentation/resource_management_page.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/glass_panel_card.dart';
import '../providers/app_state.dart';
import '../providers/service_providers.dart';

class AppShell extends ConsumerWidget {
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
      page: ResourceManagementPage(
        title: '世界书',
        subtitle: '管理世界书对象，支持新建、编辑、删除。',
        emptyTitle: '暂无世界书',
        emptyDescription: '先创建世界书，再绑定到 ST 会话。',
        icon: Icons.menu_book_outlined,
        optionType: ManagedOptionType.worldBook,
        optionsProvider: worldBookOptionsProvider,
      ),
    ),
    _DrawerNavItem(
      tab: AppTab.preset,
      label: '预设',
      icon: Icons.auto_awesome_motion_outlined,
      page: ResourceManagementPage(
        title: '预设',
        subtitle: '管理提示词与生成参数预设，支持完整增删改查。',
        emptyTitle: '暂无预设',
        emptyDescription: '先创建预设，供会话与快速设置选择。',
        icon: Icons.auto_awesome_motion_outlined,
        optionType: ManagedOptionType.preset,
        optionsProvider: presetOptionsProvider,
      ),
    ),
    _DrawerNavItem(
      tab: AppTab.apiConfig,
      label: 'API配置',
      icon: Icons.cloud_sync_outlined,
      page: ResourceManagementPage(
        title: 'API配置',
        subtitle: '管理 API 提供商、模型与接口配置项。',
        emptyTitle: '暂无 API 配置',
        emptyDescription: '创建后可在会话设置中切换使用。',
        icon: Icons.cloud_sync_outlined,
        optionType: ManagedOptionType.apiConfig,
        optionsProvider: apiConfigOptionsProvider,
      ),
    ),
    _DrawerNavItem(
      tab: AppTab.appearance,
      label: '外观',
      icon: Icons.palette_outlined,
      page: ResourceManagementPage(
        title: '外观',
        subtitle: '管理主题与外观方案，支持新建、编辑、删除。',
        emptyTitle: '暂无外观方案',
        emptyDescription: '创建后可绑定到当前会话。',
        icon: Icons.palette_outlined,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(appTabProvider);
    final currentIndex = _tabToIndex[currentTab] ?? 0;

    return AppScaffold(
      headerTrailing: const _SessionQuickSettingsTrigger(),
      drawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassPanelCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    '导航',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Icon(item.icon),
                        title: Text(item.label),
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
        key: ValueKey(_items[currentIndex].tab),
        child: _items[currentIndex].page,
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
      onPressed: () async {
        await showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: AppColors.backgroundElevated,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) => const FractionallySizedBox(
            heightFactor: 0.88,
            child: _SessionQuickSettingsSheet(),
          ),
        );
      },
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
  bool _saving = false;
  String? _error;
  frb.SessionConfig? _config;
  SchedulerMode _schedulerMode = SchedulerMode.rst;
  String _apiConfigId = '';
  String _presetId = '';
  String? _worldBookId;
  String _appearanceId = '';

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
      final appearanceOptions = ref.read(appearanceOptionsProvider);
      final defaultAppearanceId = appearanceOptions.isNotEmpty
          ? appearanceOptions.first.id
          : 'appearance-default';

      setState(() {
        _config = config;
        _schedulerMode =
            schedulerMap[config.sessionId] ?? _deriveScheduler(config);
        _apiConfigId = config.mainApiConfigId;
        _presetId = config.presetId;
        _worldBookId = config.stWorldBookId;
        _appearanceId = appearanceMap[config.sessionId] ?? defaultAppearanceId;
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

  Future<void> _save() async {
    final config = _config;
    if (config == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final mode = _schedulerMode == SchedulerMode.rst
          ? frb.SessionMode.rst
          : frb.SessionMode.st;
      final saved = await ref
          .read(sessionServiceProvider)
          .saveSession(
            frb.SessionConfig(
              sessionId: config.sessionId,
              sessionName: config.sessionName,
              mode: mode,
              mainApiConfigId: _apiConfigId,
              presetId: _presetId,
              stWorldBookId: mode == frb.SessionMode.st ? _worldBookId : null,
              createdAt: config.createdAt,
              updatedAt: config.updatedAt,
            ),
          );

      final schedulerState = <String, SchedulerMode>{
        ...ref.read(sessionSchedulerModeProvider),
        saved.sessionId: _schedulerMode,
      };
      ref.read(sessionSchedulerModeProvider.notifier).state = schedulerState;

      final appearanceState = <String, String>{
        ...ref.read(sessionAppearanceProvider),
        saved.sessionId: _appearanceId,
      };
      ref.read(sessionAppearanceProvider.notifier).state = appearanceState;

      setState(() {
        _config = saved;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiOptions = ref.watch(apiConfigOptionsProvider);
    final presetOptions = ref.watch(presetOptionsProvider);
    final worldBookOptions = ref.watch(worldBookOptionsProvider);
    final appearanceOptions = ref.watch(appearanceOptionsProvider);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_config == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text('当前会话设置', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const GlassPanelCard(child: Text('暂无可设置会话，请先到“会话管理”创建会话。')),
          ],
        ),
      );
    }

    final config = _config!;
    final apiEntries = _ensureOption(
      config.mainApiConfigId,
      apiOptions,
      ManagedOptionType.apiConfig,
    );
    final presetEntries = _ensureOption(
      config.presetId,
      presetOptions,
      ManagedOptionType.preset,
    );
    final worldEntries = _ensureOption(
      config.stWorldBookId,
      worldBookOptions,
      ManagedOptionType.worldBook,
    );
    final appearanceEntries = _ensureOption(
      _appearanceId,
      appearanceOptions,
      ManagedOptionType.appearance,
    );

    final schedulerLabel = switch (_schedulerMode) {
      SchedulerMode.direct => '关键词识别：按规则快速命中',
      SchedulerMode.rst => 'RST LLM确认：由模型确认注入策略',
      SchedulerMode.agent => 'Agent多人物独立思维：分角色推理后汇总',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        Row(
          children: [
            Text('当前会话设置', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.sessionName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'session_id: ${config.sessionId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
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
              Text('调度器模式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              DropdownButtonFormField<SchedulerMode>(
                initialValue: _schedulerMode,
                items: const [
                  DropdownMenuItem(
                    value: SchedulerMode.direct,
                    child: Text('direct'),
                  ),
                  DropdownMenuItem(
                    value: SchedulerMode.rst,
                    child: Text('RST'),
                  ),
                  DropdownMenuItem(
                    value: SchedulerMode.agent,
                    child: Text('Agent'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _schedulerMode = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                schedulerLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
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
              Text('会话绑定项', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _OptionSelector(
                label: 'API配置',
                value: _apiConfigId,
                options: apiEntries,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _apiConfigId = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              _OptionSelector(
                label: '预设',
                value: _presetId,
                options: presetEntries,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _presetId = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              _OptionSelector(
                label: '世界书',
                value: _worldBookId,
                options: worldEntries,
                allowNull: true,
                onChanged: (value) {
                  setState(() {
                    _worldBookId = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              _OptionSelector(
                label: '外观',
                value: _appearanceId,
                options: appearanceEntries,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _appearanceId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PrimaryPillButton(
                    label: _saving ? '保存中...' : '保存设置',
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(width: 8),
                  SecondaryOutlineButton(
                    label: '刷新',
                    onPressed: _saving ? null : _loadCurrentSession,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<ManagedOption> _ensureOption(
    String? selectedId,
    List<ManagedOption> source,
    ManagedOptionType type,
  ) {
    if (selectedId == null || selectedId.isEmpty) {
      return source;
    }
    if (source.any((item) => item.id == selectedId)) {
      return source;
    }
    return <ManagedOption>[
      buildManagedOptionTemplate(
        type,
        id: selectedId,
        name: '$selectedId (未在列表)',
        description: '会话当前绑定值',
      ),
      ...source,
    ];
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
  final List<ManagedOption> options;
  final ValueChanged<String?> onChanged;
  final bool allowNull;

  @override
  Widget build(BuildContext context) {
    final optionIds = options.map((item) => item.id).toSet();
    final selected = value != null && optionIds.contains(value) ? value : null;

    final items = <DropdownMenuItem<String?>>[];
    if (allowNull) {
      items.add(
        const DropdownMenuItem<String?>(value: null, child: Text('不绑定')),
      );
    }
    items.addAll(
      options.map(
        (item) =>
            DropdownMenuItem<String?>(value: item.id, child: Text(item.name)),
      ),
    );

    return DropdownButtonFormField<String?>(
      initialValue: selected,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
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
