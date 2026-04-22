import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

enum AppNoticeTone { info, success, warning, error }

class AppNotice {
  const AppNotice._();

  static const Duration _defaultDuration = Duration(milliseconds: 1800);
  static const Duration _defaultCooldown = Duration(milliseconds: 1500);
  static const Duration _fadeDuration = Duration(milliseconds: 180);

  static final Map<String, DateTime> _recentShownAt = <String, DateTime>{};
  static OverlayEntry? _activeEntry;
  static ValueNotifier<bool>? _activeVisible;
  static Timer? _hideTimer;
  static Timer? _removeTimer;

  static void show(
    BuildContext context, {
    required String message,
    AppNoticeTone tone = AppNoticeTone.info,
    String? category,
    Duration duration = _defaultDuration,
    Duration cooldown = _defaultCooldown,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    final dedupeKey = (category ?? normalizedMessage).trim();
    if (dedupeKey.isNotEmpty) {
      final now = DateTime.now();
      _recentShownAt.removeWhere(
        (_, shownAt) => now.difference(shownAt) > const Duration(minutes: 3),
      );
      final lastShown = _recentShownAt[dedupeKey];
      if (lastShown != null && now.difference(lastShown) < cooldown) {
        return;
      }
      _recentShownAt[dedupeKey] = now;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _dismissActive();

    final visible = ValueNotifier<bool>(false);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) =>
          _TopNotice(message: normalizedMessage, tone: tone, visible: visible),
    );

    _activeEntry = entry;
    _activeVisible = visible;
    overlay.insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_activeVisible == visible) {
        visible.value = true;
      }
    });

    _hideTimer = Timer(duration, () {
      if (_activeVisible != visible) {
        return;
      }
      visible.value = false;
      _removeTimer = Timer(_fadeDuration, () {
        if (_activeVisible == visible) {
          _dismissActive();
        }
      });
    });
  }

  static void _dismissActive() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _removeTimer?.cancel();
    _removeTimer = null;

    final entry = _activeEntry;
    _activeEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }

    _activeVisible?.dispose();
    _activeVisible = null;
  }
}

class _TopNotice extends StatelessWidget {
  const _TopNotice({
    required this.message,
    required this.tone,
    required this.visible,
  });

  final String message;
  final AppNoticeTone tone;
  final ValueListenable<bool> visible;

  @override
  Widget build(BuildContext context) {
    final style = _TopNoticeStyle.fromTone(context, tone);
    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        minimum: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, isVisible, _) {
                return AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  offset: isVisible ? Offset.zero : const Offset(0, -0.2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: isVisible ? 1 : 0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Material(
                        color: Colors.transparent,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: style.backgroundColor,
                            borderRadius: BorderRadius.circular(
                              AppThemeTokens.radiusLarge(context),
                            ),
                            border: Border.all(color: style.borderColor),
                            boxShadow:
                                AppThemeTokens.surfaceGlowEnabled(context)
                                ? const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 14,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  style.icon,
                                  size: 18,
                                  color: style.iconColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    message,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppThemeTokens.textStrong(
                                            context,
                                          ),
                                          height: 1.3,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNoticeStyle {
  const _TopNoticeStyle({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;

  factory _TopNoticeStyle.fromTone(BuildContext context, AppNoticeTone tone) {
    final isLightTheme = AppThemeTokens.isLight(context);
    final panel = AppThemeTokens.panel(context);
    final textStrong = AppThemeTokens.textStrong(context);
    final success = AppThemeTokens.success(context);
    final warning = AppThemeTokens.warning(context);
    final error = AppThemeTokens.error(context);
    final secondary = AppThemeTokens.secondary(context);
    return switch (tone) {
      AppNoticeTone.success => _TopNoticeStyle(
        icon: Icons.check_circle_outline_rounded,
        iconColor: success,
        borderColor: success.withValues(alpha: isLightTheme ? 0.42 : 0.6),
        backgroundColor: isLightTheme
            ? Color.lerp(panel, success, 0.1) ?? panel
            : success.withValues(alpha: 0.14),
      ),
      AppNoticeTone.warning => _TopNoticeStyle(
        icon: Icons.warning_amber_rounded,
        iconColor: warning,
        borderColor: warning.withValues(alpha: isLightTheme ? 0.48 : 0.6),
        backgroundColor: isLightTheme
            ? Color.lerp(panel, warning, 0.12) ?? panel
            : warning.withValues(alpha: 0.14),
      ),
      AppNoticeTone.error => _TopNoticeStyle(
        icon: Icons.error_outline_rounded,
        iconColor: error,
        borderColor: error.withValues(alpha: isLightTheme ? 0.42 : 0.58),
        backgroundColor: isLightTheme
            ? Color.lerp(panel, error, 0.1) ?? panel
            : error.withValues(alpha: 0.14),
      ),
      AppNoticeTone.info => _TopNoticeStyle(
        icon: Icons.info_outline_rounded,
        iconColor: secondary,
        borderColor: secondary.withValues(alpha: isLightTheme ? 0.28 : 0.48),
        backgroundColor: isLightTheme
            ? Color.lerp(panel, secondary, 0.08) ?? panel
            : textStrong.withValues(alpha: 0.08),
      ),
    };
  }
}
