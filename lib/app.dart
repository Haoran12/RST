import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'core/routing/app_shell.dart';
import 'core/providers/app_state.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_colors.dart';

class RstApp extends ConsumerWidget {
  const RstApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAppearance = _resolveActiveAppearance(ref);
    final themeMode = _resolveThemeMode(activeAppearance);

    return MaterialApp(
      title: 'RST',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: _WindowShell(child: const AppShell()),
    );
  }

  ManagedOption? _resolveActiveAppearance(WidgetRef ref) {
    final appearanceOptions = ref.watch(appearanceOptionsProvider);
    if (appearanceOptions.isEmpty) {
      return null;
    }

    final currentSessionId = ref.watch(currentSessionIdProvider);
    final appearanceBySession = ref.watch(sessionAppearanceProvider);
    final selectedAppearanceId = currentSessionId == null
        ? null
        : appearanceBySession[currentSessionId];

    if (selectedAppearanceId != null && selectedAppearanceId.isNotEmpty) {
      for (final option in appearanceOptions) {
        if (option.id == selectedAppearanceId) {
          return option;
        }
      }
    }

    return appearanceOptions.first;
  }

  ThemeMode _resolveThemeMode(ManagedOption? option) {
    if (option == null) {
      return ThemeMode.dark;
    }
    final raw = option.fieldValue('theme_mode');
    if (raw is String && raw.toLowerCase() == 'light') {
      return ThemeMode.light;
    }
    return ThemeMode.dark;
  }
}

class _WindowShell extends StatelessWidget {
  const _WindowShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WindowBorder(
      color: AppColors.borderSubtle,
      width: 1,
      child: Column(
        children: [
          _CustomTitleBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CustomTitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WindowTitleBarBox(
      child: Row(
        children: [
          Expanded(
            child: MoveWindow(
              child: Container(
                height: 32,
                color: AppColors.backgroundElevated,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          _WindowButtons(),
        ],
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final buttonColor = AppColors.textMuted;
    final hoverColor = AppColors.textSecondary;

    return Row(
      children: [
        MinimizeWindowButton(
          colors: WindowButtonColors(
            normal: Colors.transparent,
            iconNormal: buttonColor,
            iconMouseOver: hoverColor,
          ),
        ),
        MaximizeWindowButton(
          colors: WindowButtonColors(
            normal: Colors.transparent,
            iconNormal: buttonColor,
            iconMouseOver: hoverColor,
          ),
        ),
        CloseWindowButton(
          colors: WindowButtonColors(
            normal: Colors.transparent,
            iconNormal: buttonColor,
            iconMouseOver: hoverColor,
            mouseOver: AppColors.error.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}
