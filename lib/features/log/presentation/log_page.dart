import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import '../../../shared/widgets/status_badge.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = List.generate(
      3,
      (index) => _LogItem(
        model: 'gpt-5.4-mini',
        status: index == 0 ? 'error' : 'success',
        duration: '${320 + index * 40}ms',
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          if (logs.isEmpty)
            EmptyStateView(
              title: '暂无日志',
              description: '发送一轮消息后会出现请求摘要。',
              actionLabel: '去聊天',
              onAction: () {},
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = logs[index];
                  final isError = item.status == 'error';
                  return GlassPanelCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.model,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text('duration: ${item.duration}'),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: item.status,
                          color: isError ? AppColors.error : AppColors.success,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LogItem {
  const _LogItem({
    required this.model,
    required this.status,
    required this.duration,
  });

  final String model;
  final String status;
  final String duration;
}
