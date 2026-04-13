import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge/frb_api.dart' as frb;
import '../../features/chat/presentation/chat_page.dart';
import '../../features/log/presentation/log_page.dart';
import '../../features/session/presentation/session_management_page.dart';
import '../../features/settings/presentation/api_config_management_page.dart';
import '../../features/settings/presentation/preset_management_page.dart';
import '../../features/settings/presentation/resource_management_page.dart';
import '../models/workspace_config.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/glass_panel_card.dart';
import '../providers/app_state.dart';
import '../providers/config_catalog_providers.dart';
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
        emptyTitle: '暂无世界书',
        emptyDescription: '先创建世界书，再绑定到 ST 会话。',
        optionType: ManagedOptionType.worldBook,
        optionsProvider: worldBookOptionsProvider,
      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(appTabProvider);
    final currentIndex = _tabToIndex[currentTab] ?? 0;

    return AppScaffold(
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
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
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
        key: ValueKey(_items[currentIndex].tab),
        child: _items[currentIndex].page,
      ),
    );
  }
}

Future<void> _showSessionQuickSettingsBottomSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
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
  bool _saving = false;
  String? _error;
  frb.SessionConfig? _config;
  SchedulerMode _schedulerMode = SchedulerMode.rst;
  String _apiConfigId = '';
  String _presetId = '';
  String? _worldBookId;
  String _appearanceId = '';
  late final TextEditingController _rstUserDescriptionController;
  late final TextEditingController _rstSceneController;
  late final TextEditingController _rstLoresController;

  @override
  void initState() {
    super.initState();
    _rstUserDescriptionController = TextEditingController();
    _rstSceneController = TextEditingController();
    _rstLoresController = TextEditingController();
    _loadCurrentSession();
  }

  @override
  void dispose() {
    _rstUserDescriptionController.dispose();
    _rstSceneController.dispose();
    _rstLoresController.dispose();
    super.dispose();
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
      final rstDataMap = ref.read(sessionRstDataProvider);
      final appearanceOptions = ref.read(appearanceOptionsProvider);
      final defaultAppearanceId = appearanceOptions.isNotEmpty
          ? appearanceOptions.first.id
          : 'appearance-default';
      final startupRuntime = ref.read(apiServiceProvider).loadStartupRuntime();
      final rstData = rstDataMap[config.sessionId];

      _rstUserDescriptionController.text =
          rstData?.userDescription ?? startupRuntime.defaultUserDescription;
      _rstSceneController.text = rstData?.scene ?? startupRuntime.defaultScene;
      _rstLoresController.text = rstData?.lores ?? startupRuntime.defaultLores;

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

      final rstDataState = <String, SessionRstData>{
        ...ref.read(sessionRstDataProvider),
        saved.sessionId: SessionRstData(
          userDescription: _rstUserDescriptionController.text.trim(),
          scene: _rstSceneController.text.trim(),
          lores: _rstLoresController.text.trim(),
        ),
      };
      ref.read(sessionRstDataProvider.notifier).state = rstDataState;

      ref.read(workspaceReloadTickProvider.notifier).state++;

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
    final apiOptions = ref.watch(apiConfigCatalogProvider);
    final presetOptions = ref.watch(presetCatalogProvider);
    final worldBookOptions = ref.watch(worldBookOptionsProvider);
    final appearanceOptions = ref.watch(appearanceOptionsProvider);
    const listPadding = EdgeInsets.fromLTRB(16, 10, 16, 16);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_config == null) {
      return Padding(
        padding: listPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
    final apiEntries = _ensureStoredOption<StoredApiConfig>(
      selectedId: config.mainApiConfigId,
      source: apiOptions.valueOrNull ?? const <StoredApiConfig>[],
      idSelector: (item) => item.apiId,
      nameSelector: (item) => item.name,
    );
    final presetEntries = _ensureStoredOption<StoredPresetConfig>(
      selectedId: config.presetId,
      source: presetOptions.valueOrNull ?? const <StoredPresetConfig>[],
      idSelector: (item) => item.presetId,
      nameSelector: (item) => item.name,
    );
    final worldEntries = _ensureManagedOption(
      config.stWorldBookId,
      worldBookOptions,
    );
    final appearanceEntries = _ensureManagedOption(
      _appearanceId,
      appearanceOptions,
    );

    final schedulerLabel = switch (_schedulerMode) {
      SchedulerMode.direct => '关键词识别：按规则快速命中',
      SchedulerMode.rst => 'RST LLM确认：由模型确认注入策略',
      SchedulerMode.agent => 'Agent多人物独立思维：分角色推理后汇总',
    };

    return ListView(
      padding: listPadding,
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
              Text(
                '本会话 RST Data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rstUserDescriptionController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'user_description',
                  helperText: '用于描述用户身份、关系和发言风格。',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rstSceneController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'scene',
                  helperText: '用于描述当前场景、时间线与环境状态。',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rstLoresController,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'lores',
                  helperText: '用于填写本会话的 Lore 注入文本。',
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
              if (apiOptions.hasError || presetOptions.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${apiOptions.error ?? presetOptions.error}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              _OptionSelector(
                label: 'API配置',
                value: _apiConfigId,
                options: apiEntries,
                enabled: !apiOptions.isLoading,
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
                enabled: !presetOptions.isLoading,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrimaryPillButton(
                    label: _saving ? '保存中...' : '保存设置',
                    onPressed: _saving ? null : _save,
                  ),
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

  List<_SelectorEntry> _ensureStoredOption<T>({
    required String? selectedId,
    required List<T> source,
    required String Function(T item) idSelector,
    required String Function(T item) nameSelector,
  }) {
    if (selectedId == null || selectedId.isEmpty) {
      return source
          .map(
            (item) =>
                _SelectorEntry(id: idSelector(item), name: nameSelector(item)),
          )
          .toList(growable: false);
    }
    final entries = source
        .map(
          (item) =>
              _SelectorEntry(id: idSelector(item), name: nameSelector(item)),
        )
        .toList(growable: true);
    if (entries.any((item) => item.id == selectedId)) {
      return entries;
    }
    return <_SelectorEntry>[
      _SelectorEntry(id: selectedId, name: '$selectedId (未在列表)'),
      ...entries,
    ];
  }

  List<_SelectorEntry> _ensureManagedOption(
    String? selectedId,
    List<ManagedOption> source,
  ) {
    final entries = source
        .map((item) => _SelectorEntry(id: item.id, name: item.name))
        .toList(growable: true);
    if (selectedId == null || selectedId.isEmpty) {
      return entries;
    }
    if (entries.any((item) => item.id == selectedId)) {
      return entries;
    }
    return <_SelectorEntry>[
      _SelectorEntry(id: selectedId, name: '$selectedId (未在列表)'),
      ...entries,
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
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<_SelectorEntry> options;
  final ValueChanged<String?> onChanged;
  final bool allowNull;
  final bool enabled;

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
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SelectorEntry {
  const _SelectorEntry({required this.id, required this.name});

  final String id;
  final String name;
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
