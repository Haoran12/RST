import 'package:flutter/material.dart';

import '../../core/providers/app_state.dart';
import 'theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData lightTheme({ManagedOption? appearance}) {
    return _buildTheme(brightness: Brightness.light, appearance: appearance);
  }

  static ThemeData darkTheme({ManagedOption? appearance}) {
    return _buildTheme(brightness: Brightness.dark, appearance: appearance);
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    ManagedOption? appearance,
  }) {
    final defaults = AppUiTheme.fallback(brightness: brightness);
    final ui = defaults.copyWith(
      primary: _readColorField(appearance, 'primary_color', defaults.primary),
      secondary: _readColorField(
        appearance,
        'secondary_color',
        defaults.secondary,
      ),
      background: _readColorField(
        appearance,
        'background_color',
        defaults.background,
      ),
      card: _readColorField(appearance, 'card_color', defaults.card),
      panel: _readColorField(appearance, 'panel_color', defaults.panel),
      panelMuted: _readColorField(
        appearance,
        'panel_muted_color',
        defaults.panelMuted,
      ),
      fieldFill: _readColorField(
        appearance,
        'field_fill_color',
        defaults.fieldFill,
      ),
      border: _readColorField(appearance, 'border_color', defaults.border),
      borderStrong: _readColorField(
        appearance,
        'border_strong_color',
        defaults.borderStrong,
      ),
      textStrong: _readColorField(
        appearance,
        'text_strong_color',
        defaults.textStrong,
      ),
      textSecondary: _readColorField(
        appearance,
        'text_secondary_color',
        defaults.textSecondary,
      ),
      textMuted: _readColorField(
        appearance,
        'text_muted_color',
        defaults.textMuted,
      ),
      userBubble: _readColorField(
        appearance,
        'user_bubble_color',
        defaults.userBubble,
      ),
      systemBubble: _readColorField(
        appearance,
        'system_bubble_color',
        defaults.systemBubble,
      ),
      assistantBubble: _readColorField(
        appearance,
        'assistant_bubble_color',
        defaults.assistantBubble,
      ),
      windowBorder: _readColorField(
        appearance,
        'window_border_color',
        defaults.windowBorder,
      ),
      titleBarBackground: _readColorField(
        appearance,
        'title_bar_background_color',
        defaults.titleBarBackground,
      ),
      windowButton: _readColorField(
        appearance,
        'window_button_color',
        defaults.windowButton,
      ),
      windowButtonHover: _readColorField(
        appearance,
        'window_button_hover_color',
        defaults.windowButtonHover,
      ),
      closeHoverBackground: _readColorField(
        appearance,
        'window_close_hover_background_color',
        defaults.closeHoverBackground,
      ),
      success: _readColorField(appearance, 'success_color', defaults.success),
      warning: _readColorField(appearance, 'warning_color', defaults.warning),
      error: _readColorField(appearance, 'error_color', defaults.error),
      markdownParagraphColor: _readColorField(
        appearance,
        'markdown_paragraph_color',
        defaults.markdownParagraphColor,
      ),
      markdownHeadingColor: _readColorField(
        appearance,
        'markdown_heading_color',
        defaults.markdownHeadingColor,
      ),
      markdownItalicColor: _readColorField(
        appearance,
        'markdown_italic_color',
        defaults.markdownItalicColor,
      ),
      markdownBoldColor: _readColorField(
        appearance,
        'markdown_bold_color',
        defaults.markdownBoldColor,
      ),
      markdownQuotedColor: _readColorField(
        appearance,
        'markdown_quoted_color',
        defaults.markdownQuotedColor,
      ),
      reasoningBorder: _readColorField(
        appearance,
        'reasoning_border_color',
        defaults.reasoningBorder,
      ),
      reasoningBackground: _readColorField(
        appearance,
        'reasoning_background_color',
        defaults.reasoningBackground,
      ),
      reasoningTitle: _readColorField(
        appearance,
        'reasoning_title_color',
        defaults.reasoningTitle,
      ),
      reasoningParagraph: _readColorField(
        appearance,
        'reasoning_paragraph_color',
        defaults.reasoningParagraph,
      ),
      reasoningHeading: _readColorField(
        appearance,
        'reasoning_heading_color',
        defaults.reasoningHeading,
      ),
      reasoningItalic: _readColorField(
        appearance,
        'reasoning_italic_color',
        defaults.reasoningItalic,
      ),
      reasoningQuoted: _readColorField(
        appearance,
        'reasoning_quoted_color',
        defaults.reasoningQuoted,
      ),
      reasoningContentBackground: _readColorField(
        appearance,
        'reasoning_content_background_color',
        defaults.reasoningContentBackground,
      ),
      fontScale: _readDoubleField(
        appearance,
        'font_scale',
        defaults.fontScale,
      ).clamp(0.8, 1.6),
      messageBubbleOpacity: _readDoubleField(
        appearance,
        'message_bubble_opacity',
        defaults.messageBubbleOpacity,
      ).clamp(0.0, 1.0),
      surfaceGlowEnabled: _readBoolField(
        appearance,
        'surface_glow',
        defaults.surfaceGlowEnabled,
      ),
      radiusSmall: _readDoubleField(
        appearance,
        'radius_small',
        defaults.radiusSmall,
      ).clamp(0.0, 64.0),
      radiusMedium: _readDoubleField(
        appearance,
        'radius_medium',
        defaults.radiusMedium,
      ).clamp(0.0, 64.0),
      radiusLarge: _readDoubleField(
        appearance,
        'radius_large',
        defaults.radiusLarge,
      ).clamp(0.0, 80.0),
      radiusField: _readDoubleField(
        appearance,
        'radius_field',
        defaults.radiusField,
      ).clamp(0.0, 80.0),
      radiusPanel: _readDoubleField(
        appearance,
        'radius_panel',
        defaults.radiusPanel,
      ).clamp(0.0, 80.0),
      radiusBubble: _readDoubleField(
        appearance,
        'radius_bubble',
        defaults.radiusBubble,
      ).clamp(0.0, 80.0),
      radiusCard: _readDoubleField(
        appearance,
        'radius_card',
        defaults.radiusCard,
      ).clamp(0.0, 80.0),
      radiusPill: _readDoubleField(
        appearance,
        'radius_pill',
        defaults.radiusPill,
      ).clamp(0.0, 999.0),
      radiusSheet: _readDoubleField(
        appearance,
        'radius_sheet',
        defaults.radiusSheet,
      ).clamp(0.0, 120.0),
      radiusWindowFrame: _readDoubleField(
        appearance,
        'radius_window_frame',
        defaults.radiusWindowFrame,
      ).clamp(0.0, 120.0),
    );

    final colorScheme = brightness == Brightness.light
        ? ColorScheme.light(
            primary: ui.primary,
            secondary: ui.secondary,
            surface: ui.card,
            error: ui.error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: ui.textStrong,
            onError: Colors.white,
          )
        : ColorScheme.dark(
            primary: ui.primary,
            secondary: ui.secondary,
            surface: ui.card,
            error: ui.error,
            onPrimary: ui.background,
            onSecondary: ui.background,
            onSurface: ui.textStrong,
            onError: ui.textStrong,
          );

    final textTheme = _buildTextTheme(ui);
    final fontFamily = _resolveFontFamily(appearance);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ui.radiusField),
      borderSide: BorderSide(color: ui.border),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ui.radiusField),
      borderSide: BorderSide(color: ui.borderStrong),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ui.background,
      fontFamily: fontFamily,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: ui.textSecondary),
      dividerColor: ui.border,
      extensions: <ThemeExtension<dynamic>>[ui],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: ui.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radiusCard),
        ),
      ),
      dividerTheme: DividerThemeData(color: ui.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: textTheme.bodyMedium?.copyWith(color: ui.textMuted),
        filled: true,
        fillColor: ui.fieldFill,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedInputBorder,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ui.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ui.radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ui.textStrong,
          side: BorderSide(color: ui.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ui.radiusPill),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ui.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ui.radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ui.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radiusCard),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ui.background.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(ui.radiusLarge),
          border: Border.all(color: ui.border),
        ),
        textStyle: textTheme.labelLarge?.copyWith(color: ui.textStrong),
      ),
    );
  }

  static TextTheme _buildTextTheme(AppUiTheme ui) {
    final scale = ui.fontScale;
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24 * scale,
        fontWeight: FontWeight.w700,
        color: ui.textStrong,
      ),
      titleLarge: TextStyle(
        fontSize: 18 * scale,
        fontWeight: FontWeight.w600,
        color: ui.textStrong,
      ),
      titleMedium: TextStyle(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w600,
        color: ui.textStrong,
      ),
      titleSmall: TextStyle(
        fontSize: 14 * scale,
        fontWeight: FontWeight.w600,
        color: ui.textStrong,
      ),
      bodyLarge: TextStyle(
        fontSize: 15 * scale,
        height: 1.5,
        color: ui.textSecondary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13 * scale,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: ui.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12 * scale,
        height: 1.35,
        color: ui.textMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 12 * scale,
        fontWeight: FontWeight.w600,
        color: ui.textStrong,
      ),
      labelMedium: TextStyle(
        fontSize: 11 * scale,
        fontWeight: FontWeight.w600,
        color: ui.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 10 * scale,
        fontWeight: FontWeight.w600,
        color: ui.textMuted,
      ),
    );
  }

  static String? _resolveFontFamily(ManagedOption? appearance) {
    final customRaw = _readStringField(appearance, 'font_family');
    final customPrimary = _extractPrimaryFontFamily(customRaw);
    if (customPrimary != null) {
      return customPrimary;
    }

    final preset = _readStringField(appearance, 'font_preset')?.toLowerCase();
    return switch (preset) {
      null || '' || 'system' => null,
      'segoe' => 'Segoe UI',
      'noto' => 'Noto Sans SC',
      'source_han' => 'Source Han Sans SC',
      'georgia' => 'Georgia',
      'fira' => 'Fira Sans',
      _ => null,
    };
  }

  static String? _extractPrimaryFontFamily(String? raw) {
    if (raw == null) {
      return null;
    }
    final first = raw
        .split(',')
        .first
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '');
    if (first.isEmpty) {
      return null;
    }
    final normalized = first.toLowerCase();
    if (normalized == 'sans-serif' ||
        normalized == 'serif' ||
        normalized == 'monospace' ||
        normalized == 'system-ui') {
      return null;
    }
    return first;
  }

  static String? _readStringField(ManagedOption? option, String key) {
    if (option == null) {
      return null;
    }
    final value = option.fieldValue(key);
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static double _readDoubleField(
    ManagedOption? option,
    String key,
    double fallback,
  ) {
    if (option == null) {
      return fallback;
    }
    final value = option.fieldValue(key);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized) ?? fallback;
    }
    return fallback;
  }

  static bool _readBoolField(ManagedOption? option, String key, bool fallback) {
    if (option == null) {
      return fallback;
    }
    final value = option.fieldValue(key);
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  static Color _readColorField(
    ManagedOption? option,
    String key,
    Color fallback,
  ) {
    final raw = _readStringField(option, key);
    if (raw == null) {
      return fallback;
    }
    var normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    if (normalized.length == 6) {
      normalized = 'FF$normalized';
    }
    if (normalized.length != 8) {
      return fallback;
    }
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}
