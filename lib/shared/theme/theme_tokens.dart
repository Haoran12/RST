import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class AppUiTheme extends ThemeExtension<AppUiTheme> {
  const AppUiTheme({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.card,
    required this.panel,
    required this.panelMuted,
    required this.fieldFill,
    required this.border,
    required this.borderStrong,
    required this.textStrong,
    required this.textSecondary,
    required this.textMuted,
    required this.userBubble,
    required this.systemBubble,
    required this.assistantBubble,
    required this.windowBorder,
    required this.titleBarBackground,
    required this.windowButton,
    required this.windowButtonHover,
    required this.closeHoverBackground,
    required this.success,
    required this.warning,
    required this.error,
    required this.markdownParagraphColor,
    required this.markdownHeadingColor,
    required this.markdownItalicColor,
    required this.markdownBoldColor,
    required this.markdownQuotedColor,
    required this.reasoningBorder,
    required this.reasoningBackground,
    required this.reasoningTitle,
    required this.reasoningParagraph,
    required this.reasoningHeading,
    required this.reasoningItalic,
    required this.reasoningQuoted,
    required this.reasoningContentBackground,
    required this.fontScale,
    required this.messageBubbleOpacity,
    required this.surfaceGlowEnabled,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusField,
    required this.radiusPanel,
    required this.radiusBubble,
    required this.radiusCard,
    required this.radiusPill,
    required this.radiusSheet,
    required this.radiusWindowFrame,
  });

  factory AppUiTheme.fallback({required Brightness brightness}) {
    final isLight = brightness == Brightness.light;
    return AppUiTheme(
      primary: isLight ? const Color(0xFF2563D8) : AppColors.accentPrimary,
      secondary: isLight ? const Color(0xFF0F8F89) : AppColors.accentSecondary,
      background: isLight
          ? const Color(0xFFF3F7FB)
          : AppColors.backgroundElevated,
      card: isLight ? Colors.white : AppColors.surfaceCard,
      panel: isLight ? Colors.white : AppColors.surfaceOverlay,
      panelMuted: isLight
          ? const Color(0xFFEAF1F8)
          : AppColors.backgroundElevated,
      fieldFill: isLight ? const Color(0xFFF8FBFE) : AppColors.surfaceOverlay,
      border: isLight ? const Color(0xFFD8E2EC) : AppColors.borderSubtle,
      borderStrong: isLight ? const Color(0xFF3B82F6) : AppColors.borderStrong,
      textStrong: isLight ? const Color(0xFF101826) : AppColors.textStrong,
      textSecondary: isLight
          ? const Color(0xFF334155)
          : AppColors.textSecondary,
      textMuted: isLight ? const Color(0xFF64748B) : AppColors.textMuted,
      userBubble: isLight ? const Color(0xFFE7F0FF) : AppColors.surfaceActive,
      systemBubble: isLight
          ? const Color(0xFFEEF4FA)
          : AppColors.backgroundElevated,
      assistantBubble: isLight ? Colors.white : AppColors.surfaceOverlay,
      windowBorder: isLight ? const Color(0xFFD8E2EC) : AppColors.borderSubtle,
      titleBarBackground: isLight
          ? const Color(0xFFF6FAFD)
          : AppColors.backgroundElevated,
      windowButton: isLight ? const Color(0xFF64748B) : AppColors.textMuted,
      windowButtonHover: isLight
          ? const Color(0xFF334155)
          : AppColors.textSecondary,
      closeHoverBackground: const Color(0x26EC6A5E),
      success: AppColors.success,
      warning: AppColors.warning,
      error: AppColors.error,
      markdownParagraphColor: isLight
          ? const Color(0xFF334155)
          : AppColors.textStrong,
      markdownHeadingColor: isLight
          ? const Color(0xFF0F172A)
          : AppColors.textStrong,
      markdownItalicColor: isLight
          ? const Color(0xFF64748B)
          : AppColors.textSecondary,
      markdownBoldColor: isLight
          ? const Color(0xFF0F172A)
          : AppColors.textStrong,
      markdownQuotedColor: isLight
          ? const Color(0xFFA56B17)
          : AppColors.warning,
      reasoningBorder: isLight
          ? const Color(0xFFD6E1EC)
          : const Color(0xFF3D5168),
      reasoningBackground: isLight
          ? const Color(0xFFEEF4FA)
          : const Color(0xFF131C27),
      reasoningTitle: isLight
          ? const Color(0xFF51657B)
          : const Color(0xFFAABBD0),
      reasoningParagraph: isLight
          ? const Color(0xFF2C4257)
          : const Color(0xFFE3EAF3),
      reasoningHeading: isLight
          ? const Color(0xFF14283C)
          : const Color(0xFFF6FAFF),
      reasoningItalic: isLight
          ? const Color(0xFF5E7388)
          : const Color(0xFFC7D4E3),
      reasoningQuoted: isLight
          ? const Color(0xFF9E6A19)
          : const Color(0xFFF3C472),
      reasoningContentBackground: isLight
          ? const Color(0xF7FFFFFF)
          : const Color(0xFF1B2735),
      fontScale: 1.0,
      messageBubbleOpacity: 1.0,
      surfaceGlowEnabled: true,
      radiusSmall: 8,
      radiusMedium: 10,
      radiusLarge: 12,
      radiusField: 16,
      radiusPanel: 18,
      radiusBubble: 18,
      radiusCard: 20,
      radiusPill: 999,
      radiusSheet: 28,
      radiusWindowFrame: 26,
    );
  }

  final Color primary;
  final Color secondary;
  final Color background;
  final Color card;
  final Color panel;
  final Color panelMuted;
  final Color fieldFill;
  final Color border;
  final Color borderStrong;
  final Color textStrong;
  final Color textSecondary;
  final Color textMuted;
  final Color userBubble;
  final Color systemBubble;
  final Color assistantBubble;
  final Color windowBorder;
  final Color titleBarBackground;
  final Color windowButton;
  final Color windowButtonHover;
  final Color closeHoverBackground;
  final Color success;
  final Color warning;
  final Color error;
  final Color markdownParagraphColor;
  final Color markdownHeadingColor;
  final Color markdownItalicColor;
  final Color markdownBoldColor;
  final Color markdownQuotedColor;
  final Color reasoningBorder;
  final Color reasoningBackground;
  final Color reasoningTitle;
  final Color reasoningParagraph;
  final Color reasoningHeading;
  final Color reasoningItalic;
  final Color reasoningQuoted;
  final Color reasoningContentBackground;
  final double fontScale;
  final double messageBubbleOpacity;
  final bool surfaceGlowEnabled;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusField;
  final double radiusPanel;
  final double radiusBubble;
  final double radiusCard;
  final double radiusPill;
  final double radiusSheet;
  final double radiusWindowFrame;

  @override
  AppUiTheme copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
    Color? card,
    Color? panel,
    Color? panelMuted,
    Color? fieldFill,
    Color? border,
    Color? borderStrong,
    Color? textStrong,
    Color? textSecondary,
    Color? textMuted,
    Color? userBubble,
    Color? systemBubble,
    Color? assistantBubble,
    Color? windowBorder,
    Color? titleBarBackground,
    Color? windowButton,
    Color? windowButtonHover,
    Color? closeHoverBackground,
    Color? success,
    Color? warning,
    Color? error,
    Color? markdownParagraphColor,
    Color? markdownHeadingColor,
    Color? markdownItalicColor,
    Color? markdownBoldColor,
    Color? markdownQuotedColor,
    Color? reasoningBorder,
    Color? reasoningBackground,
    Color? reasoningTitle,
    Color? reasoningParagraph,
    Color? reasoningHeading,
    Color? reasoningItalic,
    Color? reasoningQuoted,
    Color? reasoningContentBackground,
    double? fontScale,
    double? messageBubbleOpacity,
    bool? surfaceGlowEnabled,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? radiusField,
    double? radiusPanel,
    double? radiusBubble,
    double? radiusCard,
    double? radiusPill,
    double? radiusSheet,
    double? radiusWindowFrame,
  }) {
    return AppUiTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      card: card ?? this.card,
      panel: panel ?? this.panel,
      panelMuted: panelMuted ?? this.panelMuted,
      fieldFill: fieldFill ?? this.fieldFill,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textStrong: textStrong ?? this.textStrong,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      userBubble: userBubble ?? this.userBubble,
      systemBubble: systemBubble ?? this.systemBubble,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      windowBorder: windowBorder ?? this.windowBorder,
      titleBarBackground: titleBarBackground ?? this.titleBarBackground,
      windowButton: windowButton ?? this.windowButton,
      windowButtonHover: windowButtonHover ?? this.windowButtonHover,
      closeHoverBackground: closeHoverBackground ?? this.closeHoverBackground,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      markdownParagraphColor:
          markdownParagraphColor ?? this.markdownParagraphColor,
      markdownHeadingColor: markdownHeadingColor ?? this.markdownHeadingColor,
      markdownItalicColor: markdownItalicColor ?? this.markdownItalicColor,
      markdownBoldColor: markdownBoldColor ?? this.markdownBoldColor,
      markdownQuotedColor: markdownQuotedColor ?? this.markdownQuotedColor,
      reasoningBorder: reasoningBorder ?? this.reasoningBorder,
      reasoningBackground: reasoningBackground ?? this.reasoningBackground,
      reasoningTitle: reasoningTitle ?? this.reasoningTitle,
      reasoningParagraph: reasoningParagraph ?? this.reasoningParagraph,
      reasoningHeading: reasoningHeading ?? this.reasoningHeading,
      reasoningItalic: reasoningItalic ?? this.reasoningItalic,
      reasoningQuoted: reasoningQuoted ?? this.reasoningQuoted,
      reasoningContentBackground:
          reasoningContentBackground ?? this.reasoningContentBackground,
      fontScale: fontScale ?? this.fontScale,
      messageBubbleOpacity: messageBubbleOpacity ?? this.messageBubbleOpacity,
      surfaceGlowEnabled: surfaceGlowEnabled ?? this.surfaceGlowEnabled,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusField: radiusField ?? this.radiusField,
      radiusPanel: radiusPanel ?? this.radiusPanel,
      radiusBubble: radiusBubble ?? this.radiusBubble,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusPill: radiusPill ?? this.radiusPill,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      radiusWindowFrame: radiusWindowFrame ?? this.radiusWindowFrame,
    );
  }

  @override
  AppUiTheme lerp(covariant ThemeExtension<AppUiTheme>? other, double t) {
    if (other is! AppUiTheme) {
      return this;
    }
    return AppUiTheme(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      background: Color.lerp(background, other.background, t) ?? background,
      card: Color.lerp(card, other.card, t) ?? card,
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t) ?? panelMuted,
      fieldFill: Color.lerp(fieldFill, other.fieldFill, t) ?? fieldFill,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      textStrong: Color.lerp(textStrong, other.textStrong, t) ?? textStrong,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      userBubble: Color.lerp(userBubble, other.userBubble, t) ?? userBubble,
      systemBubble:
          Color.lerp(systemBubble, other.systemBubble, t) ?? systemBubble,
      assistantBubble:
          Color.lerp(assistantBubble, other.assistantBubble, t) ??
          assistantBubble,
      windowBorder:
          Color.lerp(windowBorder, other.windowBorder, t) ?? windowBorder,
      titleBarBackground:
          Color.lerp(titleBarBackground, other.titleBarBackground, t) ??
          titleBarBackground,
      windowButton:
          Color.lerp(windowButton, other.windowButton, t) ?? windowButton,
      windowButtonHover:
          Color.lerp(windowButtonHover, other.windowButtonHover, t) ??
          windowButtonHover,
      closeHoverBackground:
          Color.lerp(closeHoverBackground, other.closeHoverBackground, t) ??
          closeHoverBackground,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      markdownParagraphColor:
          Color.lerp(markdownParagraphColor, other.markdownParagraphColor, t) ??
          markdownParagraphColor,
      markdownHeadingColor:
          Color.lerp(markdownHeadingColor, other.markdownHeadingColor, t) ??
          markdownHeadingColor,
      markdownItalicColor:
          Color.lerp(markdownItalicColor, other.markdownItalicColor, t) ??
          markdownItalicColor,
      markdownBoldColor:
          Color.lerp(markdownBoldColor, other.markdownBoldColor, t) ??
          markdownBoldColor,
      markdownQuotedColor:
          Color.lerp(markdownQuotedColor, other.markdownQuotedColor, t) ??
          markdownQuotedColor,
      reasoningBorder:
          Color.lerp(reasoningBorder, other.reasoningBorder, t) ??
          reasoningBorder,
      reasoningBackground:
          Color.lerp(reasoningBackground, other.reasoningBackground, t) ??
          reasoningBackground,
      reasoningTitle:
          Color.lerp(reasoningTitle, other.reasoningTitle, t) ?? reasoningTitle,
      reasoningParagraph:
          Color.lerp(reasoningParagraph, other.reasoningParagraph, t) ??
          reasoningParagraph,
      reasoningHeading:
          Color.lerp(reasoningHeading, other.reasoningHeading, t) ??
          reasoningHeading,
      reasoningItalic:
          Color.lerp(reasoningItalic, other.reasoningItalic, t) ??
          reasoningItalic,
      reasoningQuoted:
          Color.lerp(reasoningQuoted, other.reasoningQuoted, t) ??
          reasoningQuoted,
      reasoningContentBackground:
          Color.lerp(
            reasoningContentBackground,
            other.reasoningContentBackground,
            t,
          ) ??
          reasoningContentBackground,
      fontScale: lerpDouble(fontScale, other.fontScale, t) ?? fontScale,
      messageBubbleOpacity:
          lerpDouble(messageBubbleOpacity, other.messageBubbleOpacity, t) ??
          messageBubbleOpacity,
      surfaceGlowEnabled: t < 0.5
          ? surfaceGlowEnabled
          : other.surfaceGlowEnabled,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t) ?? radiusSmall,
      radiusMedium:
          lerpDouble(radiusMedium, other.radiusMedium, t) ?? radiusMedium,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t) ?? radiusLarge,
      radiusField: lerpDouble(radiusField, other.radiusField, t) ?? radiusField,
      radiusPanel: lerpDouble(radiusPanel, other.radiusPanel, t) ?? radiusPanel,
      radiusBubble:
          lerpDouble(radiusBubble, other.radiusBubble, t) ?? radiusBubble,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t) ?? radiusCard,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t) ?? radiusPill,
      radiusSheet: lerpDouble(radiusSheet, other.radiusSheet, t) ?? radiusSheet,
      radiusWindowFrame:
          lerpDouble(radiusWindowFrame, other.radiusWindowFrame, t) ??
          radiusWindowFrame,
    );
  }
}

class AppThemeTokens {
  const AppThemeTokens._();

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static AppUiTheme of(BuildContext context) =>
      Theme.of(context).extension<AppUiTheme>() ??
      AppUiTheme.fallback(brightness: Theme.of(context).brightness);

  static Color primary(BuildContext context) => of(context).primary;

  static Color secondary(BuildContext context) => of(context).secondary;

  static Color background(BuildContext context) => of(context).background;

  static Color card(BuildContext context) => of(context).card;

  static Color panel(BuildContext context) => of(context).panel;

  static Color panelMuted(BuildContext context) => of(context).panelMuted;

  static Color fieldFill(BuildContext context) => of(context).fieldFill;

  static Color border(BuildContext context) => of(context).border;

  static Color borderStrong(BuildContext context) => of(context).borderStrong;

  static Color textStrong(BuildContext context) => of(context).textStrong;

  static Color textSecondary(BuildContext context) => of(context).textSecondary;

  static Color textMuted(BuildContext context) => of(context).textMuted;

  static Color userBubble(BuildContext context) => of(context).userBubble;

  static Color systemBubble(BuildContext context) => of(context).systemBubble;

  static Color assistantBubble(BuildContext context) =>
      of(context).assistantBubble;

  static Color windowBorder(BuildContext context) => of(context).windowBorder;

  static Color titleBarBackground(BuildContext context) =>
      of(context).titleBarBackground;

  static Color windowButton(BuildContext context) => of(context).windowButton;

  static Color windowButtonHover(BuildContext context) =>
      of(context).windowButtonHover;

  static Color closeHoverBackground(BuildContext context) =>
      of(context).closeHoverBackground;

  static Color success(BuildContext context) => of(context).success;

  static Color warning(BuildContext context) => of(context).warning;

  static Color error(BuildContext context) => of(context).error;

  static Color markdownParagraphColor(BuildContext context) =>
      of(context).markdownParagraphColor;

  static Color markdownHeadingColor(BuildContext context) =>
      of(context).markdownHeadingColor;

  static Color markdownItalicColor(BuildContext context) =>
      of(context).markdownItalicColor;

  static Color markdownBoldColor(BuildContext context) =>
      of(context).markdownBoldColor;

  static Color markdownQuotedColor(BuildContext context) =>
      of(context).markdownQuotedColor;

  static Color reasoningBorder(BuildContext context) =>
      of(context).reasoningBorder;

  static Color reasoningBackground(BuildContext context) =>
      of(context).reasoningBackground;

  static Color reasoningTitle(BuildContext context) =>
      of(context).reasoningTitle;

  static Color reasoningParagraph(BuildContext context) =>
      of(context).reasoningParagraph;

  static Color reasoningHeading(BuildContext context) =>
      of(context).reasoningHeading;

  static Color reasoningItalic(BuildContext context) =>
      of(context).reasoningItalic;

  static Color reasoningQuoted(BuildContext context) =>
      of(context).reasoningQuoted;

  static Color reasoningContentBackground(BuildContext context) =>
      of(context).reasoningContentBackground;

  static double fontScale(BuildContext context) => of(context).fontScale;

  static double messageBubbleOpacity(BuildContext context) =>
      of(context).messageBubbleOpacity;

  static bool surfaceGlowEnabled(BuildContext context) =>
      of(context).surfaceGlowEnabled;

  static double radiusSmall(BuildContext context) => of(context).radiusSmall;

  static double radiusMedium(BuildContext context) => of(context).radiusMedium;

  static double radiusLarge(BuildContext context) => of(context).radiusLarge;

  static double radiusField(BuildContext context) => of(context).radiusField;

  static double radiusPanel(BuildContext context) => of(context).radiusPanel;

  static double radiusBubble(BuildContext context) => of(context).radiusBubble;

  static double radiusCard(BuildContext context) => of(context).radiusCard;

  static double radiusPill(BuildContext context) => of(context).radiusPill;

  static double radiusSheet(BuildContext context) => of(context).radiusSheet;

  static double radiusWindowFrame(BuildContext context) =>
      of(context).radiusWindowFrame;
}
