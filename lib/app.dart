import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_shell.dart';
import 'core/providers/app_state.dart';
import 'shared/theme/app_theme.dart';

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
      home: const AppShell(),
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
