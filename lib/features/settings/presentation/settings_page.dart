import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/glass_panel_card.dart';

enum SettingsSection { session, apiConfig, preset, appearance }

class SettingsSectionSpec {
  const SettingsSectionSpec({
    required this.section,
    required this.title,
    required this.subtitle,
  });

  final SettingsSection section;
  final String title;
  final String subtitle;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.section});

  final SettingsSection? section;

  static const _sectionSpecs = <SettingsSectionSpec>[
    SettingsSectionSpec(
      section: SettingsSection.session,
      title: '会话管理',
      subtitle: '管理会话配置、模式、扫描深度和上下文长度。',
    ),
    SettingsSectionSpec(
      section: SettingsSection.apiConfig,
      title: 'API配置',
      subtitle: '管理 provider、模型、请求地址和鉴权。',
    ),
    SettingsSectionSpec(
      section: SettingsSection.preset,
      title: '预设',
      subtitle: '管理主系统指令和生成参数。',
    ),
    SettingsSectionSpec(
      section: SettingsSection.appearance,
      title: '外观',
      subtitle: '管理主题与显示配置。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = section == null
        ? _sectionSpecs
        : _sectionSpecs.where((item) => item.section == section).toList();

    final items = <Widget>[];
    for (var index = 0; index < sections.length; index++) {
      final item = sections[index];
      items.add(_SettingsSection(title: item.title, subtitle: item.subtitle));
      if (index != sections.length - 1) {
        items.add(const SizedBox(height: 10));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      children: items,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              PrimaryPillButton(label: '进入', onPressed: null),
              SecondaryOutlineButton(label: '新建', onPressed: null),
            ],
          ),
        ],
      ),
    );
  }
}
