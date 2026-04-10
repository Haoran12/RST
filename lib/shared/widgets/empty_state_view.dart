import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'buttons.dart';
import 'glass_panel_card.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('暂无可展示内容', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(description),
          const SizedBox(height: 12),
          PrimaryPillButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
