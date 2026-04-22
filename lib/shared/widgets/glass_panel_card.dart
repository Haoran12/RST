import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class GlassPanelCard extends StatelessWidget {
  const GlassPanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            AppThemeTokens.card(
              context,
            ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.96 : 0.9),
        borderRadius: BorderRadius.circular(AppThemeTokens.radiusCard(context)),
        border: Border.all(
          color: borderColor ?? AppThemeTokens.border(context),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
