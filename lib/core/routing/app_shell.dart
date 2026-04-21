import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../shared/utils/responsive.dart';
import '../providers/app_state.dart';
import '../providers/config_catalog_providers.dart';
import '../providers/service_providers.dart';
import '../services/world_book_injection.dart';

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

  static const _desktopPaneTabs = <AppTab>{
    AppTab.sessionManagement,
    AppTab.worldBook,
    AppTab.preset,
    AppTab.apiConfig,
    AppTab.appearance,
  };

  static final _tabToIndex = <AppTab, int>{
    for (var i = 0; i < _items.length; i++) _items[i].tab: i,
  };

  static _DrawerNavItem _itemForTab(AppTab tab) {
    return _items[_tabToIndex[tab] ?? 0];
  }

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
  static const _desktopPaneAnimationDuration = Duration(milliseconds: 220);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey<NavigatorState> _desktopEditorNavigatorKey =
      GlobalKey<NavigatorState>();
  GlobalKey<_SessionQuickSettingsSheetState> _sessionQuickSettingsKey =
      GlobalKey<_SessionQuickSettingsSheetState>();
  bool _worldBookCatalogHydrated = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _hydrateWorldBookCatalog();
  }

  Future<void> _hydrateWorldBookCatalog() async {
    if (_worldBookCatalogHydrated) {
      return;
    }
    _worldBookCatalogHydrated = true;

    final apiService = ref.read(apiServiceProvider);
    try {
      final loaded = await apiService.loadWorldBookCatalog();
      if (!mounted) {
        return;
      }
      if (loaded == null) {
        final defaults = ref.read(worldBookOptionsProvider);
        await apiService.saveWorldBookCatalog(defaults);
        return;
      }
      ref.read(worldBookOptionsProvider.notifier).state = loaded;
    } catch (_) {
      // Keep default in-memory world books when hydration fails.
    }
  }

  /// Android 系统返回层级（由高到低）：
  /// 1. 子页面路由（Navigator.push 打开的详细设置页）先返回上一页；
  ///    这一层由 Navigator 在本回调前处理。
  /// 2. 若抽屉已打开，优先关闭抽屉。
  /// 3. 若当前不在聊天页，切回聊天页。
  /// 4. 聊天页再次返回，交给系统退出到桌面。
  bool _useDesktopEditorPane(BuildContext context) =>
      Responsive.isWindowsDesktop(context);

  bool _shouldOpenInDesktopPane(AppTab tab) =>
      AppShell._desktopPaneTabs.contains(tab);

  Future<bool> _popDesktopEditorStackToRoot() async {
    final navigator = _desktopEditorNavigatorKey.currentState;
    if (navigator == null) {
      return true;
    }
    while (navigator.canPop()) {
      final popped = await navigator.maybePop();
      if (!popped) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _dismissDesktopEditorPaneIfNeeded() async {
    final pane = ref.read(desktopEditorPaneProvider);
    if (pane == null) {
      return true;
    }
    final dismissed = await _popDesktopEditorStackToRoot();
    if (!dismissed || !mounted) {
      return false;
    }
    if (pane.isSessionQuickSettings) {
      final canClose =
          await _sessionQuickSettingsKey.currentState?.handlePaneDismiss() ??
          true;
      if (!canClose || !mounted) {
        return false;
      }
    }
    ref.read(desktopEditorPaneProvider.notifier).state = null;
    return true;
  }

  Future<void> _handleRootBack(AppTab currentTab) async {
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
      return;
    }
    if (_useDesktopEditorPane(context) &&
        ref.read(desktopEditorPaneProvider) != null) {
      await _dismissDesktopEditorPaneIfNeeded();
      return;
    }
    if (currentTab != AppTab.chat) {
      ref.read(appTabProvider.notifier).state = AppTab.chat;
    }
  }

  Widget _wrapWithWindowsEscBack(Widget child) {
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return child;
    }

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _SystemBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SystemBackIntent: CallbackAction<_SystemBackIntent>(
            onInvoke: (_) {
              unawaited(Navigator.maybePop(context));
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }

  /// 切换tab前检查是否有打开的Dialog/BottomSheet
  Future<void> _handleTabSwitch(AppTab targetTab) async {
    if (_isNavigating) return;

    final currentTab = ref.read(appTabProvider);
    final currentPane = ref.read(desktopEditorPaneProvider);
    final useDesktopPane = _useDesktopEditorPane(context);
    final isTargetDesktopPane =
        useDesktopPane && _shouldOpenInDesktopPane(targetTab);
    final sameDesktopPane =
        isTargetDesktopPane &&
        currentPane != null &&
        currentPane.matchesTab(targetTab);
    if (currentTab == targetTab && !sameDesktopPane && currentPane == null) {
      return;
    }

    // 检查是否有打开的弹窗
    if (Navigator.of(context).canPop()) {
      _isNavigating = true;
      // 弹出当前弹窗，触发其PopScope处理
      Navigator.of(context).pop();
      // 等待弹窗关闭动画完成
      await Future.delayed(const Duration(milliseconds: 100));
      _isNavigating = false;
    }

    if (isTargetDesktopPane) {
      if (sameDesktopPane) {
        await _dismissDesktopEditorPaneIfNeeded();
        return;
      }
      final canCloseCurrent = await _dismissDesktopEditorPaneIfNeeded();
      if (!canCloseCurrent || !mounted) {
        return;
      }
      _desktopEditorNavigatorKey = GlobalKey<NavigatorState>();
      _sessionQuickSettingsKey = GlobalKey<_SessionQuickSettingsSheetState>();
      ref.read(appTabProvider.notifier).state = AppTab.chat;
      ref.read(desktopEditorPaneProvider.notifier).state =
          DesktopEditorPane.tab(targetTab);
      return;
    }

    final canCloseDesktopPane = await _dismissDesktopEditorPaneIfNeeded();
    if (!canCloseDesktopPane || !mounted) {
      return;
    }

    if (mounted) {
      ref.read(appTabProvider.notifier).state = targetTab;
    }
  }

  Future<void> _openSessionQuickSettingsPane() async {
    if (!_useDesktopEditorPane(context)) {
      await _showSessionQuickSettingsBottomSheet(context);
      return;
    }

    final currentPane = ref.read(desktopEditorPaneProvider);
    if (currentPane?.isSessionQuickSettings == true) {
      final canReset = await _popDesktopEditorStackToRoot();
      if (!canReset) {
        return;
      }
      return;
    }

    final canCloseCurrent = await _dismissDesktopEditorPaneIfNeeded();
    if (!canCloseCurrent || !mounted) {
      return;
    }

    _desktopEditorNavigatorKey = GlobalKey<NavigatorState>();
    _sessionQuickSettingsKey = GlobalKey<_SessionQuickSettingsSheetState>();
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    ref.read(desktopEditorPaneProvider.notifier).state =
        const DesktopEditorPane.sessionQuickSettings();
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(appTabProvider);
    final desktopPane = ref.watch(desktopEditorPaneProvider);
    final navTab = _useDesktopEditorPane(context) && desktopPane?.tab != null
        ? desktopPane!.tab!
        : currentTab;
    final currentIndex = AppShell._tabToIndex[navTab] ?? 0;
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final sessionBackgroundMap = ref.watch(sessionBackgroundImageProvider);
    final backgroundImagePath =
        currentTab == AppTab.chat && currentSessionId != null
        ? sessionBackgroundMap[currentSessionId]
        : null;
    final useSidebar = Responsive.useSidebar(context);
    final useDesktopPane = _useDesktopEditorPane(context);

    final drawer = Drawer(
      backgroundColor: AppColors.backgroundElevated,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  'RST',
                  style: Theme.of(context).textTheme.titleLarge,
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
                        _handleTabSwitch(item.tab);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final sidebar = useDesktopPane
        ? _DesktopNavRail(
            currentIndex: currentIndex,
            onSelect: (tab) => _handleTabSwitch(tab),
          )
        : Container(
            width: 240,
            decoration: const BoxDecoration(
              color: AppColors.backgroundElevated,
              border: Border(
                right: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        'RST',
                        style: Theme.of(context).textTheme.titleLarge,
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
                            onTap: () => _handleTabSwitch(item.tab),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    final content = KeyedSubtree(
      key: ValueKey(currentTab),
      child: AppShell._itemForTab(currentTab).page,
    );

    final desktopEditorPane = useDesktopPane
        ? _AnimatedDesktopEditorPaneSlot(
            duration: _desktopPaneAnimationDuration,
            child: desktopPane == null
                ? null
                : _DesktopEditorPaneHost(
                    navigatorKey: _desktopEditorNavigatorKey,
                    sessionQuickSettingsKey: _sessionQuickSettingsKey,
                    pane: desktopPane,
                  ),
          )
        : null;

    if (useSidebar) {
      return _wrapWithWindowsEscBack(
        PopScope<void>(
          canPop: currentTab == AppTab.chat && desktopPane == null,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) {
              return;
            }
            await _handleRootBack(currentTab);
          },
          child: Row(
            children: [
              sidebar,
              if (desktopEditorPane != null) ...[desktopEditorPane],
              Expanded(
                child: AppScaffold(
                  scaffoldKey: _scaffoldKey,
                  backgroundImagePath: backgroundImagePath,
                  headerCenter: const _CurrentSessionHeaderTitle(),
                  headerTrailing: _SessionQuickSettingsTrigger(
                    onPressed: _openSessionQuickSettingsPane,
                  ),
                  showMenuButton: false,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _wrapWithWindowsEscBack(
      PopScope<void>(
        canPop: currentTab == AppTab.chat,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            return;
          }
          await _handleRootBack(currentTab);
        },
        child: AppScaffold(
          scaffoldKey: _scaffoldKey,
          backgroundImagePath: backgroundImagePath,
          headerCenter: const _CurrentSessionHeaderTitle(),
          headerTrailing: _SessionQuickSettingsTrigger(
            onPressed: _openSessionQuickSettingsPane,
          ),
          drawer: drawer,
          child: content,
        ),
      ),
    );
  }
}

class _DesktopEditorPaneHost extends StatelessWidget {
  static const hostWidth = 416.0;

  const _DesktopEditorPaneHost({
    required this.navigatorKey,
    required this.sessionQuickSettingsKey,
    required this.pane,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<_SessionQuickSettingsSheetState> sessionQuickSettingsKey;
  final DesktopEditorPane pane;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: hostWidth,
      color: AppColors.backgroundElevated,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight
                  .clamp(560.0, 940.0)
                  .toDouble();
              final maxWidth = constraints.maxWidth.toDouble();
              final phoneMaxWidth = maxWidth.clamp(352.0, 392.0).toDouble();
              final phoneMinWidth = phoneMaxWidth < 360.0
                  ? phoneMaxWidth
                  : 360.0;
              final phoneWidth = (maxHeight * 390 / 844)
                  .clamp(phoneMinWidth, phoneMaxWidth)
                  .toDouble();

              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: phoneWidth,
                  height: maxHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundElevated,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 22,
                          offset: Offset(4, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          'desktop-editor-${pane.cacheKey}',
                        ),
                        child: Navigator(
                          key: navigatorKey,
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => pane.isSessionQuickSettings
                                ? _SessionQuickSettingsSheet(
                                    key: sessionQuickSettingsKey,
                                    embeddedInDesktopPane: true,
                                  )
                                : AppShell._itemForTab(pane.tab!).page,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedDesktopEditorPaneSlot extends StatelessWidget {
  const _AnimatedDesktopEditorPaneSlot({
    required this.duration,
    required this.child,
  });

  final Duration duration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isVisible = child != null;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: isVisible ? _DesktopEditorPaneHost.hostWidth : 0,
      child: ClipRect(
        child: AnimatedOpacity(
          duration: duration,
          curve: Curves.easeOutCubic,
          opacity: isVisible ? 1 : 0,
          child: IgnorePointer(ignoring: !isVisible, child: child),
        ),
      ),
    );
  }
}

class _DesktopNavRail extends StatelessWidget {
  const _DesktopNavRail({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return TooltipTheme(
      data: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textStrong,
          fontWeight: FontWeight.w600,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderStrong),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
      ),
      child: Container(
        width: 70,
        color: AppColors.backgroundElevated,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOverlay,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'R',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: AppShell._items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = AppShell._items[index];
                      return _DesktopNavButton(
                        label: item.label,
                        icon: item.icon,
                        selected: index == currentIndex,
                        onTap: () => onSelect(item.tab),
                      );
                    },
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

class _DesktopNavButton extends StatelessWidget {
  const _DesktopNavButton({
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
  Widget build(BuildContext context) {
    final background = selected
        ? AppColors.surfaceOverlay.withValues(alpha: 0.9)
        : Colors.transparent;
    final hoverBackground = selected
        ? AppColors.surfaceOverlay.withValues(alpha: 0.96)
        : AppColors.surfaceOverlay.withValues(alpha: 0.64);

    return Tooltip(
      message: label,
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            hoverColor: hoverBackground,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 1,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      opacity: selected ? 1 : 0,
                      child: Container(
                        width: 3,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<Color?>(
                    duration: const Duration(milliseconds: 180),
                    tween: ColorTween(
                      begin: AppColors.textSecondary,
                      end: selected
                          ? AppColors.accentPrimary
                          : AppColors.textSecondary,
                    ),
                    builder: (context, color, _) {
                      return Icon(icon, color: color, size: 22);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemBackIntent extends Intent {
  const _SystemBackIntent();
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
  if (Responsive.isWindowsDesktop(context)) {
    return;
  }
  if (Responsive.isDesktop(context)) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.backgroundElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
          child: const _SessionQuickSettingsSheet(),
        ),
      ),
    );
    return;
  }

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

class _SessionQuickSettingsTrigger extends StatelessWidget {
  const _SessionQuickSettingsTrigger({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '当前会话设置',
      onPressed: () => onPressed(),
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
  const _SessionQuickSettingsSheet({
    super.key,
    this.embeddedInDesktopPane = false,
  });

  final bool embeddedInDesktopPane;

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
  SessionSettingsEditorPageState? _editorState;

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
    return SchedulerMode.sillyTavern;
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
    await _syncSessionWorldBookSnapshot(
      sessionId: saved.sessionId,
      mode: saved.mode,
      worldBookId: saved.stWorldBookId,
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

  Future<void> _syncSessionWorldBookSnapshot({
    required String sessionId,
    required frb.SessionMode mode,
    required String? worldBookId,
  }) async {
    final apiService = ref.read(apiServiceProvider);
    if (mode != frb.SessionMode.st) {
      await apiService.deleteSessionWorldBookSnapshot(sessionId: sessionId);
      return;
    }

    final worldBook = _resolveWorldBookOption(worldBookId);
    final snapshotJson = _worldBookJsonForSnapshot(worldBook);
    if (worldBook == null || snapshotJson == null) {
      await apiService.deleteSessionWorldBookSnapshot(sessionId: sessionId);
      return;
    }

    await apiService.writeSessionWorldBookSnapshot(
      sessionId: sessionId,
      sourceWorldBookId: worldBook.id,
      sourceWorldBookName: worldBook.name,
      worldBookJson: snapshotJson,
    );
  }

  ManagedOption? _resolveWorldBookOption(String? worldBookId) {
    if (worldBookId == null || worldBookId.trim().isEmpty) {
      return null;
    }
    final options = ref.read(worldBookOptionsProvider);
    for (final option in options) {
      if (option.id == worldBookId) {
        return option;
      }
    }
    return null;
  }

  String? _worldBookJsonForSnapshot(ManagedOption? worldBook) {
    if (worldBook == null) {
      return null;
    }
    final raw =
        worldBook.fieldValue(worldBookJsonFieldKey) ??
        worldBook.fieldValue(worldBookLegacyEntriesFieldKey);
    if (raw is! String) {
      return null;
    }
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<void> _attemptCloseToChat() async {
    final shouldClose = await handlePaneDismiss();
    if (!shouldClose || !mounted) {
      return;
    }
    ref.read(appTabProvider.notifier).state = AppTab.chat;
    if (widget.embeddedInDesktopPane) {
      ref.read(desktopEditorPaneProvider.notifier).state = null;
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> handlePaneDismiss() async {
    if (_editorState != null && _editorState!.hasUnsavedChanges) {
      final shouldClose = await _editorState!.handleAttemptDismiss();
      if (!shouldClose || !mounted) {
        return false;
      }
    }
    return true;
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
        onStateCreated: (state) => _editorState = state,
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
