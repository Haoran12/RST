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

class DesktopEditorPane {
  const DesktopEditorPane._({this.tab});

  const DesktopEditorPane.tab(AppTab tab) : this._(tab: tab);
  const DesktopEditorPane.sessionQuickSettings() : this._();

  final AppTab? tab;

  bool get isSessionQuickSettings => tab == null;

  String get cacheKey =>
      isSessionQuickSettings ? 'session-quick-settings' : 'tab-${tab!.name}';

  bool matchesTab(AppTab value) => tab == value;
}

final appTabProvider = StateProvider<AppTab>((_) => AppTab.chat);
final currentSessionIdProvider = StateProvider<String?>((_) => null);
final desktopEditorPaneProvider = StateProvider<DesktopEditorPane?>(
  (_) => null,
);
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
    buildAppearanceOptionTemplate(
      id: 'appearance-default',
      name: '默认深色',
      description: 'RST MVP 深色主题与 Markdown 着色方案。',
      themeMode: 'dark',
    ),
    buildAppearanceOptionTemplate(
      id: 'appearance-default-light',
      name: '默认浅色',
      description: 'RST 默认浅色主题与更明亮的阅读背景。',
      themeMode: 'light',
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

enum SchedulerMode { sillyTavern, rst, agent }

SchedulerMode schedulerModeFromWire(Object? raw) {
  final normalized = '$raw'.trim();
  for (final value in SchedulerMode.values) {
    if (value.name == normalized) {
      return value;
    }
  }
  return SchedulerMode.sillyTavern;
}

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

ManagedOption buildAppearanceOptionTemplate({
  required String id,
  required String name,
  required String description,
  required String themeMode,
}) {
  var option = buildManagedOptionTemplate(
    ManagedOptionType.appearance,
    id: id,
    name: name,
    description: description,
  ).updateField('theme_mode', themeMode);

  if (themeMode == 'light') {
    option = option
        .updateField('font_preset', 'system')
        .updateField('font_family', '"Segoe UI", "Microsoft YaHei", sans-serif')
        .updateField('primary_color', '#2563D8')
        .updateField('secondary_color', '#0F8F89')
        .updateField('background_color', '#F3F7FB')
        .updateField('card_color', '#FFFFFF')
        .updateField('panel_color', '#FFFFFF')
        .updateField('panel_muted_color', '#EAF1F8')
        .updateField('field_fill_color', '#F8FBFE')
        .updateField('border_color', '#D8E2EC')
        .updateField('border_strong_color', '#3B82F6')
        .updateField('text_strong_color', '#101826')
        .updateField('text_secondary_color', '#334155')
        .updateField('text_muted_color', '#64748B')
        .updateField('user_bubble_color', '#E7F0FF')
        .updateField('assistant_bubble_color', '#FFFFFF')
        .updateField('system_bubble_color', '#EEF4FA')
        .updateField('window_border_color', '#D8E2EC')
        .updateField('title_bar_background_color', '#F6FAFD')
        .updateField('window_button_color', '#64748B')
        .updateField('window_button_hover_color', '#334155')
        .updateField('window_close_hover_background_color', '#26EC6A5E')
        .updateField('success_color', '#43C488')
        .updateField('warning_color', '#F3B24F')
        .updateField('error_color', '#EC6A5E')
        .updateField('markdown_paragraph_color', '#334155')
        .updateField('markdown_heading_color', '#0F172A')
        .updateField('markdown_italic_color', '#64748B')
        .updateField('markdown_bold_color', '#0F172A')
        .updateField('markdown_quoted_color', '#A56B17')
        .updateField('reasoning_border_color', '#D6E1EC')
        .updateField('reasoning_background_color', '#EEF4FA')
        .updateField('reasoning_title_color', '#51657B')
        .updateField('reasoning_paragraph_color', '#2C4257')
        .updateField('reasoning_heading_color', '#14283C')
        .updateField('reasoning_italic_color', '#5E7388')
        .updateField('reasoning_quoted_color', '#9E6A19')
        .updateField('reasoning_content_background_color', '#F7FFFFFF');
  }

  return option;
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
              'Main_Prompt\nlore_before\nuser_description\nchat_history\nlore_after\nscene\ninteractive_input',
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
  const surfaceColors = <ManagedFieldChoice>[
    ManagedFieldChoice(label: '夜幕', value: '#151C24'),
    ManagedFieldChoice(label: '深卡片', value: '#1B2430'),
    ManagedFieldChoice(label: '白', value: '#FFFFFF'),
    ManagedFieldChoice(label: '浅雾', value: '#F2F5FA'),
    ManagedFieldChoice(label: '冷灰', value: '#D7E2EE'),
  ];
  const accentColors = <ManagedFieldChoice>[
    ManagedFieldChoice(label: '主蓝', value: '#2F7CFF'),
    ManagedFieldChoice(label: '海蓝', value: '#2B66D4'),
    ManagedFieldChoice(label: '青绿', value: '#32C7C1'),
    ManagedFieldChoice(label: '深青', value: '#0F8F89'),
    ManagedFieldChoice(label: '珊瑚', value: '#EC6A5E'),
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
      title: 'Color Tokens',
      description: '统一配置主色、表面色、边框和文本色，后续可直接映射为 CSS 变量。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'primary_color',
          label: 'Primary',
          type: ManagedFieldType.color,
          value: '#2F7CFF',
          choices: accentColors,
        ),
        ManagedOptionField(
          key: 'secondary_color',
          label: 'Secondary',
          type: ManagedFieldType.color,
          value: '#32C7C1',
          choices: accentColors,
        ),
        ManagedOptionField(
          key: 'background_color',
          label: 'Background',
          type: ManagedFieldType.color,
          value: '#151C24',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'card_color',
          label: 'Card',
          type: ManagedFieldType.color,
          value: '#1B2430',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'panel_color',
          label: 'Panel',
          type: ManagedFieldType.color,
          value: '#243140',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'panel_muted_color',
          label: 'Muted Panel',
          type: ManagedFieldType.color,
          value: '#151C24',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'field_fill_color',
          label: 'Field Fill',
          type: ManagedFieldType.color,
          value: '#243140',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'border_color',
          label: 'Border',
          type: ManagedFieldType.color,
          value: '#314154',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'border_strong_color',
          label: 'Strong Border',
          type: ManagedFieldType.color,
          value: '#4C8DFF',
          choices: accentColors,
        ),
        ManagedOptionField(
          key: 'text_strong_color',
          label: 'Text Strong',
          type: ManagedFieldType.color,
          value: '#F4F7FB',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'text_secondary_color',
          label: 'Text Secondary',
          type: ManagedFieldType.color,
          value: '#C3CDD9',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'text_muted_color',
          label: 'Text Muted',
          type: ManagedFieldType.color,
          value: '#8C99A8',
          choices: markdownColors,
        ),
      ],
    ),
    ManagedOptionSection(
      title: 'Window And Chat Surfaces',
      description: '集中管理窗口按钮、消息气泡和状态色。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'user_bubble_color',
          label: 'User Bubble',
          type: ManagedFieldType.color,
          value: '#2D3D52',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'assistant_bubble_color',
          label: 'Assistant Bubble',
          type: ManagedFieldType.color,
          value: '#243140',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'system_bubble_color',
          label: 'System Bubble',
          type: ManagedFieldType.color,
          value: '#151C24',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'window_border_color',
          label: 'Window Border',
          type: ManagedFieldType.color,
          value: '#314154',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'title_bar_background_color',
          label: 'Title Bar',
          type: ManagedFieldType.color,
          value: '#151C24',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'window_button_color',
          label: 'Window Button',
          type: ManagedFieldType.color,
          value: '#8C99A8',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'window_button_hover_color',
          label: 'Window Button Hover',
          type: ManagedFieldType.color,
          value: '#C3CDD9',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'window_close_hover_background_color',
          label: 'Close Hover Bg',
          type: ManagedFieldType.color,
          value: '#26EC6A5E',
        ),
        ManagedOptionField(
          key: 'success_color',
          label: 'Success',
          type: ManagedFieldType.color,
          value: '#43C488',
          choices: accentColors,
        ),
        ManagedOptionField(
          key: 'warning_color',
          label: 'Warning',
          type: ManagedFieldType.color,
          value: '#F3B24F',
          choices: accentColors,
        ),
        ManagedOptionField(
          key: 'error_color',
          label: 'Error',
          type: ManagedFieldType.color,
          value: '#EC6A5E',
          choices: accentColors,
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
          min: 0.0,
          max: 1.0,
          step: 0.05,
        ),
      ],
    ),
    ManagedOptionSection(
      title: 'Reasoning Panel',
      description: '把思考面板也收敛成语义 token，避免再次在组件里写死颜色。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'reasoning_border_color',
          label: 'Reasoning Border',
          type: ManagedFieldType.color,
          value: '#3D5168',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'reasoning_background_color',
          label: 'Reasoning Background',
          type: ManagedFieldType.color,
          value: '#131C27',
          choices: surfaceColors,
        ),
        ManagedOptionField(
          key: 'reasoning_title_color',
          label: 'Reasoning Title',
          type: ManagedFieldType.color,
          value: '#AABBD0',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'reasoning_paragraph_color',
          label: 'Reasoning Paragraph',
          type: ManagedFieldType.color,
          value: '#E3EAF3',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'reasoning_heading_color',
          label: 'Reasoning Heading',
          type: ManagedFieldType.color,
          value: '#F6FAFF',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'reasoning_italic_color',
          label: 'Reasoning Italic',
          type: ManagedFieldType.color,
          value: '#C7D4E3',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'reasoning_quoted_color',
          label: 'Reasoning Quoted',
          type: ManagedFieldType.color,
          value: '#F3C472',
          choices: markdownColors,
        ),
        ManagedOptionField(
          key: 'reasoning_content_background_color',
          label: 'Reasoning Content Bg',
          type: ManagedFieldType.color,
          value: '#1B2735',
          choices: surfaceColors,
        ),
      ],
    ),
    ManagedOptionSection(
      title: 'Shape Tokens',
      description: '把常用圆角收敛成 token，便于统一换肤或做 CSS 风格映射。',
      fields: <ManagedOptionField>[
        ManagedOptionField(
          key: 'radius_small',
          label: 'Radius Small',
          type: ManagedFieldType.decimal,
          value: 8,
          min: 0,
          max: 64,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_medium',
          label: 'Radius Medium',
          type: ManagedFieldType.decimal,
          value: 10,
          min: 0,
          max: 64,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_large',
          label: 'Radius Large',
          type: ManagedFieldType.decimal,
          value: 12,
          min: 0,
          max: 80,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_field',
          label: 'Radius Field',
          type: ManagedFieldType.decimal,
          value: 16,
          min: 0,
          max: 80,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_panel',
          label: 'Radius Panel',
          type: ManagedFieldType.decimal,
          value: 18,
          min: 0,
          max: 80,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_bubble',
          label: 'Radius Bubble',
          type: ManagedFieldType.decimal,
          value: 18,
          min: 0,
          max: 80,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_card',
          label: 'Radius Card',
          type: ManagedFieldType.decimal,
          value: 20,
          min: 0,
          max: 80,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_pill',
          label: 'Radius Pill',
          type: ManagedFieldType.decimal,
          value: 999,
          min: 0,
          max: 999,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_sheet',
          label: 'Radius Sheet',
          type: ManagedFieldType.decimal,
          value: 28,
          min: 0,
          max: 120,
          step: 1,
        ),
        ManagedOptionField(
          key: 'radius_window_frame',
          label: 'Radius Window Frame',
          type: ManagedFieldType.decimal,
          value: 26,
          min: 0,
          max: 120,
          step: 1,
        ),
      ],
    ),
  ];
}
