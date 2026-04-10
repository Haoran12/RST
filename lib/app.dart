import 'package:flutter/material.dart';

import 'core/routing/app_shell.dart';
import 'shared/theme/app_theme.dart';

class RstApp extends StatelessWidget {
  const RstApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RST',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: const AppShell(),
    );
  }
}
