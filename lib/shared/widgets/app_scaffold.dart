import 'package:flutter/material.dart';

import 'ambient_background.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.drawer,
    this.headerTrailing,
  });

  final Widget child;
  final Widget drawer;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: drawer,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: '打开导航菜单',
                        onPressed: Scaffold.of(context).openDrawer,
                        icon: const Icon(Icons.menu_rounded),
                      ),
                    ),
                    const Spacer(),
                    if (headerTrailing != null) ...[
                      headerTrailing!,
                    ],
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
