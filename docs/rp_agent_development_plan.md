# RP Agent 开发方案

Version: 0.1
Status: Draft
Audience: Backend / Runtime / Architecture

---

## 一、项目现状分析

### 1.1 技术栈

- **前端框架**: Flutter + Riverpod 状态管理
- **后端**: Rust (flutter_rust_bridge)
- **LLM 调用**: 多 Provider 支持 (OpenAI/Anthropic/Gemini/DeepSeek/OpenRouter)
- **已有定义**: `SchedulerMode.agent` 枚举已预留

### 1.2 现有架构

- `ChatService` 处理 ST/RST 模式的对话
- `PresetBuiltinEntryKeys` 定义 prompt 条目顺序
- `RustBridge` 负责消息/会话持久化

### 1.3 文档依赖

本方案基于 `docs/` 目录下的 rp_agent 系列文档：
- `rp_agent_framework_spec.md` - 架构与设计哲学
- `rp_agent_runtime_protocol_spec.md` - 数据契约与模块接口
- `rp_agent_runtime_execution_strategy.md` - 执行策略与优化
- `rp_agent_skill_system_spec.md` - 技能系统
- `rp_agent_persistence_validation_spec.md` - 持久化与验证
- `rp_agent_filtering_example.md` - 具体示例

---

## 二、模块划分与实现顺序

```
Phase 1: 数据模型层 (2-3周)
├── Scene Model
├── Character Runtime State
├── Embodiment State
├── Memory Entry
└── Skill Model

Phase 2: 程序化核心 (3-4周)
├── SceneStateExtractor
├── EmbodimentResolver
├── Scene Filtering Protocol
├── Memory Access Protocol
└── Character Input Assembly

Phase 3: 认知层 (2-3周)
├── CharacterCognitivePass (融合调用)
├── BeliefUpdater
└── IntentAgent

Phase 4: 表现层 (1-2周)
├── SurfaceRealizer
├── Action Arbitration
└── State Committer

Phase 5: 验证与监控 (1-2周)
├── Validation Rules
├── Dirty Flags & Active Set
└── Trace Logging
```

---

## 三、数据模型设计

### 3.1 Scene Model

```dart
// lib/core/models/agent/scene_model.dart

class SceneModel {
  final String sceneId;
  final String sceneTurnId;
  final TimeContext timeContext;
  final SpatialLayout spatialLayout;
  final LightingState lighting;
  final AcousticsState acoustics;
  final OlfactoryField olfactoryField;
  final ManaField manaField;
  final List<SceneEntity> entities;
  final List<ObservableSignal> observableSignals;
  final List<SceneEvent> eventStream;
  final List<ObservabilityConstraint> observabilityConstraints;
  final List<String> uncertaintyNotes;
}

class TimeContext {
  final String timeOfDay;
  final String weather;
  final String visibilityCondition;
  final List<String> ambientContextNotes;
}

class SpatialLayout {
  final SceneType sceneType;
  final String dimensionsEstimate;
  final List<SubArea> subareas;
  final List<Obstacle> obstacles;
  final List<EntryPoint> entryPoints;
}

enum SceneType {
  room, street, forest, courtyard, cave, hallway, unknown
}

class Obstacle {
  final String id;
  final ObstacleType type;
  final String location;
  final bool blocksVision;
  final bool blocksSound;
  final bool blocksSmell;
  final bool blocksMovement;
}

enum ObstacleType {
  wall, screen, table, curtain, tree, crowd, furniture, terrain
}

class LightingState {
  final LightingLevel overallLevel;
  final List<LightSource> sourcePoints;
  final List<ShadowZone> shadowZones;
  final List<BacklightZone> backlightZones;
  final double flicker;
  final List<String> visualNoise;
}

enum LightingLevel {
  bright, normal, dim, veryDim, dark
}

class AcousticsState {
  final double ambientNoiseLevel;
  final List<AmbientSoundSource> ambientSources;
  final ReflectiveQuality reflectiveQuality;
}

enum ReflectiveQuality {
  open, muffled, echoing, enclosed, mixed
}

class OlfactoryField {
  final double overallDensity;
  final Airflow airflow;
  final List<OdorSource> odorSources;
  final List<String> interferingOdors;
}

class Airflow {
  final AirflowStrength strength;
  final String direction;
}

enum AirflowStrength {
  still, weak, flowing, gusty, variable
}

class OdorSource {
  final String id;
  final OdorType type;
  final double intensity;
  final OdorFreshness freshness;
  final double spreadRange;
  final String sourcePosition;
}

enum OdorType {
  blood, medicine, incense, rot, soil, alcohol,
  sweat, flower, smoke, metal, unknown
}

enum OdorFreshness {
  fresh, recent, old, unknown
}
```

### 3.2 Mana Field (灵力场)

```dart
// lib/core/models/agent/mana_field.dart

/// 灵力场状态
class ManaField {
  /// 整体灵气浓度 (0.0-1.0)
  final double ambientDensity;

  /// 灵气属性
  final ManaAttribute ambientAttribute;

  /// 灵力源点
  final List<ManaSource> manaSources;

  /// 灵力流动
  final ManaFlow flow;

  /// 灵力干扰/屏蔽
  final List<ManaInterference> interferences;

  const ManaField({
    this.ambientDensity = 0.5,
    this.ambientAttribute = ManaAttribute.neutral,
    this.manaSources = const [],
    this.flow = const ManaFlow.neutral(),
    this.interferences = const [],
  });
}

/// 灵气属性
enum ManaAttribute {
  neutral,   // 中性/无属性
  wood,      // 木灵气 - 生机、治愈
  fire,      // 火灵气 - 炽热、爆裂
  earth,     // 土灵气 - 厚重、防御
  metal,     // 金灵气 - 锋锐、杀伐
  water,     // 水灵气 - 柔和、渗透
  yin,       // 阴气 - 幽冥、凝滞
  yang,      // 阳气 - 炽盛、升腾
  mixed,     // 混杂
  corrupt,   // 污染/魔气
  divine,    // 神力/仙气
}

/// 灵力源点
class ManaSource {
  final String sourceId;
  final ManaSourceType type;
  final double intensity;
  final ManaAttribute attribute;
  final String location;
  final double spreadRadius;
  final double stability;
  final String? ownerEntityId;
  final ManaFreshness freshness;

  const ManaSource({
    required this.sourceId,
    required this.type,
    required this.intensity,
    this.attribute = ManaAttribute.neutral,
    required this.location,
    this.spreadRadius = 1.0,
    this.stability = 1.0,
    this.ownerEntityId,
    this.freshness = ManaFreshness.active,
  });
}

/// 灵力源点类型
enum ManaSourceType {
  // 环境源
  spiritVein,      // 灵脉节点
  formationCore,   // 阵法核心
  barrierNode,     // 结界节点
  spiritWell,      // 灵井/灵泉

  // 实体源
  cultivatorAura,  // 修士气息
  artifactAura,    // 法宝威能
  spiritBeastAura, // 妖兽气息
  formationTrace,  // 阵法残留

  // 事件源
  spellResidue,    // 法术残留
  breakthrough,    // 突破波动
  tribulation,     // 天劫气息
  sacrifice,       // 献祭痕迹

  // 异常源
  corruption,      // 污染源
  seal,            // 封印
  voidRift,        // 虚空裂缝
}

/// 灵力残留新鲜度
enum ManaFreshness {
  active,      // 正在活跃
  recent,      // 刚刚结束
  fading,      // 正在消散
  old,         // 陈旧残留
  ancient,     // 远古痕迹
}

/// 灵力流动
class ManaFlow {
  final double strength;
  final String direction;
  final List<ManaVortex> vortices;

  const ManaFlow({
    this.strength = 0.0,
    this.direction = '',
    this.vortices = const [],
  });

  const ManaFlow.neutral() : this();
}

/// 灵力涡流/汇聚点
class ManaVortex {
  final String vortexId;
  final String location;
  final double intensity;
  final bool isConverging;
  final double radius;

  const ManaVortex({
    required this.vortexId,
    required this.location,
    required this.intensity,
    this.isConverging = true,
    this.radius = 1.0,
  });
}

/// 灵力干扰/屏蔽
class ManaInterference {
  final String interferenceId;
  final InterferenceType type;
  final double strength;
  final String affectedArea;

  const ManaInterference({
    required this.interferenceId,
    required this.type,
    required this.strength,
    required this.affectedArea,
  });
}

enum InterferenceType {
  shielding,    // 屏蔽 - 阻断灵力感知
  scrambling,   // 扰乱 - 干扰感知清晰度
  masking,      // 伪装 - 隐藏真实气息
  amplifying,   // 放大 - 增强特定信号
  redirecting,  // 重定向 - 改变感知方向
}
```

### 3.3 Character Runtime State

```dart
// lib/core/models/agent/character_runtime_state.dart

class CharacterRuntimeState {
  final String characterId;
  final CharacterProfile profile;
  final MindModelCard mindModelCard;
  final Map<String, RelationModel> relationshipModels;
  final BeliefState beliefState;
  final EmotionState emotionState;
  final BaselineBodyProfile baselineBodyProfile;
  final TemporaryBodyState temporaryBodyState;
  final EmbodimentState? currentEmbodimentState;
  final CurrentGoals currentGoals;
  final List<String> memoryIndexRefs;
}

class CharacterProfile {
  final List<String> traits;
  final List<String> values;
  final CognitiveStyle cognitiveStyle;
  final SocialStyle socialStyle;
}

class MindModelCard {
  final String selfImage;
  final List<String> worldview;
  final List<String> socialLogic;
  final List<String> fearTriggers;
  final List<String> defensePatterns;
  final List<String> desirePatterns;
}

class RelationModel {
  final String targetCharacterId;
  final double trust;
  final String perceivedIntent;
  final String pastInteractions;
  final Map<String, dynamic> additionalAttributes;
}

class BeliefState {
  final Map<String, double> beliefConfidences;
  final List<String> activeHypotheses;
  final String? currentHypothesis;
}

class EmotionState {
  final Map<String, double> emotions;
}

class CurrentGoals {
  final List<String> shortTerm;
  final List<String> mediumTerm;
  final List<String> hidden;
}
```

### 3.4 Baseline Body Profile

```dart
// lib/core/models/agent/baseline_body_profile.dart

class BaselineBodyProfile {
  final String species;
  final SensoryBaseline sensoryBaseline;
  final List<String> specialTraits;
  final List<String> vulnerabilities;
  final MotorBaseline motorBaseline;
  final CognitionBaseline cognitionBaseline;
  final ManaSensoryBaseline manaSensoryBaseline;

  const BaselineBodyProfile({
    required this.species,
    required this.sensoryBaseline,
    this.specialTraits = const [],
    this.vulnerabilities = const [],
    required this.motorBaseline,
    required this.cognitionBaseline,
    required this.manaSensoryBaseline,
  });
}

class SensoryBaseline {
  final double vision;
  final double hearing;
  final double smell;
  final double touch;
  final double proprioception;
}

class MotorBaseline {
  final double mobility;
  final double balance;
  final double stamina;
}

class CognitionBaseline {
  final double stressTolerance;
  final double sensoryOverloadTolerance;
}

/// 灵觉基线
class ManaSensoryBaseline {
  final double baseAcuity;
  final double realmModifier;
  final double speciesModifier;
  final double techniqueModifier;
  final Map<ManaAttribute, double> attributeAffinity;
  final List<ManaSenseTrait> traits;

  const ManaSensoryBaseline({
    this.baseAcuity = 1.0,
    this.realmModifier = 1.0,
    this.speciesModifier = 1.0,
    this.techniqueModifier = 1.0,
    this.attributeAffinity = const {},
    this.traits = const [],
  });

  double get effectiveAcuity =>
      baseAcuity * realmModifier * speciesModifier * techniqueModifier;
}

/// 灵觉特殊能力
enum ManaSenseTrait {
  basicSense,           // 基础灵觉
  auraReading,          // 气息解读
  attributeSense,       // 属性感知
  traceTracking,        // 痕迹追踪
  formationInsight,     // 阵法洞察
  soulPerception,       // 神识探查
  hiddenSense,          // 隐匿感知
  corruptionDetection,  // 污染检测
  fateSensing,          // 天机感应
  voidPerception,       // 虚空感知
  tribulationSense,     // 劫难感应
  bloodlineSense,       // 血脉感应
  contractSense,        // 契约感应
  territorySense,       // 领域感应
}
```

### 3.5 Temporary Body State

```dart
// lib/core/models/agent/temporary_body_state.dart

class TemporaryBodyState {
  final SensoryBlocks sensoryBlocks;
  final List<Injury> injuries;
  final double bloodLoss;
  final double fatigue;
  final double painLevel;
  final double dizziness;
  final List<String> illness;
  final List<DrugEffect> drugEffects;
  final double hunger;
  final double thirst;
  final double emotionalArousalBodyEffect;

  final double? manaDepletion;
  final ManaAttribute? manaAttributeBoost;
  final double soulDamage;
  final String? activeTechnique;
  final TechniqueState? techniqueState;

  const TemporaryBodyState({
    required this.sensoryBlocks,
    this.injuries = const [],
    this.bloodLoss = 0.0,
    this.fatigue = 0.0,
    this.painLevel = 0.0,
    this.dizziness = 0.0,
    this.illness = const [],
    this.drugEffects = const [],
    this.hunger = 0.0,
    this.thirst = 0.0,
    this.emotionalArousalBodyEffect = 0.0,
    this.manaDepletion,
    this.manaAttributeBoost,
    this.soulDamage = 0.0,
    this.activeTechnique,
    this.techniqueState,
  });
}

class SensoryBlocks {
  final bool visionBlocked;
  final bool hearingBlocked;
  final bool smellBlocked;
  final bool manaBlocked;

  const SensoryBlocks({
    this.visionBlocked = false,
    this.hearingBlocked = false,
    this.smellBlocked = false,
    this.manaBlocked = false,
  });
}

class Injury {
  final String part;
  final double severity;
  final double pain;
  final double functionalPenalty;
}

class DrugEffect {
  final String effectId;
  final String description;
  final double intensity;
  final Duration remainingDuration;
}

class TechniqueState {
  final String techniqueId;
  final double intensity;
  final double stability;
  final Duration uptime;
  final List<ManaAttribute> activeAttributes;

  const TechniqueState({
    required this.techniqueId,
    required this.intensity,
    this.stability = 1.0,
    this.uptime = Duration.zero,
    this.activeAttributes = const [],
  });
}
```

### 3.6 Embodiment State

```dart
// lib/core/models/agent/embodiment_state.dart

class EmbodimentState {
  final String characterId;
  final String sceneTurnId;
  final SensoryCapabilities sensoryCapabilities;
  final BodyConstraints bodyConstraints;
  final SalienceModifiers salienceModifiers;
  final ReasoningModifiers reasoningModifiers;
  final ActionFeasibility actionFeasibility;
}

class SensoryCapabilities {
  final SensoryCapability vision;
  final SensoryCapability hearing;
  final SensoryCapability smell;
  final SensoryCapability touch;
  final SensoryCapability proprioception;
  final ManaSensoryCapability mana;

  const SensoryCapabilities({
    required this.vision,
    required this.hearing,
    required this.smell,
    required this.touch,
    required this.proprioception,
    required this.mana,
  });
}

class SensoryCapability {
  final double availability;
  final double acuity;
  final double stability;
  final String notes;

  const SensoryCapability({
    required this.availability,
    required this.acuity,
    this.stability = 1.0,
    this.notes = '',
  });
}

/// 灵觉能力
class ManaSensoryCapability {
  final double availability;
  final double acuity;
  final double stability;
  final double rangeModifier;
  final Map<ManaAttribute, double> attributeSensitivity;
  final double penetration;
  final double overloadLevel;
  final String notes;

  const ManaSensoryCapability({
    required this.availability,
    required this.acuity,
    this.stability = 1.0,
    this.rangeModifier = 1.0,
    this.attributeSensitivity = const {},
    this.penetration = 0.0,
    this.overloadLevel = 0.0,
    this.notes = '',
  });

  static const ManaSensoryCapability mortal = ManaSensoryCapability(
    availability: 0.1,
    acuity: 0.3,
    stability: 1.0,
    rangeModifier: 0.5,
    penetration: 0.0,
  );

  static const ManaSensoryCapability cultivator = ManaSensoryCapability(
    availability: 1.0,
    acuity: 1.0,
    stability: 1.0,
    rangeModifier: 1.0,
    penetration: 0.3,
  );

  static const ManaSensoryCapability sensitive = ManaSensoryCapability(
    availability: 1.0,
    acuity: 1.5,
    stability: 0.9,
    rangeModifier: 1.5,
    penetration: 0.5,
  );
}

class BodyConstraints {
  final double mobility;
  final double balance;
  final double painLoad;
  final double fatigue;
  final double cognitiveClarity;
}

class SalienceModifiers {
  final List<AttentionPull> attentionPull;
  final List<AversionTrigger> aversionTriggers;
  final List<String> overloadRisks;
}

class AttentionPull {
  final String stimulusType;
  final double modifier;
  final String reason;
}

class AversionTrigger {
  final String stimulusType;
  final double modifier;
  final String reason;
}

class ReasoningModifiers {
  final double cognitiveClarity;
  final double painBias;
  final double threatBias;
  final double overloadBias;
}

class ActionFeasibility {
  final double physicalExecutionCapacity;
  final double socialPatience;
  final double fineControl;
  final double sustainedAttention;
}
```

### 3.7 Filtered Scene View

```dart
// lib/core/models/agent/filtered_scene_view.dart

class FilteredSceneView {
  final String characterId;
  final String sceneTurnId;
  final List<VisibleEntity> visibleEntities;
  final List<AudibleSignal> audibleSignals;
  final List<OlfactorySignal> olfactorySignals;
  final List<TactileSignal> tactileSignals;
  final List<ManaSignal> manaSignals;
  final ManaEnvironmentSense manaEnvironment;
  final SpatialContext spatialContext;

  const FilteredSceneView({
    required this.characterId,
    required this.sceneTurnId,
    this.visibleEntities = const [],
    this.audibleSignals = const [],
    this.olfactorySignals = const [],
    this.tactileSignals = const [],
    this.manaSignals = const [],
    this.manaEnvironment = const ManaEnvironmentSense(),
    required this.spatialContext,
  });
}

class VisibleEntity {
  final String entityId;
  final double visibilityScore;
  final double clarity;
  final String notes;
}

class AudibleSignal {
  final String signalId;
  final String content;
  final double audibilityScore;
  final String direction;
}

class OlfactorySignal {
  final String signalId;
  final String content;
  final double intensity;
  final String freshness;
}

class TactileSignal {
  final String signalId;
  final String content;
  final double immediacy;
}

/// 灵觉信号
class ManaSignal {
  final String signalId;
  final String content;
  final ManaSourceType sourceType;
  final double perceivedIntensity;
  final ManaAttribute attribute;
  final double clarity;
  final String direction;
  final double? estimatedDistance;
  final double perceivedStability;
  final ManaFreshness freshness;
  final String? associatedEntityId;
  final ManaSignalInsight? insight;
  final String notes;

  const ManaSignal({
    required this.signalId,
    required this.content,
    required this.sourceType,
    required this.perceivedIntensity,
    this.attribute = ManaAttribute.neutral,
    required this.clarity,
    required this.direction,
    this.estimatedDistance,
    this.perceivedStability = 1.0,
    this.freshness = ManaFreshness.active,
    this.associatedEntityId,
    this.insight,
    this.notes = '',
  });
}

/// 灵觉信号解读
class ManaSignalInsight {
  final String? estimatedRealm;
  final String? estimatedTechnique;
  final double threatLevel;
  final bool? isHostile;
  final bool? isConcealed;
  final String additionalInfo;

  const ManaSignalInsight({
    this.estimatedRealm,
    this.estimatedTechnique,
    this.threatLevel = 0.0,
    this.isHostile,
    this.isConcealed,
    this.additionalInfo = '',
  });
}

/// 灵觉环境感知
class ManaEnvironmentSense {
  final double perceivedDensity;
  final ManaAttribute dominantAttribute;
  final bool suitableForCultivation;
  final bool hasAnomaly;
  final String anomalyDescription;
  final String? flowDescription;
  final List<String> convergencePoints;

  const ManaEnvironmentSense({
    this.perceivedDensity = 0.5,
    this.dominantAttribute = ManaAttribute.neutral,
    this.suitableForCultivation = true,
    this.hasAnomaly = false,
    this.anomalyDescription = '',
    this.flowDescription,
    this.convergencePoints = const [],
  });
}

class SpatialContext {
  final List<String> reachableAreas;
  final List<String> nearbyObstacles;
}
```

### 3.8 Memory Entry

```dart
// lib/core/models/agent/memory_entry.dart

class MemoryEntry {
  final String memoryId;
  final String content;
  final String ownerCharacterId;
  final List<String> knownBy;
  final MemoryVisibility visibility;
  final double emotionalWeight;
  final DateTime createdAt;
  final DateTime? lastAccessedAt;

  const MemoryEntry({
    required this.memoryId,
    required this.content,
    required this.ownerCharacterId,
    required this.knownBy,
    required this.visibility,
    this.emotionalWeight = 0.0,
    required this.createdAt,
    this.lastAccessedAt,
  });
}

enum MemoryVisibility {
  public,
  private,
  shared,
}
```

### 3.9 Cognitive Pass I/O

```dart
// lib/core/models/agent/cognitive_pass_io.dart

class CharacterCognitivePassInput {
  final String characterId;
  final String sceneTurnId;
  final FilteredSceneView filteredSceneView;
  final EmbodimentState embodimentState;
  final TemporaryBodyState bodyState;
  final List<MemoryEntry> accessibleMemories;
  final BeliefState priorBeliefState;
  final Map<String, RelationModel> relationModels;
  final EmotionState emotionState;
  final CurrentGoals currentGoals;
  final List<SceneEvent> recentEventDelta;
}

class CharacterCognitivePassOutput {
  final String characterId;
  final String sceneTurnId;
  final PerceptionDelta perceptionDelta;
  final BeliefUpdate beliefUpdate;
  final IntentPlan intentPlan;
}

class PerceptionDelta {
  final List<NoticedFact> noticedFacts;
  final List<UnnoticedButObservable> unnoticedButObservable;
  final List<AmbiguousSignal> ambiguousSignals;
  final List<SubjectiveImpression> subjectiveImpressions;
  final List<AffectiveColoring> affectiveColoring;
  final List<MemoryActivation> memoryActivations;
  final List<String> immediateConcerns;
}

class BeliefUpdate {
  final List<BeliefReinforced> stableBeliefsReinforced;
  final List<BeliefWeakened> stableBeliefsWeakened;
  final List<NewHypothesis> newHypotheses;
  final List<RevisedModelOfOther> revisedModelsOfOthers;
  final List<ContradictionAndTension> contradictionsAndTension;
  final EmotionalShift emotionalShift;
  final List<String> decisionRelevantBeliefs;
}

class IntentPlan {
  final CurrentGoals activeGoals;
  final DecisionFrame decisionFrame;
  final List<CandidateIntent> candidateIntents;
  final SelectedIntent selectedIntent;
  final ExpressionConstraints expressionConstraints;
}

class SelectedIntent {
  final String intent;
  final String reason;
  final List<String> dependsOnBeliefs;
  final String emotionalDriver;
  final List<SuppressedAlternative> suppressedAlternatives;
}

class ExpressionConstraints {
  final RevealLevel revealLevel;
  final String tone;
  final List<String> behavioralNotes;
}

enum RevealLevel {
  direct, guarded, masked, deceptive, silent
}
```

### 3.10 Dirty Flags

```dart
// lib/core/models/agent/dirty_flags.dart

class DirtyFlags {
  bool sceneChanged = false;
  bool bodyChanged = false;
  bool relationChanged = false;
  bool beliefInvalidated = false;
  bool intentInvalidated = false;
  bool directlyAddressed = false;
  bool underThreat = false;
  bool reactionWindowOpen = false;
  bool receivedNewSalientSignal = false;
}
```

### 3.11 Validation Result

```dart
// lib/core/models/agent/validation_result.dart

class ValidationResult {
  final String ruleId;
  final ValidationSeverity severity;
  final String message;
  final String? details;
  final Map<String, dynamic>? context;

  const ValidationResult({
    required this.ruleId,
    required this.severity,
    required this.message,
    this.details,
    this.context,
  });
}

enum ValidationSeverity {
  info,
  warning,
  error,
}
```

---

## 四、程序化核心实现

### 4.1 Scene State Extractor

```dart
// lib/core/services/agent/scene_state_extractor.dart

class SceneStateExtractor {
  /// 从世界状态/叙述输入提取结构化场景模型
  Future<SceneModel> extract({
    required WorldStateDelta worldStateDelta,
    required String narrativeInput,
    required List<EventLogEntry> eventLogDelta,
    SceneModel? priorSceneState,
  }) async {
    // 程序化解析，不调用模型
    // 1. 解析空间布局
    // 2. 解析光照/声学/嗅觉
    // 3. 解析灵力场
    // 4. 解析实体位置和状态
    // 5. 解析可观察信号
    // 6. 构建事件流
  }
}
```

### 4.2 Embodiment Resolver

```dart
// lib/core/services/agent/embodiment_resolver.dart

class EmbodimentResolver {
  /// 解析角色在当前场景中的具身状态
  EmbodimentState resolve({
    required String characterId,
    required BaselineBodyProfile baselineProfile,
    required TemporaryBodyState temporaryState,
    required SceneModel sceneModel,
  }) {
    // 纯程序化计算
    final sensoryCapabilities = _computeSensoryCapabilities(
      baseline: baselineProfile.sensoryBaseline,
      temporary: temporaryState,
      sceneLighting: sceneModel.lighting,
      sceneAcoustics: sceneModel.acoustics,
    );

    final manaCapability = _computeManaCapability(
      baseline: baselineProfile.manaSensoryBaseline,
      temporary: temporaryState,
      sceneManaField: sceneModel.manaField,
    );

    final bodyConstraints = _computeBodyConstraints(
      injuries: temporaryState.injuries,
      fatigue: temporaryState.fatigue,
      painLevel: temporaryState.painLevel,
    );

    final salienceModifiers = _computeSalienceModifiers(
      emotionalState: /* from character state */,
      injuries: temporaryState.injuries,
    );

    return EmbodimentState(
      characterId: characterId,
      sceneTurnId: sceneModel.sceneTurnId,
      sensoryCapabilities: SensoryCapabilities(
        vision: sensoryCapabilities['vision']!,
        hearing: sensoryCapabilities['hearing']!,
        smell: sensoryCapabilities['smell']!,
        touch: sensoryCapabilities['touch']!,
        proprioception: sensoryCapabilities['proprioception']!,
        mana: manaCapability,
      ),
      bodyConstraints: bodyConstraints,
      salienceModifiers: salienceModifiers,
      reasoningModifiers: _computeReasoningModifiers(bodyConstraints),
      actionFeasibility: _computeActionFeasibility(bodyConstraints),
    );
  }

  /// 计算灵觉能力
  ManaSensoryCapability _computeManaCapability({
    required ManaSensoryBaseline baseline,
    required TemporaryBodyState temporary,
    required ManaField sceneManaField,
  }) {
    // 1. 基础可用性
    var availability = 1.0;

    if (temporary.sensoryBlocks.manaBlocked) {
      availability = 0.0;
    }

    availability *= temporary.cognitiveClarity;

    if (temporary.manaDepletion != null && temporary.manaDepletion! > 0.8) {
      availability *= (1.0 - temporary.manaDepletion! * 0.5);
    }

    // 2. 敏锐度
    final acuity = baseline.effectiveAcuity;

    // 3. 稳定性
    var stability = 1.0;
    stability *= temporary.cognitiveClarity;

    if (sceneManaField.ambientDensity > 1.0) {
      stability *= 1.0 / sceneManaField.ambientDensity;
    }

    // 4. 范围修正
    final rangeModifier = baseline.realmModifier;

    // 5. 穿透能力
    var penetration = 0.0;
    if (baseline.traits.contains(ManaSenseTrait.soulPerception)) {
      penetration = 0.5;
    }
    if (baseline.traits.contains(ManaSenseTrait.formationInsight)) {
      penetration = (penetration + 0.3).clamp(0.0, 1.0);
    }

    // 6. 过载状态
    var overloadLevel = 0.0;
    if (sceneManaField.ambientDensity * acuity > 1.5) {
      overloadLevel = (sceneManaField.ambientDensity * acuity - 1.5).clamp(0.0, 1.0);
    }

    // 7. 属性敏感度
    final attributeSensitivity = Map<ManaAttribute, double>.from(
      baseline.attributeAffinity,
    );

    if (temporary.manaAttributeBoost != null) {
      attributeSensitivity[temporary.manaAttributeBoost!] =
          (attributeSensitivity[temporary.manaAttributeBoost!] ?? 1.0) + 0.5;
    }

    return ManaSensoryCapability(
      availability: availability.clamp(0.0, 1.0),
      acuity: acuity,
      stability: stability.clamp(0.0, 1.0),
      rangeModifier: rangeModifier,
      attributeSensitivity: attributeSensitivity,
      penetration: penetration,
      overloadLevel: overloadLevel,
      notes: _buildManaNotes(availability, overloadLevel, baseline.traits),
    );
  }
}
```

### 4.3 Scene Filtering Protocol

```dart
// lib/core/services/agent/scene_filtering.dart

class SceneFilteringProtocol {
  static const double _visibilityThreshold = 0.1;
  static const double _olfactoryThreshold = 0.1;
  static const double _manaThreshold = 0.1;

  /// 生成角色特定的过滤场景视图
  FilteredSceneView filter({
    required SceneModel sceneModel,
    required String characterId,
    required CharacterPosition characterPosition,
    required EmbodimentState embodimentState,
  }) {
    final visibleEntities = <VisibleEntity>[];
    final audibleSignals = <AudibleSignal>[];
    final olfactorySignals = <OlfactorySignal>[];
    final tactileSignals = <TactileSignal>[];
    final manaSignals = <ManaSignal>[];

    // 视觉过滤
    if (embodimentState.sensoryCapabilities.vision.availability >= _visibilityThreshold) {
      for (final entity in sceneModel.entities) {
        final visibility = _computeVisibility(
          entity: entity,
          observerPosition: characterPosition,
          lighting: sceneModel.lighting,
          obstacles: sceneModel.spatialLayout.obstacles,
          visionAcuity: embodimentState.sensoryCapabilities.vision.acuity,
        );
        if (visibility.visibilityScore > _visibilityThreshold) {
          visibleEntities.add(visibility);
        }
      }
    }

    // 嗅觉过滤
    if (embodimentState.sensoryCapabilities.smell.availability >= _olfactoryThreshold) {
      for (final odor in sceneModel.olfactoryField.odorSources) {
        final detectability = _computeOlfactoryDetectability(
          odor: odor,
          observerPosition: characterPosition,
          airflow: sceneModel.olfactoryField.airflow,
          smellAcuity: embodimentState.sensoryCapabilities.smell.acuity,
        );
        if (detectability > _olfactoryThreshold) {
          olfactorySignals.add(OlfactorySignal(
            signalId: odor.id,
            content: odor.type.name,
            intensity: detectability,
            freshness: odor.freshness.name,
          ));
        }
      }
    }

    // 灵觉过滤
    ManaEnvironmentSense manaEnvironment = const ManaEnvironmentSense();
    if (embodimentState.sensoryCapabilities.mana.availability >= _manaThreshold) {
      manaSignals.addAll(_filterManaSignals(
        manaField: sceneModel.manaField,
        observerPosition: characterPosition,
        manaCapability: embodimentState.sensoryCapabilities.mana,
        interferences: sceneModel.manaField.interferences,
        entities: sceneModel.entities,
      ));

      manaEnvironment = _senseManaEnvironment(
        manaField: sceneModel.manaField,
        observerPosition: characterPosition,
        manaCapability: embodimentState.sensoryCapabilities.mana,
      );
    }

    return FilteredSceneView(
      characterId: characterId,
      sceneTurnId: sceneModel.sceneTurnId,
      visibleEntities: visibleEntities,
      audibleSignals: audibleSignals,
      olfactorySignals: olfactorySignals,
      tactileSignals: tactileSignals,
      manaSignals: manaSignals,
      manaEnvironment: manaEnvironment,
      spatialContext: _computeSpatialContext(characterPosition, sceneModel),
    );
  }

  /// 过滤灵力信号
  List<ManaSignal> _filterManaSignals({
    required ManaField manaField,
    required CharacterPosition observerPosition,
    required ManaSensoryCapability manaCapability,
    required List<ManaInterference> interferences,
    required List<SceneEntity> entities,
  }) {
    final signals = <ManaSignal>[];

    for (final source in manaField.manaSources) {
      // 1. 计算距离衰减
      final distance = _computeDistance(
        observerPosition.locationId,
        source.location,
      );
      final distanceFactor = _manaDistanceDecay(distance, manaCapability.rangeModifier);

      // 2. 计算干扰影响
      final interferenceFactor = _computeInterferenceFactor(
        interferences: interferences,
        sourceLocation: source.location,
        observerPosition: observerPosition,
        penetration: manaCapability.penetration,
      );

      // 3. 计算属性敏感度修正
      final attributeFactor = _computeAttributeFactor(
        sourceAttribute: source.attribute,
        sensitivity: manaCapability.attributeSensitivity,
      );

      // 4. 计算最终感知强度
      final perceivedIntensity = source.intensity *
          distanceFactor *
          interferenceFactor *
          attributeFactor *
          manaCapability.acuity;

      // 5. 判断是否超过感知阈值
      final threshold = _manaThreshold(source.type, source.freshness);
      if (perceivedIntensity < threshold) continue;

      // 6. 计算清晰度
      final clarity = _computeManaClarity(
        perceivedIntensity: perceivedIntensity,
        stability: source.stability,
        manaStability: manaCapability.stability,
        interferenceFactor: interferenceFactor,
      );

      // 7. 生成解读
      ManaSignalInsight? insight;
      if (clarity > 0.5 && manaCapability.availability > 0.5) {
        insight = _interpretManaSignal(
          source: source,
          entities: entities,
          clarity: clarity,
        );
      }

      signals.add(ManaSignal(
        signalId: 'mana_${source.sourceId}',
        content: _describeManaSource(source, perceivedIntensity),
        sourceType: source.type,
        perceivedIntensity: perceivedIntensity,
        attribute: source.attribute,
        clarity: clarity,
        direction: _computeDirection(observerPosition.locationId, source.location),
        estimatedDistance: distance,
        perceivedStability: source.stability,
        freshness: source.freshness,
        associatedEntityId: source.ownerEntityId,
        insight: insight,
      ));
    }

    signals.sort((a, b) => b.perceivedIntensity.compareTo(a.perceivedIntensity));
    return signals;
  }

  /// 灵力距离衰减
  double _manaDistanceDecay(double distance, double rangeModifier) {
    final normalizedDistance = distance / rangeModifier;
    return 1.0 / (1.0 + normalizedDistance * 0.05);
  }

  /// 灵力感知阈值
  double _manaThreshold(ManaSourceType type, ManaFreshness freshness) {
    final baseThreshold = switch (type) {
      ManaSourceType.spiritVein => 0.05,
      ManaSourceType.cultivatorAura => 0.1,
      ManaSourceType.artifactAura => 0.15,
      ManaSourceType.spellResidue => 0.2,
      ManaSourceType.formationCore => 0.1,
      ManaSourceType.formationTrace => 0.25,
      ManaSourceType.corruption => 0.08,
      ManaSourceType.tribulation => 0.02,
      _ => 0.15,
    };

    final freshnessModifier = switch (freshness) {
      ManaFreshness.active => 1.0,
      ManaFreshness.recent => 1.2,
      ManaFreshness.fading => 1.5,
      ManaFreshness.old => 2.0,
      ManaFreshness.ancient => 3.0,
    };

    return baseThreshold * freshnessModifier;
  }

  /// 感知环境灵气
  ManaEnvironmentSense _senseManaEnvironment({
    required ManaField manaField,
    required CharacterPosition observerPosition,
    required ManaSensoryCapability manaCapability,
  }) {
    final perceivedDensity = manaField.ambientDensity * manaCapability.acuity;

    final suitableForCultivation = perceivedDensity > 0.3 &&
        manaField.ambientAttribute != ManaAttribute.corrupt;

    final hasAnomaly = manaField.manaSources.any(
      (s) => s.type == ManaSourceType.corruption ||
             s.type == ManaSourceType.voidRift ||
             s.type == ManaSourceType.tribulation,
    );

    String anomalyDescription = '';
    if (hasAnomaly) {
      final anomalies = manaField.manaSources
          .where((s) => s.type == ManaSourceType.corruption ||
                       s.type == ManaSourceType.voidRift)
          .map((s) => s.type.name)
          .toList();
      anomalyDescription = '检测到：${anomalies.join('、')}';
    }

    final convergencePoints = manaField.flow.vortices
        .where((v) => v.isConverging && v.intensity > 0.3)
        .map((v) => v.location)
        .toList();

    return ManaEnvironmentSense(
      perceivedDensity: perceivedDensity.clamp(0.0, 1.0),
      dominantAttribute: manaField.ambientAttribute,
      suitableForCultivation: suitableForCultivation,
      hasAnomaly: hasAnomaly,
      anomalyDescription: anomalyDescription,
      flowDescription: manaField.flow.strength > 0.1
          ? '灵气流动，方向${manaField.flow.direction}'
          : null,
      convergencePoints: convergencePoints,
    );
  }
}
```

### 4.4 Memory Access Protocol

```dart
// lib/core/services/agent/memory_access.dart

class MemoryAccessProtocol {
  final RustBridge _rustBridge;

  /// 检索角色可访问的记忆
  Future<MemoryRetrievalOutput> retrieve({
    required String characterId,
    required String queryContext,
    required List<SceneEvent> recentEvents,
    required BeliefState beliefState,
    required EmotionState emotionState,
  }) async {
    final allMemories = await _rustBridge.listMemoriesForCharacter(characterId);

    // 过滤：只返回 knownBy 包含该角色的记忆
    final accessibleMemories = allMemories
        .where((m) => m.knownBy.contains(characterId) ||
                      m.visibility == MemoryVisibility.public)
        .toList();

    // 相关性排序
    final relevantMemories = _rankByRelevance(
      memories: accessibleMemories,
      queryContext: queryContext,
      emotionState: emotionState,
    );

    // 信念触发
    final triggeredMemories = _findTriggeredMemories(
      memories: accessibleMemories,
      beliefState: beliefState,
    );

    return MemoryRetrievalOutput(
      accessibleMemories: accessibleMemories,
      relevantMemories: relevantMemories,
      triggeredMemories: triggeredMemories,
    );
  }
}

class MemoryRetrievalOutput {
  final List<MemoryEntry> accessibleMemories;
  final List<MemoryEntry> relevantMemories;
  final List<MemoryEntry> triggeredMemories;
}
```

### 4.5 Character Input Assembly

```dart
// lib/core/services/agent/character_input_assembly.dart

class CharacterInputAssembly {
  final SceneFilteringProtocol _sceneFiltering;
  final MemoryAccessProtocol _memoryAccess;
  final EmbodimentResolver _embodimentResolver;

  /// 组装角色认知传递的完整输入
  Future<CharacterCognitivePassInput> assemble({
    required SceneModel sceneModel,
    required CharacterRuntimeState characterState,
    required List<SceneEvent> eventDelta,
  }) async {
    // 1. 位置解析
    final position = _resolvePosition(characterState, sceneModel);

    // 2. 具身解析
    final embodimentState = _embodimentResolver.resolve(
      characterId: characterState.characterId,
      baselineProfile: characterState.baselineBodyProfile,
      temporaryState: characterState.temporaryBodyState,
      sceneModel: sceneModel,
    );

    // 3. 场景过滤
    final filteredSceneView = _sceneFiltering.filter(
      sceneModel: sceneModel,
      characterId: characterState.characterId,
      characterPosition: position,
      embodimentState: embodimentState,
    );

    // 4. 记忆检索
    final memories = await _memoryAccess.retrieve(
      characterId: characterState.characterId,
      queryContext: _buildQueryContext(filteredSceneView, eventDelta),
      recentEvents: eventDelta,
      beliefState: characterState.beliefState,
      emotionState: characterState.emotionState,
    );

    return CharacterCognitivePassInput(
      characterId: characterState.characterId,
      sceneTurnId: sceneModel.sceneTurnId,
      filteredSceneView: filteredSceneView,
      embodimentState: embodimentState,
      bodyState: characterState.temporaryBodyState,
      accessibleMemories: memories.relevantMemories,
      priorBeliefState: characterState.beliefState,
      relationModels: characterState.relationshipModels,
      emotionState: characterState.emotionState,
      currentGoals: characterState.currentGoals,
      recentEventDelta: eventDelta,
    );
  }
}
```

---

## 五、认知层实现

### 5.1 Character Cognitive Pass

```dart
// lib/core/services/agent/character_cognitive_pass.dart

class CharacterCognitivePass {
  final ChatService _chatService;

  /// 单次模型调用完成感知+信念+意图
  Future<CharacterCognitivePassOutput> execute({
    required CharacterCognitivePassInput input,
    required RuntimeApiConfig apiConfig,
    required AgentPresetConfig presetConfig,
  }) async {
    // 构建专门的 Agent 模式 prompt
    final prompt = _buildCognitivePrompt(input);

    // 单次模型调用
    final response = await _chatService.sendRound(SendRoundRequest(
      sessionId: _agentSessionId,
      userInput: '',
      apiConfig: apiConfig,
      presetConfig: presetConfig,
    ));

    // 解析结构化输出
    return _parseCognitiveOutput(response.assistantMessage.content);
  }

  String _buildCognitivePrompt(CharacterCognitivePassInput input) {
    // 构建 YAML/JSON 格式的结构化输入
    // 包含：filtered_scene_view, embodiment_state, memories, beliefs, etc.
    // 要求输出：perception_delta, belief_update, intent_plan
  }
}
```

---

## 六、验证层实现

### 6.1 Agent Validator

```dart
// lib/core/services/agent/validation/agent_validator.dart

class AgentValidator {
  final List<ValidationRule> _rules;

  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];

    for (final rule in _rules) {
      results.addAll(rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: output,
        accessibleMemories: accessibleMemories,
      ));
    }

    return results;
  }
}
```

### 6.2 Omniscience Leakage Rule

```dart
// lib/core/services/agent/validation/rules/omniscience_leakage_rule.dart

class OmniscienceLeakageRule extends ValidationRule {
  @override
  String get ruleId => 'omniscience_leakage';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];

    if (output == null) return results;

    // 检查输出是否引用了不可访问的实体
    final referencedEntities = _extractReferencedEntities(output);
    final visibleEntityIds = filteredView.visibleEntities.map((e) => e.entityId).toSet();

    for (final entityId in referencedEntities) {
      if (!visibleEntityIds.contains(entityId)) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: '引用了不可见的实体',
          details: 'entityId=$entityId',
        ));
      }
    }

    // 检查输出是否引用了不可访问的记忆
    final referencedMemories = _extractReferencedMemories(output);
    final accessibleMemoryIds = accessibleMemories.map((m) => m.memoryId).toSet();

    for (final memoryId in referencedMemories) {
      if (!accessibleMemoryIds.contains(memoryId)) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: '引用了不可访问的记忆',
          details: 'memoryId=$memoryId',
        ));
      }
    }

    return results;
  }
}
```

### 6.3 Embodiment Ignored Rule

```dart
// lib/core/services/agent/validation/rules/embodiment_ignored_rule.dart

class EmbodimentIgnoredRule extends ValidationRule {
  @override
  String get ruleId => 'embodiment_ignored';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];

    // 检查视觉约束是否被忽略
    if (embodimentState.sensoryCapabilities.vision.availability < 0.1) {
      if (filteredView.visibleEntities.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: '视觉不可用但存在可见实体',
          details: 'availability=${embodimentState.sensoryCapabilities.vision.availability}',
        ));
      }
    }

    // 检查嗅觉约束是否被忽略
    if (embodimentState.sensoryCapabilities.smell.availability < 0.1) {
      if (filteredView.olfactorySignals.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: '嗅觉不可用但存在嗅觉信号',
        ));
      }
    }

    // 检查灵觉约束是否被忽略
    if (embodimentState.sensoryCapabilities.mana.availability < 0.1) {
      if (filteredView.manaSignals.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: '灵觉不可用但检测到灵力信号',
        ));
      }
    }

    return results;
  }
}
```

### 6.4 Mana Sense Validation Rule

```dart
// lib/core/services/agent/validation/rules/mana_sense_validation_rule.dart

class ManaSenseValidationRule extends ValidationRule {
  @override
  String get ruleId => 'mana_sense_validation';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];
    final manaCapability = embodimentState.sensoryCapabilities.mana;

    // 1. 灵觉不可用时检测到灵力信号
    if (manaCapability.availability < 0.1) {
      if (filteredView.manaSignals.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: '灵觉不可用但检测到灵力信号',
          details: 'availability=${manaCapability.availability}, '
              'signals=${filteredView.manaSignals.length}',
        ));
      }
    }

    // 2. 凡人检测到高阶修士气息
    if (manaCapability.acuity < 0.5) {
      for (final signal in filteredView.manaSignals) {
        if (signal.sourceType == ManaSourceType.cultivatorAura &&
            signal.perceivedIntensity > 0.3) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.warning,
            message: '凡人不应清晰感知修士气息',
            details: 'acuity=${manaCapability.acuity}, '
                'perceivedIntensity=${signal.perceivedIntensity}',
          ));
        }
      }
    }

    // 3. 灵觉过载但输出正常
    if (manaCapability.overloadLevel > 0.7) {
      // 检查输出是否有体现过载影响
    }

    return results;
  }
}
```

### 6.5 Memory Leakage Rule

```dart
// lib/core/services/agent/validation/rules/memory_leakage_rule.dart

class MemoryLeakageRule extends ValidationRule {
  @override
  String get ruleId => 'memory_leakage';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];

    // 检查 private 记忆的 knownBy 是否正确
    for (final memory in accessibleMemories) {
      if (memory.visibility == MemoryVisibility.private) {
        if (memory.knownBy.length != 1 ||
            memory.knownBy.first != memory.ownerCharacterId) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'private 记忆的 knownBy 应只包含所有者',
            details: 'memoryId=${memory.memoryId}, knownBy=${memory.knownBy}',
          ));
        }
      }
    }

    return results;
  }
}
```

---

## 七、主循环与调度

### 7.1 Agent Runtime

```dart
// lib/core/services/agent/agent_runtime.dart

class AgentRuntime {
  final SceneStateExtractor _sceneExtractor;
  final CharacterInputAssembly _inputAssembly;
  final CharacterCognitivePass _cognitivePass;
  final AgentValidator _validator;
  final RustBridge _rustBridge;

  final Map<String, DirtyFlags> _characterDirtyFlags = {};
  final Set<String> _activeCharacters = {};

  /// 主循环：处理一个回合
  Future<AgentTurnResult> processTurn(AgentTurnRequest request) async {
    // 1. 更新世界状态
    final sceneModel = await _sceneExtractor.extract(
      worldStateDelta: request.worldDelta,
      narrativeInput: request.narrativeInput,
      eventLogDelta: request.eventDelta,
    );

    // 2. 计算活跃角色集合和脏标志
    _updateActiveSet(sceneModel, request.eventDelta);

    // 3. 为每个活跃脏角色执行认知传递
    final cognitiveResults = <String, CharacterCognitivePassOutput>{};
    for (final characterId in _activeCharacters) {
      if (!_isDirty(characterId)) continue;

      final input = await _inputAssembly.assemble(
        sceneModel: sceneModel,
        characterState: await _loadCharacterState(characterId),
        eventDelta: request.eventDelta,
      );

      final output = await _cognitivePass.execute(
        input: input,
        apiConfig: request.apiConfig,
        presetConfig: request.presetConfig,
      );

      // 验证
      final validationResults = _validator.validate(
        filteredView: input.filteredSceneView,
        embodimentState: input.embodimentState,
        output: output,
        accessibleMemories: input.accessibleMemories,
      );

      // 记录验证失败
      if (validationResults.any((r) => r.severity == ValidationSeverity.error)) {
        await _logValidationFailures(characterId, validationResults);
      }

      cognitiveResults[characterId] = output;
    }

    // 4. 仲裁和渲染
    final arbitrationResult = _arbitrate(cognitiveResults);
    final renderedOutput = await _renderOutput(arbitrationResult);

    // 5. 持久化状态
    await _commitState(
      sceneModel: sceneModel,
      cognitiveResults: cognitiveResults,
      renderedOutput: renderedOutput,
    );

    return AgentTurnResult(
      sceneModel: sceneModel,
      cognitiveResults: cognitiveResults,
      renderedOutput: renderedOutput,
    );
  }

  void _updateActiveSet(SceneModel scene, List<SceneEvent> events) {
    // 根据事件更新活跃角色集合
  }

  bool _isDirty(String characterId) {
    final flags = _characterDirtyFlags[characterId];
    if (flags == null) return false;
    return flags.sceneChanged ||
           flags.bodyChanged ||
           flags.beliefInvalidated ||
           flags.directlyAddressed ||
           flags.underThreat ||
           flags.reactionWindowOpen;
  }
}

class AgentTurnRequest {
  final WorldStateDelta worldDelta;
  final String narrativeInput;
  final List<EventLogEntry> eventDelta;
  final RuntimeApiConfig apiConfig;
  final AgentPresetConfig presetConfig;
}

class AgentTurnResult {
  final SceneModel sceneModel;
  final Map<String, CharacterCognitivePassOutput> cognitiveResults;
  final RenderedOutput renderedOutput;
}
```

---

## 八、Rust 端持久化

### 8.1 Models

```rust
// rust/src/agent/models.rs

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SceneSnapshot {
    pub snapshot_id: String,
    pub scene_id: String,
    pub scene_turn_id: String,
    pub scene_model: serde_json::Value,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterRuntimeSnapshot {
    pub snapshot_id: String,
    pub character_id: String,
    pub scene_turn_id: String,
    pub relationship_models: serde_json::Value,
    pub belief_state: serde_json::Value,
    pub emotion_state: serde_json::Value,
    pub temporary_body_state: serde_json::Value,
    pub current_goals: serde_json::Value,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TurnTrace {
    pub trace_id: String,
    pub scene_turn_id: String,
    pub perception_packets: Vec<serde_json::Value>,
    pub belief_updates: Vec<serde_json::Value>,
    pub intent_plans: Vec<serde_json::Value>,
    pub rendered_output: serde_json::Value,
    pub validation_results: Vec<ValidationResult>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationResult {
    pub rule_id: String,
    pub severity: String,
    pub message: String,
    pub details: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryRecord {
    pub memory_id: String,
    pub content: String,
    pub owner_character_id: String,
    pub known_by: Vec<String>,
    pub visibility: String,
    pub emotional_weight: f64,
    pub created_at: String,
    pub last_accessed_at: Option<String>,
}
```

### 8.2 Storage

```rust
// rust/src/agent/storage.rs

use sqlite::Connection;

pub struct AgentStorage {
    conn: Connection,
}

impl AgentStorage {
    pub fn new(path: &str) -> Result<Self, sqlite::Error> {
        let conn = Connection::open(path)?;
        let storage = Self { conn };
        storage.initialize_tables()?;
        Ok(storage)
    }

    fn initialize_tables(&self) -> Result<(), sqlite::Error> {
        self.conn.execute("
            CREATE TABLE IF NOT EXISTS scene_snapshots (
                snapshot_id TEXT PRIMARY KEY,
                scene_id TEXT NOT NULL,
                scene_turn_id TEXT NOT NULL,
                scene_model TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        ")?;

        self.conn.execute("
            CREATE TABLE IF NOT EXISTS character_runtime_snapshots (
                snapshot_id TEXT PRIMARY KEY,
                character_id TEXT NOT NULL,
                scene_turn_id TEXT NOT NULL,
                relationship_models TEXT NOT NULL,
                belief_state TEXT NOT NULL,
                emotion_state TEXT NOT NULL,
                temporary_body_state TEXT NOT NULL,
                current_goals TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        ")?;

        self.conn.execute("
            CREATE TABLE IF NOT EXISTS turn_traces (
                trace_id TEXT PRIMARY KEY,
                scene_turn_id TEXT NOT NULL,
                perception_packets TEXT NOT NULL,
                belief_updates TEXT NOT NULL,
                intent_plans TEXT NOT NULL,
                rendered_output TEXT NOT NULL,
                validation_results TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        ")?;

        self.conn.execute("
            CREATE TABLE IF NOT EXISTS memory_records (
                memory_id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                owner_character_id TEXT NOT NULL,
                known_by TEXT NOT NULL,
                visibility TEXT NOT NULL,
                emotional_weight REAL NOT NULL,
                created_at TEXT NOT NULL,
                last_accessed_at TEXT
            )
        ")?;

        Ok(())
    }

    pub fn save_scene_snapshot(&self, snapshot: &SceneSnapshot) -> Result<(), sqlite::Error> {
        // ...
    }

    pub fn save_character_snapshot(&self, snapshot: &CharacterRuntimeSnapshot) -> Result<(), sqlite::Error> {
        // ...
    }

    pub fn save_turn_trace(&self, trace: &TurnTrace) -> Result<(), sqlite::Error> {
        // ...
    }

    pub fn list_memories_for_character(&self, character_id: &str) -> Result<Vec<MemoryRecord>, sqlite::Error> {
        // ...
    }
}
```

---

## 九、潜在坑点与应对策略

| 坑点 | 风险 | 应对策略 |
|------|------|----------|
| **模型输出非结构化** | 解析失败，认知传递中断 | 1. 使用 JSON/YAML 格式约束输出 2. 多次重试+降级模板 3. 输出 schema 验证 |
| **全知泄露难以检测** | 角色行为不符合设定 | 1. 严格的输入过滤 2. 输出后验证 3. 记忆访问日志审计 |
| **状态爆炸** | 长对话后状态过大 | 1. 增量更新+周期压缩 2. 记忆分级（短期/长期） 3. 过期状态清理 |
| **多角色调用成本高** | Token 消耗过大 | 1. Dirty Flags 严格过滤 2. 意图复用 3. Tier B/C 角色简化处理 |
| **Rust-Dart 类型同步** | 两端模型定义不一致 | 1. 使用代码生成 2. 共享 schema 定义文件 3. 单元测试覆盖 |
| **验证规则维护** | 规则过时或遗漏 | 1. 规则可配置化 2. 失败案例回归测试 3. 规则文档化 |
| **Prompt 漂移** | 模型行为随时间变化 | 1. 固定 prompt 版本 2. A/B 测试 3. 监控输出质量指标 |
| **并发安全** | 多角色同时更新状态 | 1. 每角色独立状态空间 2. 写前验证 3. 乐观锁+重试 |
| **记忆检索效率** | 长期记忆过多导致延迟 | 1. 向量索引 2. 分层检索（近期/相关/触发） 3. 缓存热点记忆 |
| **物种特性硬编码** | 新物种难以扩展 | 1. 物种配置文件 2. 特性继承体系 3. 运行时特性注入 |
| **灵觉过载处理** | 高灵气环境导致感知失真 | 1. 过载阈值配置 2. 感知降级策略 3. 验证过载影响 |
| **灵力信号衰减** | 距离计算不准确 | 1. 分场景类型衰减曲线 2. 环境介质修正 3. 单元测试覆盖 |

---

## 十、测试策略

### 10.1 Scene Filtering Tests

```dart
// test/agent/scene_filtering_test.dart

group('Scene Filtering Protocol', () {
  test('blind character has empty visible_entities', () {
    final embodiment = EmbodimentState(
      sensoryCapabilities: SensoryCapabilities(
        vision: SensoryCapability(availability: 0.0, acuity: 1.0),
        hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
        smell: SensoryCapability(availability: 1.0, acuity: 1.0),
        touch: SensoryCapability(availability: 1.0, acuity: 1.0),
        proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
        mana: ManaSensoryCapability.mortal,
      ),
      // ...
    );

    final filtered = sceneFiltering.filter(
      sceneModel: testScene,
      characterId: 'blind_character',
      characterPosition: testPosition,
      embodimentState: embodiment,
    );

    expect(filtered.visibleEntities, isEmpty);
  });

  test('fox spirit detects blood smell human cannot', () {
    final foxEmbodiment = EmbodimentState(
      sensoryCapabilities: SensoryCapabilities(
        smell: SensoryCapability(availability: 1.0, acuity: 1.8),
        // ...
      ),
    );
    final humanEmbodiment = EmbodimentState(
      sensoryCapabilities: SensoryCapabilities(
        smell: SensoryCapability(availability: 1.0, acuity: 0.5),
        // ...
      ),
    );

    final foxView = sceneFiltering.filter(..., embodimentState: foxEmbodiment);
    final humanView = sceneFiltering.filter(..., embodimentState: humanEmbodiment);

    expect(foxView.olfactorySignals.any((s) => s.content.contains('blood')), isTrue);
    expect(humanView.olfactorySignals.any((s) => s.content.contains('blood')), isFalse);
  });

  test('mortal cannot detect cultivator aura', () {
    final mortalEmbodiment = EmbodimentState(
      sensoryCapabilities: SensoryCapabilities(
        mana: ManaSensoryCapability.mortal,
        // ...
      ),
    );

    final filtered = sceneFiltering.filter(
      sceneModel: sceneWithCultivatorAura,
      characterId: 'mortal',
      characterPosition: testPosition,
      embodimentState: mortalEmbodiment,
    );

    expect(filtered.manaSignals.where(
      (s) => s.sourceType == ManaSourceType.cultivatorAura
    ), isEmpty);
  });

  test('sensitive cultivator detects hidden aura', () {
    final sensitiveEmbodiment = EmbodimentState(
      sensoryCapabilities: SensoryCapabilities(
        mana: ManaSensoryCapability.sensitive,
        // ...
      ),
    );

    final filtered = sceneFiltering.filter(
      sceneModel: sceneWithHiddenAura,
      characterId: 'sensitive_cultivator',
      characterPosition: testPosition,
      embodimentState: sensitiveEmbodiment,
    );

    expect(filtered.manaSignals.any((s) => s.insight?.isConcealed == true), isTrue);
  });
});
```

### 10.2 Memory Access Tests

```dart
// test/agent/memory_access_test.dart

group('Memory Access Protocol', () {
  test('private memory only accessible to owner', () {
    final memory = MemoryEntry(
      memoryId: 'secret',
      content: '秘密信息',
      ownerCharacterId: 'alice',
      knownBy: ['alice'],
      visibility: MemoryVisibility.private,
      createdAt: DateTime.now(),
    );

    expect(memoryAccess.canAccess('alice', memory), isTrue);
    expect(memoryAccess.canAccess('bob', memory), isFalse);
  });

  test('shared memory accessible to known_by list', () {
    final memory = MemoryEntry(
      memoryId: 'shared_event',
      content: '共同经历',
      ownerCharacterId: 'alice',
      knownBy: ['alice', 'bob'],
      visibility: MemoryVisibility.shared,
      createdAt: DateTime.now(),
    );

    expect(memoryAccess.canAccess('alice', memory), isTrue);
    expect(memoryAccess.canAccess('bob', memory), isTrue);
    expect(memoryAccess.canAccess('charlie', memory), isFalse);
  });

  test('public memory accessible to all', () {
    final memory = MemoryEntry(
      memoryId: 'public_fact',
      content: '公开事实',
      ownerCharacterId: 'alice',
      knownBy: ['alice'],
      visibility: MemoryVisibility.public,
      createdAt: DateTime.now(),
    );

    expect(memoryAccess.canAccess('anyone', memory), isTrue);
  });
});
```

### 10.3 Validation Tests

```dart
// test/agent/validation_test.dart

group('Agent Validation', () {
  test('detects omniscience leakage', () {
    final output = CharacterCognitivePassOutput(
      // 角色引用了不可见的实体
    );

    final results = validator.validate(
      filteredView: filteredViewWithoutEntity,
      embodimentState: testEmbodiment,
      output: output,
      accessibleMemories: [],
    );

    expect(results.any((r) => r.ruleId == 'omniscience_leakage'), isTrue);
  });

  test('detects embodiment ignored', () {
    final embodiment = EmbodimentState(
      sensoryCapabilities: SensoryCapabilities(
        vision: SensoryCapability(availability: 0.0, acuity: 1.0),
        // ...
      ),
    );

    final filteredView = FilteredSceneView(
      visibleEntities: [VisibleEntity(entityId: 'visible', visibilityScore: 0.5, clarity: 0.5, notes: '')],
      // ...
    );

    final results = validator.validate(
      filteredView: filteredView,
      embodimentState: embodiment,
      output: null,
      accessibleMemories: [],
    );

    expect(results.any((r) => r.ruleId == 'embodiment_ignored'), isTrue);
  });

  test('detects mana sense violation', () {
    final embodiment = EmbodimentState(
      sensoryCapabilities: SensoryCapabilities(
        mana: ManaSensoryCapability.mortal,
        // ...
      ),
    );

    final filteredView = FilteredSceneView(
      manaSignals: [ManaSignal(
        signalId: 'aura',
        content: '修士气息',
        sourceType: ManaSourceType.cultivatorAura,
        perceivedIntensity: 0.8,
        clarity: 0.7,
        direction: 'north',
      )],
      // ...
    );

    final results = validator.validate(
      filteredView: filteredView,
      embodimentState: embodiment,
      output: null,
      accessibleMemories: [],
    );

    expect(results.any((r) => r.ruleId == 'mana_sense_validation'), isTrue);
  });
});
```

---

## 十一、文件结构

```
lib/
├── core/
│   ├── models/
│   │   └── agent/
│   │       ├── scene_model.dart
│   │       ├── mana_field.dart
│   │       ├── character_runtime_state.dart
│   │       ├── baseline_body_profile.dart
│   │       ├── temporary_body_state.dart
│   │       ├── embodiment_state.dart
│   │       ├── memory_entry.dart
│   │       ├── filtered_scene_view.dart
│   │       ├── cognitive_pass_io.dart
│   │       ├── dirty_flags.dart
│   │       └── validation_result.dart
│   └── services/
│       └── agent/
│           ├── scene_state_extractor.dart
│           ├── embodiment_resolver.dart
│           ├── scene_filtering.dart
│           ├── memory_access.dart
│           ├── character_input_assembly.dart
│           ├── character_cognitive_pass.dart
│           ├── agent_runtime.dart
│           ├── action_arbitration.dart
│           ├── surface_realizer.dart
│           └── validation/
│               ├── agent_validator.dart
│               ├── validation_rule.dart
│               └── rules/
│                   ├── omniscience_leakage_rule.dart
│                   ├── embodiment_ignored_rule.dart
│                   ├── memory_leakage_rule.dart
│                   └── mana_sense_validation_rule.dart
├── features/
│   └── agent/
│       ├── agent_module.dart
│       └── presentation/
│           └── agent_debug_page.dart
└── shared/
    └── prompts/
        └── agent/
            ├── cognitive_pass_prompt.dart
            └── surface_realizer_prompt.dart

rust/
└── src/
    └── agent/
        ├── models.rs
        ├── storage.rs
        └── bridge.rs

test/
└── agent/
    ├── scene_filtering_test.dart
    ├── memory_access_test.dart
    ├── validation_test.dart
    └── integration/
        └── agent_runtime_test.dart
```

---

## 十二、Phase 1-3 检查与完善（2026-04-20）

### 检查方法

- 代码项核对：对照 `lib/core/models/agent` 与 `lib/core/services/agent` 的实现文件。
- 测试核对：执行 `flutter test test/agent`，结果为全部通过。

### Phase 1（数据模型层）

- [x] Scene Model：`scene_model.dart`
- [x] Character Runtime State：`character_runtime_state.dart`
- [x] Embodiment State：`embodiment_state.dart`
- [x] Memory Entry：`memory_entry.dart`
- [x] Skill Model：`skill_model.dart`（本次补齐）
- [ ] Skill 与角色能力映射的持久化落盘（后续接 Rust storage 设计）

### Phase 2（程序化核心）

- [x] SceneStateExtractor：`scene_state_extractor.dart`
- [x] EmbodimentResolver：`embodiment_resolver.dart`
- [x] Scene Filtering Protocol：`scene_filtering_protocol.dart`
- [x] Memory Access Protocol：`memory_access_protocol.dart`
- [x] Character Input Assembly：`character_input_assembly.dart`
- [x] Dirty Flags 数据结构：`dirty_flags.dart`

### Phase 3（认知层）

- [x] CharacterCognitivePass：`character_cognitive_pass.dart`
- [x] BeliefUpdater：`belief_updater.dart`
- [x] IntentAgent：`intent_agent.dart`
- [x] 认知链路执行器：`cognitive_pass_executor.dart`
- [x] 灵力过载约束：`embodiment_resolver.dart` + `scene_filtering_protocol.dart`

### Phase 4（表现层）

- [x] 仲裁与冲突（Action Arbitration）：`action_arbitration.dart`（本次补齐）
- [x] 表现层 SurfaceRealizer：`surface_realizer.dart`（本次补齐）
- [x] AgentRuntime 主循环接入仲裁与渲染：`agent_runtime.dart`（本次补齐）

### 阶段结论

- Phase 1：核心模型已齐备（含补齐 Skill Model）。
- Phase 2：核心流程可运行且有测试覆盖。
- Phase 3：认知主链路已落地。
- Phase 4：仲裁与渲染模块已落地，待接入 AgentRuntime 主循环。

---

## 十三、总结

本开发方案基于 rp_agent 系列文档，针对玄幻故事场景扩展了 Mana（灵力）感知维度。

核心设计要点：

1. **信息分层**：World Truth → Scene → Embodiment → Perception → Belief → Intent
2. **程序化核心**：场景过滤、具身解析、记忆访问均为纯代码实现
3. **认知融合**：Perception + Belief + Intent 融合为单次模型调用
4. **验证驱动**：多层验证规则确保角色行为符合设定
5. **灵觉扩展**：独立的 Mana 感知通道，支持玄幻场景特有需求

关键约束：

- 角色只能访问 filtered_scene_view 中的信息
- 记忆访问受 known_by 列表约束
- 灵觉感知受 availability/acuity/penetration 约束
- 所有输出需通过验证规则检查
