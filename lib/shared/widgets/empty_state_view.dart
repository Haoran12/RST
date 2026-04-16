import 'package:flutter/material.dart';

import 'buttons.dart';
import 'glass_panel_card.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel = '',
    this.onAction,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 12),
            PrimaryPillButton(label: actionLabel, onPressed: onAction!),
          ],
        ],
      ),
    );
  }
}
