import 'package:flutter/material.dart';

import '../../../core/models/agent/baseline_body_profile.dart';
import '../../../core/models/agent/character_runtime_state.dart';
import '../../../core/models/agent/temporary_body_state.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/theme_tokens.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class AgentCharacterEditorPage extends StatefulWidget {
  const AgentCharacterEditorPage({
    super.key,
    this.initialState,
    this.onSave,
  });

  final CharacterRuntimeState? initialState;
  final void Function(CharacterRuntimeState state)? onSave;

  @override
  State<AgentCharacterEditorPage> createState() =>
      AgentCharacterEditorPageState();
}

class AgentCharacterEditorPageState extends State<AgentCharacterEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late String _characterId;
  late CharacterProfile _profile;
  late MindModelCard _mindModelCard;
  late BaselineBodyProfile _baselineBodyProfile;
  late EmotionState _emotionState;
  late BeliefState _beliefState;
  late CurrentGoals _currentGoals;

  late final String? _initialCharacterId;
  late final CharacterProfile? _initialProfile;
  late final MindModelCard? _initialMindModelCard;
  late final BaselineBodyProfile? _initialBaselineBodyProfile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final initial = widget.initialState;
    _characterId = initial?.characterId ?? '';
    _profile = initial?.profile ?? const CharacterProfile();
    _mindModelCard = initial?.mindModelCard ?? const MindModelCard();
    _baselineBodyProfile = initial?.baselineBodyProfile ??
        BaselineBodyProfile(
          species: '',
          sensoryBaseline: const SensoryBaseline(
            vision: 1.0,
            hearing: 1.0,
            smell: 1.0,
            touch: 1.0,
            proprioception: 1.0,
          ),
          motorBaseline: const MotorBaseline(
            mobility: 1.0,
            balance: 1.0,
            stamina: 1.0,
          ),
          cognitionBaseline: const CognitionBaseline(
            stressTolerance: 1.0,
            sensoryOverloadTolerance: 1.0,
          ),
          manaSensoryBaseline: const ManaSensoryBaseline(),
        );
    _emotionState = initial?.emotionState ?? const EmotionState();
    _beliefState = initial?.beliefState ?? const BeliefState();
    _currentGoals = initial?.currentGoals ?? const CurrentGoals();

    _initialCharacterId = initial?.characterId;
    _initialProfile = initial?.profile;
    _initialMindModelCard = initial?.mindModelCard;
    _initialBaselineBodyProfile = initial?.baselineBodyProfile;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = Theme.of(context).extension<AppUiTheme>() ?? AppUiTheme.fallback(brightness: Brightness.dark);
    return PopScope<CharacterRuntimeState>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldClose = await _confirmDiscard();
        if (!mounted || !shouldClose) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final shouldClose = await _confirmDiscard();
              if (!mounted || !shouldClose) return;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Agent 角色编辑'),
          bottom: TabBar(
            controller: _tabController,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ui.textStrong,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ui.textSecondary,
            ),
            labelColor: ui.textStrong,
            unselectedLabelColor: ui.textSecondary,
            indicatorColor: ui.primary,
            indicatorWeight: 2,
            dividerColor: ui.border,
            tabs: const [
              Tab(text: '基本信息'),
              Tab(text: '心智模型'),
              Tab(text: '身体配置'),
              Tab(text: '初始状态'),
            ],
          ),
          actions: [
            TextButton(onPressed: _save, child: const Text('保存')),
            const SizedBox(width: 4),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _BasicInfoTab(
              characterId: _characterId,
              profile: _profile,
              onCharacterIdChanged: (v) => setState(() => _characterId = v),
              onProfileChanged: (v) => setState(() => _profile = v),
            ),
            _MindModelTab(
              mindModelCard: _mindModelCard,
              onChanged: (v) => setState(() => _mindModelCard = v),
            ),
            _BodyProfileTab(
              baselineBodyProfile: _baselineBodyProfile,
              onChanged: (v) => setState(() => _baselineBodyProfile = v),
            ),
            _InitialStateTab(
              emotionState: _emotionState,
              beliefState: _beliefState,
              currentGoals: _currentGoals,
              onEmotionStateChanged: (v) => setState(() => _emotionState = v),
              onBeliefStateChanged: (v) => setState(() => _beliefState = v),
              onCurrentGoalsChanged: (v) => setState(() => _currentGoals = v),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final id = _characterId.trim();
    if (id.isEmpty) {
      _showError('角色ID不能为空');
      return;
    }

    final state = CharacterRuntimeState(
      characterId: id,
      profile: _profile,
      mindModelCard: _mindModelCard,
      beliefState: _beliefState,
      emotionState: _emotionState,
      baselineBodyProfile: _baselineBodyProfile,
      temporaryBodyState: TemporaryBodyState(
        sensoryBlocks: const SensoryBlocks(),
      ),
      currentGoals: _currentGoals,
    );

    if (widget.onSave != null) {
      widget.onSave!(state);
    }
    Navigator.of(context).pop(state);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty()) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了内容，现在返回会丢失本次填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  bool _isDirty() {
    return _characterId != (_initialCharacterId ?? '') ||
        _profile != (_initialProfile ?? const CharacterProfile()) ||
        _mindModelCard != (_initialMindModelCard ?? const MindModelCard()) ||
        _baselineBodyProfile !=
            (_initialBaselineBodyProfile ??
                BaselineBodyProfile(
                  species: '',
                  sensoryBaseline: const SensoryBaseline(
                    vision: 1.0,
                    hearing: 1.0,
                    smell: 1.0,
                    touch: 1.0,
                    proprioception: 1.0,
                  ),
                  motorBaseline: const MotorBaseline(
                    mobility: 1.0,
                    balance: 1.0,
                    stamina: 1.0,
                  ),
                  cognitionBaseline: const CognitionBaseline(
                    stressTolerance: 1.0,
                    sensoryOverloadTolerance: 1.0,
                  ),
                  manaSensoryBaseline: const ManaSensoryBaseline(),
                ));
  }
}

class _BasicInfoTab extends StatefulWidget {
  const _BasicInfoTab({
    required this.characterId,
    required this.profile,
    required this.onCharacterIdChanged,
    required this.onProfileChanged,
  });

  final String characterId;
  final CharacterProfile profile;
  final ValueChanged<String> onCharacterIdChanged;
  final ValueChanged<CharacterProfile> onProfileChanged;

  @override
  State<_BasicInfoTab> createState() => _BasicInfoTabState();
}

class _BasicInfoTabState extends State<_BasicInfoTab> {
  late final TextEditingController _characterIdController;
  late final TextEditingController _cognitiveStyleController;
  late final TextEditingController _socialStyleController;
  late List<String> _traits;
  late List<String> _values;

  @override
  void initState() {
    super.initState();
    _characterIdController =
        TextEditingController(text: widget.characterId);
    _cognitiveStyleController =
        TextEditingController(text: widget.profile.cognitiveStyle);
    _socialStyleController =
        TextEditingController(text: widget.profile.socialStyle);
    _traits = List.from(widget.profile.traits);
    _values = List.from(widget.profile.values);
  }

  @override
  void dispose() {
    _characterIdController.dispose();
    _cognitiveStyleController.dispose();
    _socialStyleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('角色标识', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _characterIdController,
                decoration: const InputDecoration(
                  labelText: '角色ID',
                  hintText: '唯一标识符，如 alice、fox_spirit',
                ),
                onChanged: widget.onCharacterIdChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('性格特征', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _traits,
                hintText: '添加性格特征，如：谨慎、多疑、重情义',
                onChanged: (items) {
                  setState(() => _traits = items);
                  _emitProfileChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('核心价值观', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _values,
                hintText: '添加核心价值观，如：自由、真相、守护',
                onChanged: (items) {
                  setState(() => _values = items);
                  _emitProfileChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('认知风格', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _cognitiveStyleController,
                decoration: const InputDecoration(
                  labelText: '认知风格',
                  hintText: '如：善于分析、直觉型、谨慎推理',
                ),
                maxLines: 2,
                onChanged: (_) => _emitProfileChange(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _socialStyleController,
                decoration: const InputDecoration(
                  labelText: '社交风格',
                  hintText: '如：外向、内敛、善于察言观色',
                ),
                maxLines: 2,
                onChanged: (_) => _emitProfileChange(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _emitProfileChange() {
    widget.onProfileChanged(CharacterProfile(
      traits: _traits,
      values: _values,
      cognitiveStyle: _cognitiveStyleController.text,
      socialStyle: _socialStyleController.text,
    ));
  }
}

class _MindModelTab extends StatefulWidget {
  const _MindModelTab({
    required this.mindModelCard,
    required this.onChanged,
  });

  final MindModelCard mindModelCard;
  final ValueChanged<MindModelCard> onChanged;

  @override
  State<_MindModelTab> createState() => _MindModelTabState();
}

class _MindModelTabState extends State<_MindModelTab> {
  late final TextEditingController _selfImageController;
  late List<String> _worldview;
  late List<String> _socialLogic;
  late List<String> _fearTriggers;
  late List<String> _defensePatterns;
  late List<String> _desirePatterns;

  @override
  void initState() {
    super.initState();
    _selfImageController =
        TextEditingController(text: widget.mindModelCard.selfImage);
    _worldview = List.from(widget.mindModelCard.worldview);
    _socialLogic = List.from(widget.mindModelCard.socialLogic);
    _fearTriggers = List.from(widget.mindModelCard.fearTriggers);
    _defensePatterns = List.from(widget.mindModelCard.defensePatterns);
    _desirePatterns = List.from(widget.mindModelCard.desirePatterns);
  }

  @override
  void dispose() {
    _selfImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('自我形象', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _selfImageController,
                decoration: const InputDecoration(
                  labelText: '自我认知',
                  hintText: '角色如何看待自己',
                ),
                maxLines: 3,
                onChanged: (_) => _emitChange(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('世界观', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _worldview,
                hintText: '添加世界观信念',
                onChanged: (items) {
                  setState(() => _worldview = items);
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('社交逻辑', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _socialLogic,
                hintText: '添加社交规则，如：信任需要时间建立',
                onChanged: (items) {
                  setState(() => _socialLogic = items);
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('恐惧触发', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _fearTriggers,
                hintText: '添加恐惧触发条件',
                onChanged: (items) {
                  setState(() => _fearTriggers = items);
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('防御模式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _defensePatterns,
                hintText: '添加心理防御机制',
                onChanged: (items) {
                  setState(() => _defensePatterns = items);
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('欲望模式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _desirePatterns,
                hintText: '添加内在欲望驱动',
                onChanged: (items) {
                  setState(() => _desirePatterns = items);
                  _emitChange();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _emitChange() {
    widget.onChanged(MindModelCard(
      selfImage: _selfImageController.text,
      worldview: _worldview,
      socialLogic: _socialLogic,
      fearTriggers: _fearTriggers,
      defensePatterns: _defensePatterns,
      desirePatterns: _desirePatterns,
    ));
  }
}

class _BodyProfileTab extends StatefulWidget {
  const _BodyProfileTab({
    required this.baselineBodyProfile,
    required this.onChanged,
  });

  final BaselineBodyProfile baselineBodyProfile;
  final ValueChanged<BaselineBodyProfile> onChanged;

  @override
  State<_BodyProfileTab> createState() => _BodyProfileTabState();
}

class _BodyProfileTabState extends State<_BodyProfileTab> {
  late final TextEditingController _speciesController;
  late SensoryBaseline _sensoryBaseline;
  late MotorBaseline _motorBaseline;
  late CognitionBaseline _cognitionBaseline;
  late ManaSensoryBaseline _manaSensoryBaseline;
  late List<String> _specialTraits;
  late List<String> _vulnerabilities;

  @override
  void initState() {
    super.initState();
    _speciesController =
        TextEditingController(text: widget.baselineBodyProfile.species);
    _sensoryBaseline = widget.baselineBodyProfile.sensoryBaseline;
    _motorBaseline = widget.baselineBodyProfile.motorBaseline;
    _cognitionBaseline = widget.baselineBodyProfile.cognitionBaseline;
    _manaSensoryBaseline = widget.baselineBodyProfile.manaSensoryBaseline;
    _specialTraits = List.from(widget.baselineBodyProfile.specialTraits);
    _vulnerabilities = List.from(widget.baselineBodyProfile.vulnerabilities);
  }

  @override
  void dispose() {
    _speciesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('物种', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _speciesController,
                decoration: const InputDecoration(
                  labelText: '物种类型',
                  hintText: '如：人类、狐妖、剑灵',
                ),
                onChanged: (_) => _emitChange(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('感官基线', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SliderField(
                label: '视觉',
                value: _sensoryBaseline.vision,
                onChanged: (v) {
                  setState(() {
                    _sensoryBaseline = _sensoryBaseline.copyWith(vision: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '听觉',
                value: _sensoryBaseline.hearing,
                onChanged: (v) {
                  setState(() {
                    _sensoryBaseline = _sensoryBaseline.copyWith(hearing: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '嗅觉',
                value: _sensoryBaseline.smell,
                onChanged: (v) {
                  setState(() {
                    _sensoryBaseline = _sensoryBaseline.copyWith(smell: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '触觉',
                value: _sensoryBaseline.touch,
                onChanged: (v) {
                  setState(() {
                    _sensoryBaseline = _sensoryBaseline.copyWith(touch: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '本体感觉',
                value: _sensoryBaseline.proprioception,
                onChanged: (v) {
                  setState(() {
                    _sensoryBaseline =
                        _sensoryBaseline.copyWith(proprioception: v);
                  });
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('运动基线', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SliderField(
                label: '机动性',
                value: _motorBaseline.mobility,
                onChanged: (v) {
                  setState(() {
                    _motorBaseline = _motorBaseline.copyWith(mobility: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '平衡',
                value: _motorBaseline.balance,
                onChanged: (v) {
                  setState(() {
                    _motorBaseline = _motorBaseline.copyWith(balance: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '耐力',
                value: _motorBaseline.stamina,
                onChanged: (v) {
                  setState(() {
                    _motorBaseline = _motorBaseline.copyWith(stamina: v);
                  });
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('认知基线', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SliderField(
                label: '压力耐受',
                value: _cognitionBaseline.stressTolerance,
                onChanged: (v) {
                  setState(() {
                    _cognitionBaseline =
                        _cognitionBaseline.copyWith(stressTolerance: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '感官过载耐受',
                value: _cognitionBaseline.sensoryOverloadTolerance,
                onChanged: (v) {
                  setState(() {
                    _cognitionBaseline = _cognitionBaseline.copyWith(
                        sensoryOverloadTolerance: v);
                  });
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('灵觉配置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SliderField(
                label: '基础敏锐度',
                value: _manaSensoryBaseline.baseAcuity,
                min: 0,
                max: 5,
                onChanged: (v) {
                  setState(() {
                    _manaSensoryBaseline =
                        _manaSensoryBaseline.copyWith(baseAcuity: v);
                  });
                  _emitChange();
                },
              ),
              _SliderField(
                label: '境界修正',
                value: _manaSensoryBaseline.realmModifier,
                min: 0,
                max: 5,
                onChanged: (v) {
                  setState(() {
                    _manaSensoryBaseline =
                        _manaSensoryBaseline.copyWith(realmModifier: v);
                  });
                  _emitChange();
                },
              ),
              const SizedBox(height: 8),
              Text('灵觉特性',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ManaSenseTrait.values.map((trait) {
                  final selected =
                      _manaSensoryBaseline.traits.contains(trait);
                  return FilterChip(
                    label: Text(trait.label),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        final traits =
                            _manaSensoryBaseline.traits.toList();
                        if (v) {
                          traits.add(trait);
                        } else {
                          traits.remove(trait);
                        }
                        _manaSensoryBaseline =
                            _manaSensoryBaseline.copyWith(traits: traits);
                      });
                      _emitChange();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('特殊特质', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _specialTraits,
                hintText: '添加特殊特质',
                onChanged: (items) {
                  setState(() => _specialTraits = items);
                  _emitChange();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('弱点', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StringListEditor(
                items: _vulnerabilities,
                hintText: '添加弱点',
                onChanged: (items) {
                  setState(() => _vulnerabilities = items);
                  _emitChange();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _emitChange() {
    widget.onChanged(BaselineBodyProfile(
      species: _speciesController.text,
      sensoryBaseline: _sensoryBaseline,
      motorBaseline: _motorBaseline,
      cognitionBaseline: _cognitionBaseline,
      manaSensoryBaseline: _manaSensoryBaseline,
      specialTraits: _specialTraits,
      vulnerabilities: _vulnerabilities,
    ));
  }
}

class _InitialStateTab extends StatefulWidget {
  const _InitialStateTab({
    required this.emotionState,
    required this.beliefState,
    required this.currentGoals,
    required this.onEmotionStateChanged,
    required this.onBeliefStateChanged,
    required this.onCurrentGoalsChanged,
  });

  final EmotionState emotionState;
  final BeliefState beliefState;
  final CurrentGoals currentGoals;
  final ValueChanged<EmotionState> onEmotionStateChanged;
  final ValueChanged<BeliefState> onBeliefStateChanged;
  final ValueChanged<CurrentGoals> onCurrentGoalsChanged;

  @override
  State<_InitialStateTab> createState() => _InitialStateTabState();
}

class _InitialStateTabState extends State<_InitialStateTab> {
  late Map<String, double> _emotions;
  late Map<String, double> _beliefConfidences;
  late List<String> _activeHypotheses;
  late List<String> _shortTermGoals;
  late List<String> _mediumTermGoals;
  late List<String> _hiddenGoals;

  @override
  void initState() {
    super.initState();
    _emotions = Map.from(widget.emotionState.emotions);
    _beliefConfidences = Map.from(widget.beliefState.beliefConfidences);
    _activeHypotheses = List.from(widget.beliefState.activeHypotheses);
    _shortTermGoals = List.from(widget.currentGoals.shortTerm);
    _mediumTermGoals = List.from(widget.currentGoals.mediumTerm);
    _hiddenGoals = List.from(widget.currentGoals.hidden);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('初始情绪', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _EmotionEditor(
                emotions: _emotions,
                onChanged: (v) {
                  setState(() => _emotions = v);
                  widget.onEmotionStateChanged(EmotionState(emotions: v));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('初始信念', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _BeliefEditor(
                confidences: _beliefConfidences,
                hypotheses: _activeHypotheses,
                onChanged: (confidences, hypotheses) {
                  setState(() {
                    _beliefConfidences = confidences;
                    _activeHypotheses = hypotheses;
                  });
                  widget.onBeliefStateChanged(BeliefState(
                    beliefConfidences: confidences,
                    activeHypotheses: hypotheses,
                  ));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('初始目标', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('短期目标',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              _StringListEditor(
                items: _shortTermGoals,
                hintText: '添加短期目标',
                onChanged: (items) {
                  setState(() => _shortTermGoals = items);
                  _emitGoalsChange();
                },
              ),
              const SizedBox(height: 12),
              Text('中期目标',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              _StringListEditor(
                items: _mediumTermGoals,
                hintText: '添加中期目标',
                onChanged: (items) {
                  setState(() => _mediumTermGoals = items);
                  _emitGoalsChange();
                },
              ),
              const SizedBox(height: 12),
              Text('隐藏目标',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              _StringListEditor(
                items: _hiddenGoals,
                hintText: '添加隐藏目标',
                onChanged: (items) {
                  setState(() => _hiddenGoals = items);
                  _emitGoalsChange();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _emitGoalsChange() {
    widget.onCurrentGoalsChanged(CurrentGoals(
      shortTerm: _shortTermGoals,
      mediumTerm: _mediumTermGoals,
      hidden: _hiddenGoals,
    ));
  }
}

class _StringListEditor extends StatefulWidget {
  const _StringListEditor({
    required this.items,
    required this.hintText,
    required this.onChanged,
  });

  final List<String> items;
  final String hintText;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<_StringListEditor> {
  late List<String> _items;
  late final TextEditingController _newItemController;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _newItemController = TextEditingController();
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Chip(
              label: Text(item),
              onDeleted: () {
                setState(() {
                  _items.removeAt(index);
                });
                widget.onChanged(_items);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newItemController,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  isDense: true,
                ),
                onSubmitted: _addItem,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addItem(_newItemController.text),
            ),
          ],
        ),
      ],
    );
  }

  void _addItem(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _items.add(trimmed);
      _newItemController.clear();
    });
    widget.onChanged(_items);
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 2,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 50, child: Text(value.toStringAsFixed(2))),
      ],
    );
  }
}

class _EmotionEditor extends StatefulWidget {
  const _EmotionEditor({
    required this.emotions,
    required this.onChanged,
  });

  final Map<String, double> emotions;
  final ValueChanged<Map<String, double>> onChanged;

  @override
  State<_EmotionEditor> createState() => _EmotionEditorState();
}

class _EmotionEditorState extends State<_EmotionEditor> {
  late Map<String, double> _emotions;
  late final TextEditingController _nameController;

  static const _presetEmotions = [
    'fear', 'anger', 'joy', 'sadness', 'surprise', 'disgust', 'trust', 'anticipation'
  ];

  @override
  void initState() {
    super.initState();
    _emotions = Map.from(widget.emotions);
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetEmotions.map((name) {
            final value = _emotions[name] ?? 0.0;
            return GestureDetector(
              onTap: () => _showSliderDialog(name, value),
              child: Chip(
                label: Text('$name: ${value.toStringAsFixed(2)}'),
                backgroundColor: value > 0.5 ? AppColors.accentSecondary.withValues(alpha: 0.3) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: '自定义情绪名称',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addCustomEmotion,
            ),
          ],
        ),
      ],
    );
  }

  void _addCustomEmotion() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _emotions[name] = 0.5;
      _nameController.clear();
    });
    widget.onChanged(_emotions);
  }

  void _showSliderDialog(String name, double currentValue) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置 $name'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: currentValue,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) {
                    currentValue = v;
                    setState(() {});
                  },
                ),
                Text(currentValue.toStringAsFixed(2)),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _emotions[name] = currentValue;
              });
              widget.onChanged(_emotions);
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _BeliefEditor extends StatefulWidget {
  const _BeliefEditor({
    required this.confidences,
    required this.hypotheses,
    required this.onChanged,
  });

  final Map<String, double> confidences;
  final List<String> hypotheses;
  final void Function(Map<String, double>, List<String>) onChanged;

  @override
  State<_BeliefEditor> createState() => _BeliefEditorState();
}

class _BeliefEditorState extends State<_BeliefEditor> {
  late Map<String, double> _confidences;
  late List<String> _hypotheses;
  late final TextEditingController _beliefController;
  late final TextEditingController _hypothesisController;

  @override
  void initState() {
    super.initState();
    _confidences = Map.from(widget.confidences);
    _hypotheses = List.from(widget.hypotheses);
    _beliefController = TextEditingController();
    _hypothesisController = TextEditingController();
  }

  @override
  void dispose() {
    _beliefController.dispose();
    _hypothesisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('信念置信度', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _confidences.entries.map((entry) {
            return GestureDetector(
              onTap: () => _showBeliefDialog(entry.key, entry.value),
              child: Chip(
                label: Text('${entry.key}: ${entry.value.toStringAsFixed(2)}'),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _beliefController,
                decoration: const InputDecoration(
                  hintText: '添加信念',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addBelief,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('活跃假设', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        _StringListEditor(
          items: _hypotheses,
          hintText: '添加假设',
          onChanged: (items) {
            setState(() => _hypotheses = items);
            widget.onChanged(_confidences, _hypotheses);
          },
        ),
      ],
    );
  }

  void _addBelief() {
    final name = _beliefController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _confidences[name] = 0.5;
      _beliefController.clear();
    });
    widget.onChanged(_confidences, _hypotheses);
  }

  void _showBeliefDialog(String name, double currentValue) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置信念: $name'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: currentValue,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) {
                    currentValue = v;
                    setState(() {});
                  },
                ),
                Text(currentValue.toStringAsFixed(2)),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _confidences.remove(name);
              });
              widget.onChanged(_confidences, _hypotheses);
              Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _confidences[name] = currentValue;
              });
              widget.onChanged(_confidences, _hypotheses);
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
