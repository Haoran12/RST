import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'tag_chip.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.hidden = false,
  });

  final String role;
  final String content;
  final bool hidden;

  bool get _isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _isUser ? AppColors.surfaceActive : AppColors.surfaceOverlay,
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
                      _isUser ? 'User' : 'Assistant',
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
                Text(
                  content,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
