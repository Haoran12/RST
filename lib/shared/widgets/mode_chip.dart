import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        mode,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
