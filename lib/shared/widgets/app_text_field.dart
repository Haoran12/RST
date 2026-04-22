import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.hintText,
    this.controller,
    this.maxLines = 1,
    this.readOnly = false,
  });

  final String? hintText;
  final TextEditingController? controller;
  final int maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppThemeTokens.border(context);
    final strongBorderColor = AppThemeTokens.borderStrong(context);

    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppThemeTokens.textMuted(context)),
        filled: true,
        fillColor: AppThemeTokens.fieldFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppThemeTokens.radiusField(context),
          ),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppThemeTokens.radiusField(context),
          ),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppThemeTokens.radiusField(context),
          ),
          borderSide: BorderSide(color: strongBorderColor),
        ),
      ),
    );
  }
}
