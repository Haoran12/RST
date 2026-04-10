import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab {
  sessionManagement,
  worldBook,
  preset,
  apiConfig,
  appearance,
  log,
}

final appTabProvider = StateProvider<AppTab>((_) => AppTab.sessionManagement);
final currentSessionIdProvider = StateProvider<String?>((_) => null);

class ManagedOption {
  const ManagedOption({
    required this.id,
    required this.name,
    required this.description,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final DateTime updatedAt;

  ManagedOption copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? updatedAt,
  }) {
    return ManagedOption(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final worldBookOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    ManagedOption(
      id: 'wb-main',
      name: '主世界书',
      description: '默认剧情知识库与常驻 lore 条目。',
      updatedAt: DateTime.now(),
    ),
  ],
);

final presetOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    ManagedOption(
      id: 'preset-startup',
      name: 'Startup Preset',
      description: '默认主指令和生成参数。',
      updatedAt: DateTime.now(),
    ),
  ],
);

final apiConfigOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    ManagedOption(
      id: 'api-startup',
      name: 'Startup API Config',
      description: '默认 OpenAI 兼容配置。',
      updatedAt: DateTime.now(),
    ),
  ],
);

final appearanceOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    ManagedOption(
      id: 'appearance-default',
      name: '默认深色',
      description: 'RST MVP 深色主题。',
      updatedAt: DateTime.now(),
    ),
  ],
);

final sessionAppearanceProvider = StateProvider<Map<String, String>>(
  (_) => <String, String>{},
);

enum SchedulerMode { direct, rst, agent }

final sessionSchedulerModeProvider = StateProvider<Map<String, SchedulerMode>>(
  (_) => <String, SchedulerMode>{},
);
