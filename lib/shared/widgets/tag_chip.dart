import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppThemeTokens.secondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(
          alpha: AppThemeTokens.isLight(context) ? 0.14 : 0.18,
        ),
        borderRadius: BorderRadius.circular(AppThemeTokens.radiusPill(context)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: resolvedColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
