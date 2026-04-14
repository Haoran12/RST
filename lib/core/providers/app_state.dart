import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab {
  chat,
  sessionManagement,
  worldBook,
  preset,
  apiConfig,
  appearance,
  log,
}

enum ChatTopStatus { calm, waiting, error }

enum ManagedOptionType { worldBook, preset, apiConfig, appearance }

enum ManagedFieldType {
  text,
  multiline,
  select,
  toggle,
  integer,
  decimal,
  color,
}

class ManagedFieldChoice {
  const ManagedFieldChoice({required this.label, required this.value});

  final String label;
  final String value;
}

class ManagedOptionField {
  const ManagedOptionField({
    required this.key,
    required this.label,
    required this.type,
    required this.value,
    this.helperText,
    this.placeholder,
    this.readOnly = false,
    this.choices = const <ManagedFieldChoice>[],
    this.min,
    this.max,
    this.step,
  });

  final String key;
  final String label;
  final ManagedFieldType type;
  final Object? value;
  final String? helperText;
  final String? placeholder;
  final bool readOnly;
  final List<ManagedFieldChoice> choices;
  final double? min;
  final double? max;
  final double? step;

  ManagedOptionField copyWith({
    String? key,
    String? label,
    ManagedFieldType? type,
    Object? value,
    bool replaceValue = false,
    String? helperText,
    bool replaceHelperText = false,
    String? placeholder,
    bool replacePlaceholder = false,
    bool? readOnly,
    List<ManagedFieldChoice>? choices,
    double? min,
    bool replaceMin = false,
    double? max,
    bool replaceMax = false,
    double? step,
    bool replaceStep = false,
  }) {
    return ManagedOptionField(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      value: replaceValue ? value : (value ?? this.value),
      helperText: replaceHelperText
          ? helperText
          : (helperText ?? this.helperText),
      placeholder: replacePlaceholder
          ? placeholder
          : (placeholder ?? this.placeholder),
      readOnly: readOnly ?? this.readOnly,
      choices: choices ?? this.choices,
      min: replaceMin ? min : (min ?? this.min),
      max: replaceMax ? max : (max ?? this.max),
      step: replaceStep ? step : (step ?? this.step),
    );
  }
}

class ManagedOptionSection {
  const ManagedOptionSection({
    required this.title,
    required this.description,
    required this.fields,
  });

  final String title;
  final String description;
  final List<ManagedOptionField> fields;

  ManagedOptionSection copyWith({
    String? title,
    String? description,
    List<ManagedOptionField>? fields,
  }) {
    return ManagedOptionSection(
      title: title ?? this.title,
      description: description ?? this.description,
      fields: fields ?? this.fields,
    );
  }
}

class ManagedOption {
  const ManagedOption({
    required this.id,
    required this.name,
    required this.description,
    required this.updatedAt,
    required this.type,
    required this.sections,
  });

  final String id;
  final String name;
  final String description;
  final DateTime updatedAt;
  final ManagedOptionType type;
  final List<ManagedOptionSection> sections;

  ManagedOption copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? updatedAt,
    ManagedOptionType? type,
    List<ManagedOptionSection>? sections,
  }) {
    return ManagedOption(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      sections: sections ?? this.sections,
    );
  }

  ManagedOption updateField(String fieldKey, Object? nextValue) {
    final nextSections = sections
        .map(
          (section) => section.copyWith(
            fields: section.fields
                .map(
                  (field) => field.key == fieldKey
                      ? field.copyWith(value: nextValue, replaceValue: true)
                      : field,
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    return copyWith(updatedAt: DateTime.now(), sections: nextSections);
  }

  ManagedOptionField? field(String key) {
    for (final section in sections) {
      for (final field in section.fields) {
        if (field.key == key) {
          return field;
        }
      }
    }
    return null;
  }

  Object? fieldValue(String key) => field(key)?.value;

  String? choiceLabel(String key, String value) {
    final target = field(key);
    if (target == null) {
      return null;
    }
    for (final choice in target.choices) {
      if (choice.value == value) {
        return choice.label;
      }
    }
    return null;
  }
}

final appTabProvider = StateProvider<AppTab>((_) => AppTab.chat);
final currentSessionIdProvider = StateProvider<String?>((_) => null);
final workspaceReloadTickProvider = StateProvider<int>((_) => 0);
final chatTopStatusProvider = StateProvider<ChatTopStatus>(
  (_) => ChatTopStatus.calm,
);

final worldBookOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    buildManagedOptionTemplate(
      ManagedOptionType.worldBook,
      id: 'wb-main',
      name: '主世界书',
      description: '默认剧情知识库与常驻 lore 条目。',
    ),
    buildManagedOptionTemplate(
      ManagedOptionType.worldBook,
      id: 'wb-side-story',
      name: '支线档案',
      description: '用于支线人物与地区事件的补充设定。',
    ),
  ],
);

final presetOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    buildManagedOptionTemplate(
      ManagedOptionType.preset,
      id: 'preset-startup',
      name: 'Startup Preset',
      description: '默认主指令、内置条目顺序与空输入策略。',
    ),
  ],
);

final apiConfigOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    buildManagedOptionTemplate(
      ManagedOptionType.apiConfig,
      id: 'api-startup',
      name: 'Startup API Config',
      description: '默认 OpenAI 兼容配置。',
    ),
  ],
);

final appearanceOptionsProvider = StateProvider<List<ManagedOption>>(
  (_) => <ManagedOption>[
    buildManagedOptionTemplate(
      ManagedOptionType.appearance,
      id: 'appearance-default',
      name: '默认深色',
      description: 'RST MVP 深色主题与 Markdown 着色方案。',
    ),
  ],
);

final sessionAppearanceProvider = StateProvider<Map<String, String>>(
  (_) => <String, String>{},
);

final sessionBackgroundImageProvider = StateProvider<Map<String, String>>(
  (_) => <String, String>{},
);

class SessionRstData {
  const SessionRstData({
    required this.userDescription,
    required this.scene,
    required this.lores,
  });

  final String userDescription;
  final String scene;
  final String lores;
}

final sessionRstDataProvider = StateProvider<Map<String, SessionRstData>>(
  (_) => <String, SessionRstData>{},
);

enum SchedulerMode { direct, rst, agent }

final sessionSchedulerModeProvider = StateProvider<Map<String, SchedulerMode>>(
  (_) => <String, SchedulerMode>{},
);

ManagedOption buildManagedOptionTemplate(
  ManagedOptionType type, {
  required String id,
  required String name,
  required String description,
}) {
  return ManagedOption(
    id: id,
    name: name,
    description: description,
    updatedAt: DateTime.now(),
    type: type,
    sections: switch (type) {
      ManagedOptionType.worldBook => _buildWorldBookSections(),
      ManagedOptionType.preset => _buildPresetSections(),
      ManagedOptionType.apiConfig => _buildApiConfigSections(),
      ManagedOptionType.appearance => _buildAppearanceSections(),
    },
  );
}

List<ManagedOptionSection> _buildWorldBookSections() {
  const scopeChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: '当前会话优先', value: 'session'),
    ManagedFieldChoice(label: '共享资料库', value: 'shared'),
    ManagedFieldChoice(label: '实验草稿区', value: 'draft'),
  ];
  const injectionChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: '常驻注入', value: 'always'),
    ManagedFieldChoice(label: '关键词触发', value: 'keyword'),
    ManagedFieldChoice(label: '混合模式', value: 'hybrid'),
  ];
  const categoryChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: 'world_base', value: 'world_base'),
    ManagedFieldChoice(label: 'place', value: 'place'),
    ManagedFieldChoice(label: 'faction', value: 'faction'),
    ManagedFieldChoice(label: 'character', value: 'character'),
    ManagedFieldChoice(label: 'others', value: 'others'),
  ];

  return const <ManagedOptionSection>[
    ManagedOptionSection(
      title: '基础信息',
      description: '决定这份世界书默认服务哪个场景，以及它在 ST 模式下的挂载方式。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'scope',
          label: '作用范围',
          type: ManagedFieldType.select,
          value: 'session',
          choices: scopeChoices,
        ),
        ManagedOptionField(
          key: 'injection_mode',
          label: '注入模式',
          type: ManagedFieldType.select,
          value: 'hybrid',
          choices: injectionChoices,
        ),
        ManagedOptionField(
          key: 'enabled_by_default',
          label: '默认启用',
          type: ManagedFieldType.toggle,
          value: true,
          helperText: '新建 ST 会话时自动作为候选世界书。',
        ),
      ],
    ),
    ManagedOptionSection(
      title: '检索与触发',
      description: '集中配置触发词、优先级和标签。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'keyword_rule',
          label: '关键词触发词',
          type: ManagedFieldType.text,
          value: '主城, 皇都, 王国议会, 禁忌塔',
          helperText: '逗号分隔，供 ST 模式快速命中。',
        ),
        ManagedOptionField(
          key: 'priority',
          label: '注入优先级',
          type: ManagedFieldType.integer,
          value: 78,
          min: 0,
          max: 100,
          step: 1,
        ),
        ManagedOptionField(
          key: 'default_category',
          label: '默认条目分类',
          type: ManagedFieldType.select,
          value: 'world_base',
          choices: categoryChoices,
        ),
      ],
    ),
    ManagedOptionSection(
      title: '条目规范',
      description: '约束离线导入后的条目行为，避免世界设定在长对话中被冲淡。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'pin_constant_entries',
          label: 'constant 条目优先',
          type: ManagedFieldType.toggle,
          value: true,
        ),
        ManagedOptionField(
          key: 'tag_whitelist',
          label: '默认标签',
          type: ManagedFieldType.multiline,
          value: '主舞台\n势力设定\n不可违背',
          helperText: '每行一个标签，便于后续检索和导出。',
        ),
        ManagedOptionField(
          key: 'notes',
          label: '备注',
          type: ManagedFieldType.multiline,
          value: '用于主线剧情，优先承载地区、组织与常驻人物关系。',
        ),
      ],
    ),
  ];
}

List<ManagedOptionSection> _buildPresetSections() {
  const modeChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: 'RST', value: 'rst'),
    ManagedFieldChoice(label: 'ST', value: 'st'),
  ];

  return const <ManagedOptionSection>[
    ManagedOptionSection(
      title: 'Prompt 骨架',
      description: '配置 Main_Prompt 与额外系统约束。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'preset_mode',
          label: '适用模式',
          type: ManagedFieldType.select,
          value: 'rst',
          choices: modeChoices,
        ),
        ManagedOptionField(
          key: 'main_prompt',
          label: 'Main_Prompt',
          type: ManagedFieldType.multiline,
          value: '你是一个擅长长对话一致性的叙事助手，必须优先遵守世界设定与当前 SceneState。',
        ),
        ManagedOptionField(
          key: 'extra_instruction',
          label: '额外系统指令',
          type: ManagedFieldType.multiline,
          value: '回复时优先保持角色口吻稳定，除非用户明确要求，否则不要跳出现有世界观。',
        ),
      ],
    ),
    ManagedOptionSection(
      title: '系统条目开关',
      description: '管理内置条目开关与顺序。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'builtin_order',
          label: '条目顺序',
          type: ManagedFieldType.multiline,
          value:
              'Main_Prompt\nlores\nuser_description\nchat_history\nscene\nuser_input',
          readOnly: true,
          helperText: '用于查看当前条目顺序。',
        ),
        ManagedOptionField(
          key: 'lores_enabled',
          label: '启用 lores',
          type: ManagedFieldType.toggle,
          value: true,
        ),
        ManagedOptionField(
          key: 'scene_enabled',
          label: '启用 scene',
          type: ManagedFieldType.toggle,
          value: true,
        ),
        ManagedOptionField(
          key: 'user_description_enabled',
          label: '启用 user_description',
          type: ManagedFieldType.toggle,
          value: true,
        ),
      ],
    ),
    ManagedOptionSection(
      title: '空输入策略',
      description: '配置空输入时的处理行为。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'empty_input_behavior',
          label: '空输入行为',
          type: ManagedFieldType.select,
          value: 'reuse_last_user',
          choices: <ManagedFieldChoice>[
            ManagedFieldChoice(
              label: '复用上一条 user 消息',
              value: 'reuse_last_user',
            ),
            ManagedFieldChoice(label: '固定 continue', value: 'continue'),
          ],
        ),
        ManagedOptionField(
          key: 'assistant_prefix',
          label: 'Assistant 前缀',
          type: ManagedFieldType.text,
          value: '',
          helperText: '留空则不追加额外前缀。',
        ),
        ManagedOptionField(
          key: 'preset_comment',
          label: 'Preset 备注',
          type: ManagedFieldType.multiline,
          value: '适合剧情推进与长记忆场景，默认开启 lores 与 scene 注入。',
        ),
      ],
    ),
  ];
}

List<ManagedOptionSection> _buildApiConfigSections() {
  const providerChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: 'OpenAI', value: 'openai'),
    ManagedFieldChoice(label: 'OpenRouter', value: 'openrouter'),
    ManagedFieldChoice(label: 'Gemini', value: 'gemini'),
    ManagedFieldChoice(label: 'Deepseek', value: 'deepseek'),
    ManagedFieldChoice(label: 'Anthropic', value: 'anthropic'),
    ManagedFieldChoice(label: 'OpenAI 兼容', value: 'openai_compatible'),
  ];
  const reasoningChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: '不使用', value: ''),
    ManagedFieldChoice(label: '低', value: 'low'),
    ManagedFieldChoice(label: '中', value: 'medium'),
    ManagedFieldChoice(label: '高', value: 'high'),
  ];

  return const <ManagedOptionSection>[
    ManagedOptionSection(
      title: 'Provider',
      description: '配置来源、地址和鉴权信息。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'provider',
          label: 'Provider',
          type: ManagedFieldType.select,
          value: 'openai_compatible',
          choices: providerChoices,
        ),
        ManagedOptionField(
          key: 'base_url',
          label: 'Base URL',
          type: ManagedFieldType.text,
          value: 'https://api.openai.com/v1',
        ),
        ManagedOptionField(
          key: 'api_key',
          label: 'API Key',
          type: ManagedFieldType.text,
          value: 'sk-********************************',
          helperText: '当前先做脱敏展示，后续可接真实安全存储。',
        ),
        ManagedOptionField(
          key: 'model',
          label: 'Model',
          type: ManagedFieldType.text,
          value: 'gpt-4.1-mini',
        ),
      ],
    ),
    ManagedOptionSection(
      title: '采样参数',
      description: '温度、输出长度与推理强度都在这里收口，方便和会话绑定一起调。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'temperature',
          label: 'Temperature',
          type: ManagedFieldType.decimal,
          value: 0.75,
          min: 0,
          max: 2,
          step: 0.05,
        ),
        ManagedOptionField(
          key: 'max_tokens',
          label: 'Max Tokens',
          type: ManagedFieldType.integer,
          value: 8192,
          min: 256,
          max: 32768,
          step: 256,
        ),
        ManagedOptionField(
          key: 'reasoning_effort',
          label: '推理强度',
          type: ManagedFieldType.select,
          value: 'medium',
          choices: reasoningChoices,
        ),
      ],
    ),
    ManagedOptionSection(
      title: '输出行为',
      description: '用来控制是否流式输出，以及这份配置的默认说明。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'stream',
          label: 'Stream',
          type: ManagedFieldType.toggle,
          value: true,
        ),
        ManagedOptionField(
          key: 'config_note',
          label: '配置说明',
          type: ManagedFieldType.multiline,
          value: '主对话默认配置，兼顾长响应和较高上下文容量。',
        ),
      ],
    ),
  ];
}

List<ManagedOptionSection> _buildAppearanceSections() {
  const themeChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: '深色', value: 'dark'),
    ManagedFieldChoice(label: '浅色', value: 'light'),
  ];
  const fontChoices = <ManagedFieldChoice>[
    ManagedFieldChoice(label: 'System UI', value: 'system'),
    ManagedFieldChoice(label: 'Segoe + 中文', value: 'segoe'),
    ManagedFieldChoice(label: 'Noto Sans SC', value: 'noto'),
    ManagedFieldChoice(label: 'Source Han Sans SC', value: 'source_han'),
    ManagedFieldChoice(label: 'Georgia Serif', value: 'georgia'),
    ManagedFieldChoice(label: 'Fira Sans', value: 'fira'),
  ];
  const markdownColors = <ManagedFieldChoice>[
    ManagedFieldChoice(label: '银灰', value: '#D4D4D4'),
    ManagedFieldChoice(label: '冷白', value: '#F5F5F5'),
    ManagedFieldChoice(label: '浅蓝灰', value: '#CBD5E1'),
    ManagedFieldChoice(label: '琥珀', value: '#FBBF24'),
    ManagedFieldChoice(label: '青蓝', value: '#67E8F9'),
  ];

  return const <ManagedOptionSection>[
    ManagedOptionSection(
      title: '主题',
      description: '配置主题模式和卡片效果。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'theme_mode',
          label: '主题模式',
          type: ManagedFieldType.select,
          value: 'dark',
          choices: themeChoices,
        ),
        ManagedOptionField(
          key: 'surface_glow',
          label: '卡片氛围光',
          type: ManagedFieldType.toggle,
          value: true,
        ),
      ],
    ),
    ManagedOptionSection(
      title: '字体',
      description: '配置字体预设、字体组与字号缩放。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'font_preset',
          label: '字体预设',
          type: ManagedFieldType.select,
          value: 'noto',
          choices: fontChoices,
        ),
        ManagedOptionField(
          key: 'font_family',
          label: '字体组',
          type: ManagedFieldType.text,
          value: '"Noto Sans SC", "Microsoft YaHei", sans-serif',
        ),
        ManagedOptionField(
          key: 'font_scale',
          label: '字号缩放',
          type: ManagedFieldType.decimal,
          value: 1.0,
          min: 0.8,
          max: 1.6,
          step: 0.05,
        ),
      ],
    ),
    ManagedOptionSection(
      title: 'Markdown Styles',
      description: '配置段落、标题、斜体、粗体、引号文字颜色与气泡透明度。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'markdown_paragraph_color',
          label: 'Paragraph Color',
          type: ManagedFieldType.color,
          value: '#D4D4D4',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'markdown_heading_color',
          label: 'Heading Color',
          type: ManagedFieldType.color,
          value: '#F5F5F5',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'markdown_italic_color',
          label: 'Italic Color',
          type: ManagedFieldType.color,
          value: '#CBD5E1',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'markdown_bold_color',
          label: 'Bold Color',
          type: ManagedFieldType.color,
          value: '#F5F5F5',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'markdown_quoted_color',
          label: 'Quoted Text Color',
          type: ManagedFieldType.color,
          value: '#FBBF24',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'message_bubble_opacity',
          label: 'Bubble Opacity',
          type: ManagedFieldType.decimal,
          value: 1.0,
          min: 0.35,
          max: 1.0,
          step: 0.05,
        ),
      ],
    ),
  ];
}
