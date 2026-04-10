import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F141B), Color(0xFF121A24), Color(0xFF101823)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -20,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentSecondary.withValues(alpha: 0.08),
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
                color: AppColors.accentPrimary.withValues(alpha: 0.10),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
