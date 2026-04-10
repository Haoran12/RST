import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'buttons.dart';
import 'glass_panel_card.dart';

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          SecondaryOutlineButton(label: '重试', onPressed: onRetry),
        ],
      ),
    );
  }
}
