import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class StreamingIndicator extends StatelessWidget {
  const StreamingIndicator({super.key, this.label = '生成中...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppThemeTokens.secondary(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppThemeTokens.textMuted(context),
          ),
        ),
      ],
    );
  }
}
