import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      children: const [
        _SettingsSection(title: 'Session', subtitle: '管理会话配置、模式、扫描深度和上下文长度。'),
        SizedBox(height: 10),
        _SettingsSection(
          title: 'API Config',
          subtitle: '管理 provider、模型、请求地址和鉴权。',
        ),
        SizedBox(height: 10),
        _SettingsSection(title: 'Preset', subtitle: '管理主系统指令和生成参数。'),
        SizedBox(height: 10),
        _SettingsSection(title: 'Appearance', subtitle: '管理主题与显示配置。'),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 12),
          Row(
            children: const [
              PrimaryPillButton(label: '进入', onPressed: null),
              SizedBox(width: 8),
              SecondaryOutlineButton(label: '新建', onPressed: null),
            ],
          ),
        ],
      ),
    );
  }
}
