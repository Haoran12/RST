import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/tag_chip.dart';

class LorePage extends StatelessWidget {
  const LorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          const AppTextField(hintText: '搜索 Lore / 标签 / 关键词'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              TagChip(label: 'constant', color: AppColors.accentSecondary),
              TagChip(label: 'ST', color: AppColors.accentPrimary),
              TagChip(label: 'private', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return GlassPanelCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lore Entry ${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text('这里是条目摘要占位，后续接 Rust 检索结果。'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: index.isEven ? 'constant' : 'enabled',
                        color: index.isEven
                            ? AppColors.accentSecondary
                            : AppColors.success,
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
