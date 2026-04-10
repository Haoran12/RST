import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/chat_page.dart';
import '../../features/log/presentation/log_page.dart';
import '../../features/lore/presentation/lore_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../providers/app_state.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _pages = <Widget>[
    ChatPage(),
    LorePage(),
    SettingsPage(),
    LogPage(),
  ];

  static const _titles = <String>['聊天', 'Lore', '设置', '日志'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(appTabProvider);
    final currentIndex = currentTab.index;

    return AppScaffold(
      title: _titles[currentIndex],
      currentIndex: currentIndex,
      showBottomNavigationBar: currentTab != AppTab.chat,
      headerTrailing: PopupMenuButton<int>(
        tooltip: '切换页面',
        icon: const Icon(Icons.grid_view_rounded),
        onSelected: (index) {
          ref.read(appTabProvider.notifier).state = AppTab.values[index];
        },
        itemBuilder: (context) {
          return List<PopupMenuEntry<int>>.generate(_titles.length, (index) {
            return CheckedPopupMenuItem<int>(
              value: index,
              checked: index == currentIndex,
              child: Text(_titles[index]),
            );
          });
        },
      ),
      onDestinationSelected: (index) {
        ref.read(appTabProvider.notifier).state = AppTab.values[index];
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: '聊天',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: 'Lore',
        ),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: '日志',
        ),
      ],
      child: IndexedStack(index: currentIndex, children: _pages),
    );
  }
}
