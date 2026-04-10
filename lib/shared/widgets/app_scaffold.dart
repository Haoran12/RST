import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ambient_background.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
    this.showBottomNavigationBar = true,
    this.headerTrailing,
  });

  final String title;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget child;
  final bool showBottomNavigationBar;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    if (headerTrailing != null) ...[
                      headerTrailing!,
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOverlay,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Text(
                        'MVP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        bottomNavigationBar: showBottomNavigationBar
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: NavigationBar(
                    height: 66,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    backgroundColor: Colors.transparent,
                    selectedIndex: currentIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: destinations,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
