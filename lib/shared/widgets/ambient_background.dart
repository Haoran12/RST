import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.backgroundImagePath,
  });

  final Widget child;
  final String? backgroundImagePath;

  @override
  Widget build(BuildContext context) {
    final imagePath = backgroundImagePath?.trim() ?? '';
    final hasBackgroundImage = imagePath.isNotEmpty;
    final isLightTheme = AppThemeTokens.isLight(context);
    final background = AppThemeTokens.background(context);
    final panelMuted = AppThemeTokens.panelMuted(context);
    final card = AppThemeTokens.card(context);
    final gradientColors = <Color>[
      Color.lerp(card, background, isLightTheme ? 0.18 : 0.08) ?? background,
      Color.lerp(background, panelMuted, 0.72) ?? panelMuted,
      Color.lerp(panelMuted, background, isLightTheme ? 0.58 : 0.32) ??
          background,
    ];
    final imageOverlayColor = isLightTheme
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.black.withValues(alpha: 0.52);
    final secondaryGlowAlpha = isLightTheme ? 0.12 : 0.08;
    final primaryGlowAlpha = isLightTheme ? 0.14 : 0.10;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          if (hasBackgroundImage)
            Positioned.fill(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          if (hasBackgroundImage)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: imageOverlayColor),
              ),
            ),
          Positioned(
            top: -80,
            right: -20,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppThemeTokens.secondary(
                  context,
                ).withValues(alpha: secondaryGlowAlpha),
              ),
            ),
          ),
          Positioned(
            top: -30,
            left: -20,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppThemeTokens.primary(
                  context,
                ).withValues(alpha: primaryGlowAlpha),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
