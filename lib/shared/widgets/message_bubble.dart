import 'package:flutter/material.dart';

import '../utils/reasoning_markup.dart';
import '../utils/responsive.dart';
import '../theme/app_colors.dart';
import 'tag_chip.dart';

class MessageBubbleAppearance {
  const MessageBubbleAppearance({
    required this.paragraphColor,
    required this.headingColor,
    required this.italicColor,
    required this.boldColor,
    required this.quotedColor,
    required this.fontScale,
    required this.bubbleOpacity,
  });

  const MessageBubbleAppearance.defaults()
    : paragraphColor = AppColors.textStrong,
      headingColor = AppColors.textStrong,
      italicColor = AppColors.textSecondary,
      boldColor = AppColors.textStrong,
      quotedColor = AppColors.warning,
      fontScale = 1.0,
      bubbleOpacity = 1.0;

  final Color paragraphColor;
  final Color headingColor;
  final Color italicColor;
  final Color boldColor;
  final Color quotedColor;
  final double fontScale;
  final double bubbleOpacity;
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.messageId,
    required this.role,
    required this.content,
    this.headerMeta,
    this.appearance = const MessageBubbleAppearance.defaults(),
    this.hidden = false,
    this.onToggleVisibility,
    this.onDelete,
    this.onCopy,
    this.onEdit,
    this.onRewrite,
  });

  final String messageId;
  final String role;
  final String content;
  final String? headerMeta;
  final MessageBubbleAppearance appearance;
  final bool hidden;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRewrite;

  bool get _isUser => role == 'user';
  bool get _isSystem => role == 'system';
  bool get _hasActions =>
      onDelete != null ||
      onCopy != null ||
      onEdit != null ||
      onRewrite != null ||
      onToggleVisibility != null;

  @override
  Widget build(BuildContext context) {
    final useCenteredDesktopLayout = Responsive.isWindowsDesktop(context);
    final roleLabel = switch (role) {
      'user' => 'User',
      'system' => 'System',
      _ => 'Assistant',
    };
    final label = (headerMeta == null || headerMeta!.trim().isEmpty)
        ? roleLabel
        : '$roleLabel ${headerMeta!.trim()}';
    final background = _isUser
        ? AppColors.surfaceActive
        : _isSystem
        ? AppColors.backgroundElevated
        : AppColors.surfaceOverlay;
    final parsedMarkup = ReasoningMarkup.parse(content);
    final maxBubbleWidth = useCenteredDesktopLayout
        ? 760.0
        : Responsive.isDesktop(context)
        ? 680.0
        : 420.0;

    return Align(
      alignment: useCenteredDesktopLayout
          ? Alignment.center
          : _isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background.withValues(alpha: appearance.bubbleOpacity),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hidden ? AppColors.warning : AppColors.borderSubtle,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hidden)
                      const TagChip(label: '已隐藏', color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: 8),
                if (parsedMarkup.content.isNotEmpty)
                  _MarkdownMessageText(
                    content: parsedMarkup.content,
                    appearance: appearance,
                  ),
                if (parsedMarkup.hasReasoning) ...[
                  if (parsedMarkup.content.isNotEmpty)
                    const SizedBox(height: 8),
                  _ReasoningPanel(
                    messageId: messageId,
                    reasoning: parsedMarkup.reasoning,
                    appearance: appearance,
                  ),
                ],
                if (_hasActions) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 2,
                      children: [
                        if (onToggleVisibility != null)
                          _QuickActionButton(
                            icon: hidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            tooltip: hidden ? '设为可见' : '设为隐藏',
                            onPressed: onToggleVisibility!,
                          ),
                        if (onDelete != null)
                          _QuickActionButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: '删除',
                            onPressed: onDelete!,
                            foregroundColor: AppColors.error,
                          ),
                        if (onCopy != null)
                          _QuickActionButton(
                            icon: Icons.content_copy_rounded,
                            tooltip: '复制',
                            onPressed: onCopy!,
                          ),
                        if (onEdit != null)
                          _QuickActionButton(
                            icon: Icons.edit_rounded,
                            tooltip: '编辑',
                            onPressed: onEdit!,
                          ),
                        if (onRewrite != null)
                          _QuickActionButton(
                            icon: Icons.edit_note_rounded,
                            tooltip: '改写',
                            onPressed: onRewrite!,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasoningPanel extends StatelessWidget {
  const _ReasoningPanel({
    required this.messageId,
    required this.reasoning,
    required this.appearance,
  });

  final String messageId;
  final String reasoning;
  final MessageBubbleAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final panelBorderColor = isLightTheme
        ? const Color(0xFFD7E0EC)
        : const Color(0xFF3D5168);
    final panelBackgroundColor = isLightTheme
        ? const Color(0xFFF2F5FA)
        : const Color(0xFF131C27);
    final panelTitleColor = isLightTheme
        ? const Color(0xFF4C5D72)
        : const Color(0xFFAABBD0);
    final panelParagraphColor = isLightTheme
        ? const Color(0xFF2A3A4D)
        : const Color(0xFFE3EAF3);
    final panelHeadingColor = isLightTheme
        ? const Color(0xFF172433)
        : const Color(0xFFF6FAFF);
    final panelItalicColor = isLightTheme
        ? const Color(0xFF596D83)
        : const Color(0xFFC7D4E3);
    final panelQuotedColor = isLightTheme
        ? const Color(0xFF9A6A1A)
        : const Color(0xFFF3C472);
    final contentContainerColor = isLightTheme
        ? Colors.white.withValues(alpha: 0.92)
        : const Color(0xFF1B2735);

    final reasoningAppearance = MessageBubbleAppearance(
      paragraphColor: panelParagraphColor,
      headingColor: panelHeadingColor,
      italicColor: panelItalicColor,
      boldColor: panelHeadingColor,
      quotedColor: panelQuotedColor,
      fontScale: (appearance.fontScale * 0.95).clamp(0.8, 1.6),
      bubbleOpacity: appearance.bubbleOpacity,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: panelBorderColor),
        color: panelBackgroundColor,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('reasoning:$messageId'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          dense: true,
          minTileHeight: 32,
          iconColor: panelTitleColor,
          collapsedIconColor: panelTitleColor,
          textColor: panelTitleColor,
          collapsedTextColor: panelTitleColor,
          title: Text(
            '思考',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: panelTitleColor,
            ),
          ),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: panelBorderColor.withValues(alpha: 0.7),
                ),
                color: contentContainerColor,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: _MarkdownMessageText(
                  content: reasoning,
                  appearance: reasoningAppearance,
                  selectable: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownMessageText extends StatelessWidget {
  const _MarkdownMessageText({
    required this.content,
    required this.appearance,
    this.selectable = true,
  });

  static final RegExp _headingPattern = RegExp(r'^\s{0,3}(#{1,6})\s+(.*)$');
  static final RegExp _tokenPattern = RegExp(
    r'(\*\*[^*\n]+?\*\*|__[^_\n]+?__|\*[^*\n]+?\*|_[^_\n]+?_|"[^"\n]+"|“[^”\n]+”)',
  );
  static final RegExp _invisibleCharsPattern = RegExp(
    r'[\u200B\u200C\u200D\uFEFF]',
  );

  final String content;
  final MessageBubbleAppearance appearance;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final normalizedContent = content
        .replaceAll('\r\n', '\n')
        .replaceAll(_invisibleCharsPattern, '');
    final textTheme = Theme.of(context).textTheme;
    final baseSize =
        ((textTheme.bodyLarge?.fontSize ?? 15.0) * appearance.fontScale).clamp(
          10.0,
          40.0,
        );
    final paragraphStyle = TextStyle(
      color: appearance.paragraphColor,
      fontSize: baseSize,
      height: 1.45,
    );
    final headingStyle = paragraphStyle.copyWith(
      color: appearance.headingColor,
      fontWeight: FontWeight.w700,
      fontSize: baseSize + 1.0,
    );
    final blocks = _parseBlocks(normalizedContent);
    if (blocks.isEmpty) {
      final normalized = normalizedContent.trim();
      if (normalized.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildTextWidget(normalized, paragraphStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildTextWidget(
            blocks[i].text,
            blocks[i].isHeading ? headingStyle : paragraphStyle,
          ),
        ],
      ],
    );
  }

  Widget _buildTextWidget(String text, TextStyle baseStyle) {
    final span = TextSpan(children: _buildInlineSpans(text, baseStyle));
    if (selectable) {
      return SelectableText.rich(span);
    }
    return Text.rich(span);
  }

  List<_MarkdownBlock> _parseBlocks(String raw) {
    final lines = raw.split('\n');
    final blocks = <_MarkdownBlock>[];
    final paragraphBuffer = StringBuffer();

    void flushParagraph() {
      final text = paragraphBuffer.toString().trim();
      if (text.isNotEmpty) {
        blocks.add(_MarkdownBlock(text: text, isHeading: false));
      }
      paragraphBuffer.clear();
    }

    for (final line in lines) {
      final headingMatch = _headingPattern.firstMatch(line);
      if (headingMatch != null) {
        flushParagraph();
        final headingText = headingMatch.group(2)?.trim() ?? '';
        if (headingText.isNotEmpty) {
          blocks.add(_MarkdownBlock(text: headingText, isHeading: true));
        }
        continue;
      }

      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }

      if (paragraphBuffer.isNotEmpty) {
        paragraphBuffer.write('\n');
      }
      paragraphBuffer.write(line);
    }
    flushParagraph();
    return blocks;
  }

  List<InlineSpan> _buildInlineSpans(String text, TextStyle baseStyle) {
    if (text.isEmpty) {
      return <InlineSpan>[TextSpan(text: '', style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    var start = 0;

    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: baseStyle),
        );
      }

      final token = match.group(0) ?? '';
      if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(
              color: appearance.boldColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else if (token.startsWith('__') &&
          token.endsWith('__') &&
          token.length > 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(
              color: appearance.boldColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length > 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(
              color: appearance.italicColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (token.startsWith('_') &&
          token.endsWith('_') &&
          token.length > 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(
              color: appearance.italicColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(color: appearance.quotedColor),
          ),
        );
      }

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return spans;
  }
}

class _MarkdownBlock {
  const _MarkdownBlock({required this.text, required this.isHeading});

  final String text;
  final bool isHeading;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.foregroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedForeground = foregroundColor ?? AppColors.textMuted;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: resolvedForeground,
          hoverColor: resolvedForeground.withValues(alpha: 0.16),
          splashFactory: InkRipple.splashFactory,
        ),
        icon: Icon(icon, size: 16),
      ),
    );
  }
}
