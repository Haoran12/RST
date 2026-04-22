import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(
          alpha: AppThemeTokens.isLight(context) ? 0.12 : 0.2,
        ),
        borderRadius: BorderRadius.circular(AppThemeTokens.radiusPill(context)),
        border: Border.all(color: primary),
      ),
      child: Text(
        mode,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppThemeTokens.textStrong(context),
        ),
      ),
    );
  }
}
