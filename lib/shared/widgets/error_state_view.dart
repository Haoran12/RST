import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'app_notice.dart';
import 'buttons.dart';
import 'glass_panel_card.dart';

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '请求失败',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: '复制错误信息',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (!context.mounted) {
                    return;
                  }
                  AppNotice.show(
                    context,
                    message: '错误信息已复制',
                    tone: AppNoticeTone.success,
                    category: 'copy_error_message',
                  );
                },
                icon: const Icon(Icons.copy_all_outlined, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SecondaryOutlineButton(label: '重试', onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}
