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
      subtitle: '对话区域与会话上下文',
      icon: Icons.forum_outlined,
      page: const ChatPage(),
    ),
    _DrawerNavItem(
      tab: AppTab.sessionManagement,
      label: '会话管理',
      subtitle: '模式、绑定、上下文相关配置',
      icon: Icons.chat_bubble_outline_rounded,
      page: const SessionManagementPage(),
    ),
    _DrawerNavItem(
      tab: AppTab.worldBook,
      label: '世界书',
      subtitle: '管理 lore 文件与绑定项',
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
      subtitle: '主提示词与参数方案',
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
      subtitle: '提供商、模型与访问配置',
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
      subtitle: '主题与显示方案',
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
      subtitle: '查看请求与调度记录',
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
    Widget buildDetails(_DrawerNavItem item) {
      switch (item.tab) {
        case AppTab.chat:
          return _DrawerChatDetails(
            onOpenPage: () {
              Navigator.of(context).pop();
              ref.read(appTabProvider.notifier).state = item.tab;
            },
          );
        case AppTab.sessionManagement:
          return _DrawerSessionDetails(
            onOpenPage: () {
              Navigator.of(context).pop();
              ref.read(appTabProvider.notifier).state = item.tab;
            },
            onOpenFullscreen: () =>
                _showSessionQuickSettingsBottomSheet(context),
          );
        case AppTab.worldBook:
          return _DrawerResourceDetails(
            title: '世界书',
            emptyHint: '先创建世界书，再在 ST 会话里绑定。',
            type: ManagedOptionType.worldBook,
            optionsProvider: worldBookOptionsProvider,
            onOpenPage: () {
              Navigator.of(context).pop();
              ref.read(appTabProvider.notifier).state = item.tab;
            },
          );
        case AppTab.preset:
          return _DrawerResourceDetails(
            title: '预设',
            emptyHint: '先创建预设，用于会话生成策略。',
            type: ManagedOptionType.preset,
            optionsProvider: presetOptionsProvider,
            onOpenPage: () {
              Navigator.of(context).pop();
              ref.read(appTabProvider.notifier).state = item.tab;
            },
          );
        case AppTab.apiConfig:
          return _DrawerResourceDetails(
            title: 'API配置',
            emptyHint: '至少创建一个 API 配置后再绑定。',
            type: ManagedOptionType.apiConfig,
            optionsProvider: apiConfigOptionsProvider,
            onOpenPage: () {
              Navigator.of(context).pop();
              ref.read(appTabProvider.notifier).state = item.tab;
            },
          );
        case AppTab.appearance:
          return _DrawerResourceDetails(
            title: '外观',
            emptyHint: '创建一套外观后可绑定到当前会话。',
            type: ManagedOptionType.appearance,
            optionsProvider: appearanceOptionsProvider,
            onOpenPage: () {
              Navigator.of(context).pop();
              ref.read(appTabProvider.notifier).state = item.tab;
            },
          );
        case AppTab.log:
          return _DrawerLogDetails(
            onOpenPage: () {
              Navigator.of(context).pop();
              ref.read(appTabProvider.notifier).state = item.tab;
            },
          );
      }
    }

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
                        'Tavo 风格设置',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '点击分组可展开详细配置',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
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
                        subtitle: item.subtitle,
                        icon: item.icon,
                        selected: index == currentIndex,
                        onOpenPage: () {
                          Navigator.of(context).pop();
                          ref.read(appTabProvider.notifier).state = item.tab;
                        },
                        child: buildDetails(item),
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
      heightFactor: 0.88,
      child: _SessionQuickSettingsSheet(),
    ),
  );
}

class _DrawerExpandableSection extends StatefulWidget {
  const _DrawerExpandableSection({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onOpenPage,
    required this.child,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onOpenPage;
  final Widget child;

  @override
  State<_DrawerExpandableSection> createState() =>
      _DrawerExpandableSectionState();
}

class _DrawerExpandableSectionState extends State<_DrawerExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.selected;
  }

  @override
  void didUpdateWidget(covariant _DrawerExpandableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected && !_expanded) {
      _expanded = true;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

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
            onTap: _toggleExpanded,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '进入页面',
                    onPressed: widget.onOpenPage,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerChatDetails extends StatelessWidget {
  const _DrawerChatDetails({required this.onOpenPage});

  final VoidCallback onOpenPage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
            color: AppColors.backgroundBase.withValues(alpha: 0.25),
          ),
          child: const Text(
            '进入聊天界面并使用当前会话绑定的 API、Preset、世界书与外观方案。',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        PrimaryPillButton(label: '打开聊天', onPressed: onOpenPage),
      ],
    );
  }
}

class _DrawerSessionDetails extends StatelessWidget {
  const _DrawerSessionDetails({
    required this.onOpenPage,
    required this.onOpenFullscreen,
  });

  final VoidCallback onOpenPage;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
            color: AppColors.backgroundBase.withValues(alpha: 0.45),
          ),
          child: const SizedBox(
            height: 420,
            child: _SessionQuickSettingsSheet(embedded: true),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PrimaryPillButton(label: '进入会话页', onPressed: onOpenPage),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SecondaryOutlineButton(
                label: '全屏设置',
                onPressed: onOpenFullscreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DrawerResourceDetails extends ConsumerWidget {
  const _DrawerResourceDetails({
    required this.title,
    required this.emptyHint,
    required this.type,
    required this.optionsProvider,
    required this.onOpenPage,
  });

  final String title;
  final String emptyHint;
  final ManagedOptionType type;
  final StateProvider<List<ManagedOption>> optionsProvider;
  final VoidCallback onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(optionsProvider);
    final preview = options.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '$title配置 (${options.length})',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            if (options.length > preview.length)
              Text(
                '还有 ${options.length - preview.length} 项',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (preview.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
              color: AppColors.backgroundBase.withValues(alpha: 0.25),
            ),
            child: Text(
              emptyHint,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          )
        else
          ...preview.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DrawerOptionItem(
                item: item,
                onEdit: () => _openEditDialog(context, ref, source: item),
                onDelete: () => _deleteItem(context, ref, item),
              ),
            ),
          ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: PrimaryPillButton(label: '进入页面', onPressed: onOpenPage),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SecondaryOutlineButton(
                label: '新建',
                onPressed: () => _openEditDialog(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref, {
    ManagedOption? source,
  }) async {
    final nameController = TextEditingController(text: source?.name ?? '');
    final descController = TextEditingController(
      text: source?.description ?? '',
    );
    final isEdit = source != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑$title' : '新建$title'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '描述'),
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
    );

    if (saved != true) {
      return;
    }

    final name = nameController.text.trim();
    final description = descController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final notifier = ref.read(optionsProvider.notifier);
    final current = notifier.state;
    if (isEdit) {
      notifier.state = current
          .map(
            (item) => item.id == source.id
                ? item.copyWith(
                    name: name,
                    description: description.isEmpty ? '无描述' : description,
                    updatedAt: DateTime.now(),
                  )
                : item,
          )
          .toList(growable: false);
      return;
    }

    final idBase = _slugify(name);
    final idSuffix = DateTime.now().millisecondsSinceEpoch.toString();
    final next = buildManagedOptionTemplate(
      type,
      id: '$idBase-$idSuffix',
      name: name,
      description: description.isEmpty ? '无描述' : description,
    );
    notifier.state = <ManagedOption>[next, ...current];
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    ManagedOption item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除$title'),
        content: Text('确定删除“${item.name}”？此操作不可撤销。'),
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
        .where((element) => element.id != item.id)
        .toList(growable: false);
  }

  String _slugify(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '-');
    return normalized.replaceAll(RegExp(r'[^a-z0-9\-_]'), '');
  }
}

class _DrawerOptionItem extends StatelessWidget {
  const _DrawerOptionItem({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ManagedOption item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        color: AppColors.backgroundBase.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 17),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 17,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerLogDetails extends StatelessWidget {
  const _DrawerLogDetails({required this.onOpenPage});

  final VoidCallback onOpenPage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
            color: AppColors.backgroundBase.withValues(alpha: 0.25),
          ),
          child: const Text(
            '查看请求日志、响应耗时、token 用量和错误详情。',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        PrimaryPillButton(label: '打开日志页', onPressed: onOpenPage),
      ],
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
  const _SessionQuickSettingsSheet({this.embedded = false});

  final bool embedded;

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
    final listPadding = widget.embedded
        ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
        : const EdgeInsets.fromLTRB(16, 10, 16, 16);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_config == null) {
      return Padding(
        padding: listPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.embedded)
              Text('当前会话设置', style: Theme.of(context).textTheme.titleMedium)
            else
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
      padding: listPadding,
      children: [
        if (widget.embedded)
          Text('当前会话设置', style: Theme.of(context).textTheme.titleMedium)
        else
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
    required this.subtitle,
    required this.icon,
    required this.page,
  });

  final AppTab tab;
  final String label;
  final String subtitle;
  final IconData icon;
  final Widget page;
}
