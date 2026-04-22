import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppThemeTokens.radiusPill(context),
          ),
        ),
      ),
      child: Text(label),
    );
  }
}

class SecondaryOutlineButton extends StatelessWidget {
  const SecondaryOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppThemeTokens.textStrong(context),
        side: BorderSide(color: AppThemeTokens.border(context)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppThemeTokens.radiusPill(context),
          ),
        ),
      ),
      child: Text(label),
    );
  }
}
