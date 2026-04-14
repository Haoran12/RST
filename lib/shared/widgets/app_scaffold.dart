import 'package:flutter/material.dart';

import 'ambient_background.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.drawer,
    this.scaffoldKey,
    this.headerCenter,
    this.headerTrailing,
    this.backgroundImagePath,
  });

  final Widget child;
  final Widget drawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? headerCenter;
  final Widget? headerTrailing;
  final String? backgroundImagePath;

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      backgroundImagePath: backgroundImagePath,
      child: Scaffold(
        key: scaffoldKey,
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
                    if (headerCenter != null)
                      Expanded(child: headerCenter!)
                    else
                      const Spacer(),
                    if (headerTrailing != null) ...[
                      const SizedBox(width: 8),
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
