import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'tag_chip.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.hidden = false,
    this.onDelete,
    this.onCopy,
    this.onRewrite,
  });

  final String role;
  final String content;
  final bool hidden;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onRewrite;

  bool get _isUser => role == 'user';
  bool get _isSystem => role == 'system';
  bool get _hasActions =>
      onDelete != null || onCopy != null || onRewrite != null;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'user' => 'User',
      'system' => 'System',
      _ => 'Assistant',
    };
    final background = _isUser
        ? AppColors.surfaceActive
        : _isSystem
        ? AppColors.backgroundElevated
        : AppColors.surfaceOverlay;

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
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
                SelectableText(
                  content,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    height: 1.45,
                  ),
                ),
                if (_hasActions) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 2,
                      children: [
                        if (onDelete != null)
                          _QuickActionButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: '删除',
                            onPressed: onDelete!,
                          ),
                        if (onCopy != null)
                          _QuickActionButton(
                            icon: Icons.content_copy_rounded,
                            tooltip: '复制',
                            onPressed: onCopy!,
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

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          hoverColor: AppColors.surfaceActive.withValues(alpha: 0.4),
          splashFactory: InkRipple.splashFactory,
        ),
        icon: Icon(icon, size: 16),
      ),
    );
  }
}
