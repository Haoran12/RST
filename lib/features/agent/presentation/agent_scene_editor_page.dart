import 'package:flutter/material.dart';

import '../../../core/models/agent/scene_model.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/theme_tokens.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class AgentSceneEditorPage extends StatefulWidget {
  const AgentSceneEditorPage({
    super.key,
    this.initialScene,
    this.onSave,
  });

  final SceneModel? initialScene;
  final void Function(SceneModel scene)? onSave;

  @override
  State<AgentSceneEditorPage> createState() => AgentSceneEditorPageState();
}

class AgentSceneEditorPageState extends State<AgentSceneEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late String _sceneId;
  late TimeContext _timeContext;
  late SpatialLayout _spatialLayout;
  late LightingState _lighting;
  late AcousticsState _acoustics;
  late OlfactoryField _olfactoryField;
  late List<SceneEntity> _entities;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final initial = widget.initialScene;
    _sceneId = initial?.sceneId ?? '';
    _timeContext = initial?.timeContext ?? const TimeContext(
      timeOfDay: '',
      weather: '',
      visibilityCondition: '',
    );
    _spatialLayout = initial?.spatialLayout ?? SpatialLayout(
      sceneType: SceneType.unknown,
      dimensionsEstimate: '',
    );
    _lighting = initial?.lighting ?? const LightingState(
      overallLevel: LightingLevel.normal,
    );
    _acoustics = initial?.acoustics ?? const AcousticsState(
      ambientNoiseLevel: 0.5,
      reflectiveQuality: ReflectiveQuality.open,
    );
    _olfactoryField = initial?.olfactoryField ?? OlfactoryField(
      overallDensity: 0.5,
      airflow: const Airflow(
        strength: AirflowStrength.still,
        direction: '',
      ),
    );
    _entities = initial?.entities.toList() ?? [];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = Theme.of(context).extension<AppUiTheme>() ?? AppUiTheme.fallback(brightness: Brightness.dark);
    return PopScope<SceneModel>(
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
          title: const Text('Agent 场景编辑'),
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
              Tab(text: '空间布局'),
              Tab(text: '环境状态'),
              Tab(text: '场景实体'),
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
              sceneId: _sceneId,
              timeContext: _timeContext,
              onSceneIdChanged: (v) => setState(() => _sceneId = v),
              onTimeContextChanged: (v) => setState(() => _timeContext = v),
            ),
            _SpatialLayoutTab(
              spatialLayout: _spatialLayout,
              onChanged: (v) => setState(() => _spatialLayout = v),
            ),
            _EnvironmentTab(
              lighting: _lighting,
              acoustics: _acoustics,
              olfactoryField: _olfactoryField,
              onLightingChanged: (v) => setState(() => _lighting = v),
              onAcousticsChanged: (v) => setState(() => _acoustics = v),
              onOlfactoryChanged: (v) => setState(() => _olfactoryField = v),
            ),
            _EntitiesTab(
              entities: _entities,
              onChanged: (v) => setState(() => _entities = v),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final id = _sceneId.trim();
    if (id.isEmpty) {
      _showError('场景ID不能为空');
      return;
    }

    final scene = SceneModel(
      sceneId: id,
      sceneTurnId: 'turn_0',
      timeContext: _timeContext,
      spatialLayout: _spatialLayout,
      lighting: _lighting,
      acoustics: _acoustics,
      olfactoryField: _olfactoryField,
      entities: _entities,
    );

    if (widget.onSave != null) {
      widget.onSave!(scene);
    }
    Navigator.of(context).pop(scene);
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
}

class _BasicInfoTab extends StatefulWidget {
  const _BasicInfoTab({
    required this.sceneId,
    required this.timeContext,
    required this.onSceneIdChanged,
    required this.onTimeContextChanged,
  });

  final String sceneId;
  final TimeContext timeContext;
  final ValueChanged<String> onSceneIdChanged;
  final ValueChanged<TimeContext> onTimeContextChanged;

  @override
  State<_BasicInfoTab> createState() => _BasicInfoTabState();
}

class _BasicInfoTabState extends State<_BasicInfoTab> {
  late final TextEditingController _sceneIdController;
  late final TextEditingController _timeOfDayController;
  late final TextEditingController _weatherController;
  late final TextEditingController _visibilityController;

  @override
  void initState() {
    super.initState();
    _sceneIdController = TextEditingController(text: widget.sceneId);
    _timeOfDayController =
        TextEditingController(text: widget.timeContext.timeOfDay);
    _weatherController =
        TextEditingController(text: widget.timeContext.weather);
    _visibilityController =
        TextEditingController(text: widget.timeContext.visibilityCondition);
  }

  @override
  void dispose() {
    _sceneIdController.dispose();
    _timeOfDayController.dispose();
    _weatherController.dispose();
    _visibilityController.dispose();
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
              Text('场景标识', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _sceneIdController,
                decoration: const InputDecoration(
                  labelText: '场景ID',
                  hintText: '唯一标识符',
                ),
                onChanged: widget.onSceneIdChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('时间上下文', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _timeOfDayController,
                decoration: const InputDecoration(
                  labelText: '时间',
                  hintText: '如：黄昏、深夜、清晨',
                ),
                onChanged: (_) => _emitChange(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _weatherController,
                decoration: const InputDecoration(
                  labelText: '天气',
                  hintText: '如：晴朗、阴雨、大风',
                ),
                onChanged: (_) => _emitChange(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _visibilityController,
                decoration: const InputDecoration(
                  labelText: '能见度条件',
                  hintText: '如：良好、雾气弥漫',
                ),
                onChanged: (_) => _emitChange(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _emitChange() {
    widget.onTimeContextChanged(TimeContext(
      timeOfDay: _timeOfDayController.text,
      weather: _weatherController.text,
      visibilityCondition: _visibilityController.text,
    ));
  }
}

class _SpatialLayoutTab extends StatefulWidget {
  const _SpatialLayoutTab({
    required this.spatialLayout,
    required this.onChanged,
  });

  final SpatialLayout spatialLayout;
  final ValueChanged<SpatialLayout> onChanged;

  @override
  State<_SpatialLayoutTab> createState() => _SpatialLayoutTabState();
}

class _SpatialLayoutTabState extends State<_SpatialLayoutTab> {
  late SceneType _sceneType;
  late final TextEditingController _dimensionsController;

  @override
  void initState() {
    super.initState();
    _sceneType = widget.spatialLayout.sceneType;
    _dimensionsController =
        TextEditingController(text: widget.spatialLayout.dimensionsEstimate);
  }

  @override
  void dispose() {
    _dimensionsController.dispose();
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
              Text('场景类型', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SceneType.values.where((t) => t != SceneType.unknown).map((type) {
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: _sceneType == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _sceneType = type);
                        _emitChange();
                      }
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
              Text('空间尺寸', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _dimensionsController,
                decoration: const InputDecoration(
                  labelText: '尺寸估计',
                  hintText: '如：约十步见方、长条形走廊',
                ),
                maxLines: 2,
                onChanged: (_) => _emitChange(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _emitChange() {
    widget.onChanged(SpatialLayout(
      sceneType: _sceneType,
      dimensionsEstimate: _dimensionsController.text,
    ));
  }
}

class _EnvironmentTab extends StatefulWidget {
  const _EnvironmentTab({
    required this.lighting,
    required this.acoustics,
    required this.olfactoryField,
    required this.onLightingChanged,
    required this.onAcousticsChanged,
    required this.onOlfactoryChanged,
  });

  final LightingState lighting;
  final AcousticsState acoustics;
  final OlfactoryField olfactoryField;
  final ValueChanged<LightingState> onLightingChanged;
  final ValueChanged<AcousticsState> onAcousticsChanged;
  final ValueChanged<OlfactoryField> onOlfactoryChanged;

  @override
  State<_EnvironmentTab> createState() => _EnvironmentTabState();
}

class _EnvironmentTabState extends State<_EnvironmentTab> {
  late LightingLevel _lightingLevel;
  late double _ambientNoiseLevel;
  late ReflectiveQuality _reflectiveQuality;
  late double _olfactoryDensity;
  late AirflowStrength _airflowStrength;

  @override
  void initState() {
    super.initState();
    _lightingLevel = widget.lighting.overallLevel;
    _ambientNoiseLevel = widget.acoustics.ambientNoiseLevel;
    _reflectiveQuality = widget.acoustics.reflectiveQuality;
    _olfactoryDensity = widget.olfactoryField.overallDensity;
    _airflowStrength = widget.olfactoryField.airflow.strength;
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
              Text('光照状态', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LightingLevel.values.map((level) {
                  return ChoiceChip(
                    label: Text(level.label),
                    selected: _lightingLevel == level,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _lightingLevel = level);
                        widget.onLightingChanged(
                            widget.lighting.copyWith(overallLevel: level));
                      }
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
              Text('声学状态', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SliderField(
                label: '环境噪音',
                value: _ambientNoiseLevel,
                onChanged: (v) {
                  setState(() => _ambientNoiseLevel = v);
                  widget.onAcousticsChanged(
                      widget.acoustics.copyWith(ambientNoiseLevel: v));
                },
              ),
              const SizedBox(height: 8),
              Text('反射质量', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReflectiveQuality.values.map((quality) {
                  return ChoiceChip(
                    label: Text(quality.label),
                    selected: _reflectiveQuality == quality,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _reflectiveQuality = quality);
                        widget.onAcousticsChanged(
                            widget.acoustics.copyWith(reflectiveQuality: quality));
                      }
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
              Text('嗅觉场', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SliderField(
                label: '气味密度',
                value: _olfactoryDensity,
                onChanged: (v) {
                  setState(() => _olfactoryDensity = v);
                  widget.onOlfactoryChanged(widget.olfactoryField.copyWith(
                      overallDensity: v,
                      airflow: widget.olfactoryField.airflow));
                },
              ),
              const SizedBox(height: 8),
              Text('气流强度', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AirflowStrength.values.map((strength) {
                  return ChoiceChip(
                    label: Text(strength.label),
                    selected: _airflowStrength == strength,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _airflowStrength = strength);
                        widget.onOlfactoryChanged(widget.olfactoryField.copyWith(
                            airflow: Airflow(
                                strength: strength,
                                direction: widget.olfactoryField.airflow.direction)));
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntitiesTab extends StatefulWidget {
  const _EntitiesTab({
    required this.entities,
    required this.onChanged,
  });

  final List<SceneEntity> entities;
  final ValueChanged<List<SceneEntity>> onChanged;

  @override
  State<_EntitiesTab> createState() => _EntitiesTabState();
}

class _EntitiesTabState extends State<_EntitiesTab> {
  late List<SceneEntity> _entities;

  @override
  void initState() {
    super.initState();
    _entities = widget.entities.toList();
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
              Row(
                children: [
                  Text('场景实体', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addEntity,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_entities.isEmpty)
                const Text('暂无实体，点击右上角添加')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _entities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entity = _entities[index];
                    return ListTile(
                      title: Text(entity.entityId),
                      subtitle: Text('${entity.type} · ${entity.location}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeEntity(index),
                      ),
                      onTap: () => _editEntity(index),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _addEntity() async {
    final entity = await _showEntityDialog(null);
    if (entity != null) {
      setState(() => _entities.add(entity));
      widget.onChanged(_entities);
    }
  }

  void _editEntity(int index) async {
    final entity = await _showEntityDialog(_entities[index]);
    if (entity != null) {
      setState(() => _entities[index] = entity);
      widget.onChanged(_entities);
    }
  }

  void _removeEntity(int index) {
    setState(() => _entities.removeAt(index));
    widget.onChanged(_entities);
  }

  Future<SceneEntity?> _showEntityDialog(SceneEntity? existing) async {
    final idController = TextEditingController(text: existing?.entityId ?? '');
    final typeController = TextEditingController(text: existing?.type ?? '');
    final locationController =
        TextEditingController(text: existing?.location ?? '');
    final stateController = TextEditingController(text: existing?.state ?? '');

    return showDialog<SceneEntity>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? '添加实体' : '编辑实体'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: '实体ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(labelText: '类型'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: '位置'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: stateController,
              decoration: const InputDecoration(labelText: '状态'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(SceneEntity(
                entityId: idController.text,
                type: typeController.text,
                location: locationController.text,
                state: stateController.text,
              ));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 50, child: Text(value.toStringAsFixed(2))),
      ],
    );
  }
}
