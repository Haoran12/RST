import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
        color: backgroundColor ?? AppColors.surfaceCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppColors.borderSubtle),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
