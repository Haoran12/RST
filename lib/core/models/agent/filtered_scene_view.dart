import 'mana_field.dart';

// 可见实体
class VisibleEntity {
  const VisibleEntity({
    required this.entityId,
    required this.visibilityScore,
    required this.clarity,
    this.notes = '',
  });

  final String entityId;
  final double visibilityScore;
  final double clarity;
  final String notes;

  VisibleEntity copyWith({
    String? entityId,
    double? visibilityScore,
    double? clarity,
    String? notes,
  }) {
    return VisibleEntity(
      entityId: entityId ?? this.entityId,
      visibilityScore: visibilityScore ?? this.visibilityScore,
      clarity: clarity ?? this.clarity,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entityId': entityId,
      'visibilityScore': visibilityScore,
      'clarity': clarity,
      'notes': notes,
    };
  }

  factory VisibleEntity.fromJson(Map<String, dynamic> json) {
    return VisibleEntity(
      entityId: '${json['entityId'] ?? ''}',
      visibilityScore: _parseDouble(json['visibilityScore']) ?? 0.0,
      clarity: _parseDouble(json['clarity']) ?? 0.0,
      notes: '${json['notes'] ?? ''}',
    );
  }
}

// 可听信号
class AudibleSignal {
  const AudibleSignal({
    required this.signalId,
    required this.content,
    required this.audibilityScore,
    required this.direction,
  });

  final String signalId;
  final String content;
  final double audibilityScore;
  final String direction;

  AudibleSignal copyWith({
    String? signalId,
    String? content,
    double? audibilityScore,
    String? direction,
  }) {
    return AudibleSignal(
      signalId: signalId ?? this.signalId,
      content: content ?? this.content,
      audibilityScore: audibilityScore ?? this.audibilityScore,
      direction: direction ?? this.direction,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'signalId': signalId,
      'content': content,
      'audibilityScore': audibilityScore,
      'direction': direction,
    };
  }

  factory AudibleSignal.fromJson(Map<String, dynamic> json) {
    return AudibleSignal(
      signalId: '${json['signalId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      audibilityScore: _parseDouble(json['audibilityScore']) ?? 0.0,
      direction: '${json['direction'] ?? ''}',
    );
  }
}

// 嗅觉信号
class OlfactorySignal {
  const OlfactorySignal({
    required this.signalId,
    required this.content,
    required this.intensity,
    required this.freshness,
  });

  final String signalId;
  final String content;
  final double intensity;
  final String freshness;

  OlfactorySignal copyWith({
    String? signalId,
    String? content,
    double? intensity,
    String? freshness,
  }) {
    return OlfactorySignal(
      signalId: signalId ?? this.signalId,
      content: content ?? this.content,
      intensity: intensity ?? this.intensity,
      freshness: freshness ?? this.freshness,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'signalId': signalId,
      'content': content,
      'intensity': intensity,
      'freshness': freshness,
    };
  }

  factory OlfactorySignal.fromJson(Map<String, dynamic> json) {
    return OlfactorySignal(
      signalId: '${json['signalId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 0.0,
      freshness: '${json['freshness'] ?? ''}',
    );
  }
}

// 触觉信号
class TactileSignal {
  const TactileSignal({
    required this.signalId,
    required this.content,
    required this.immediacy,
  });

  final String signalId;
  final String content;
  final double immediacy;

  TactileSignal copyWith({
    String? signalId,
    String? content,
    double? immediacy,
  }) {
    return TactileSignal(
      signalId: signalId ?? this.signalId,
      content: content ?? this.content,
      immediacy: immediacy ?? this.immediacy,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'signalId': signalId,
      'content': content,
      'immediacy': immediacy,
    };
  }

  factory TactileSignal.fromJson(Map<String, dynamic> json) {
    return TactileSignal(
      signalId: '${json['signalId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      immediacy: _parseDouble(json['immediacy']) ?? 0.0,
    );
  }
}

// 灵觉信号解读
class ManaSignalInsight {
  const ManaSignalInsight({
    this.estimatedRealm,
    this.estimatedTechnique,
    this.threatLevel = 0.0,
    this.isHostile,
    this.isConcealed,
    this.additionalInfo = '',
  });

  final String? estimatedRealm;
  final String? estimatedTechnique;
  final double threatLevel;
  final bool? isHostile;
  final bool? isConcealed;
  final String additionalInfo;

  ManaSignalInsight copyWith({
    String? estimatedRealm,
    bool clearEstimatedRealm = false,
    String? estimatedTechnique,
    bool clearEstimatedTechnique = false,
    double? threatLevel,
    bool? isHostile,
    bool clearIsHostile = false,
    bool? isConcealed,
    bool clearIsConcealed = false,
    String? additionalInfo,
  }) {
    return ManaSignalInsight(
      estimatedRealm: clearEstimatedRealm ? null : (estimatedRealm ?? this.estimatedRealm),
      estimatedTechnique: clearEstimatedTechnique ? null : (estimatedTechnique ?? this.estimatedTechnique),
      threatLevel: threatLevel ?? this.threatLevel,
      isHostile: clearIsHostile ? null : (isHostile ?? this.isHostile),
      isConcealed: clearIsConcealed ? null : (isConcealed ?? this.isConcealed),
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'estimatedRealm': estimatedRealm,
      'estimatedTechnique': estimatedTechnique,
      'threatLevel': threatLevel,
      'isHostile': isHostile,
      'isConcealed': isConcealed,
      'additionalInfo': additionalInfo,
    };
  }

  factory ManaSignalInsight.fromJson(Map<String, dynamic> json) {
    return ManaSignalInsight(
      estimatedRealm: _normalizeOptional(json['estimatedRealm']),
      estimatedTechnique: _normalizeOptional(json['estimatedTechnique']),
      threatLevel: _parseDouble(json['threatLevel']) ?? 0.0,
      isHostile: _parseBool(json['isHostile']),
      isConcealed: _parseBool(json['isConcealed']),
      additionalInfo: '${json['additionalInfo'] ?? ''}',
    );
  }
}

// 灵觉信号
class ManaSignal {
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

  ManaSignal copyWith({
    String? signalId,
    String? content,
    ManaSourceType? sourceType,
    double? perceivedIntensity,
    ManaAttribute? attribute,
    double? clarity,
    String? direction,
    double? estimatedDistance,
    bool clearEstimatedDistance = false,
    double? perceivedStability,
    ManaFreshness? freshness,
    String? associatedEntityId,
    bool clearAssociatedEntityId = false,
    ManaSignalInsight? insight,
    bool clearInsight = false,
    String? notes,
  }) {
    return ManaSignal(
      signalId: signalId ?? this.signalId,
      content: content ?? this.content,
      sourceType: sourceType ?? this.sourceType,
      perceivedIntensity: perceivedIntensity ?? this.perceivedIntensity,
      attribute: attribute ?? this.attribute,
      clarity: clarity ?? this.clarity,
      direction: direction ?? this.direction,
      estimatedDistance: clearEstimatedDistance ? null : (estimatedDistance ?? this.estimatedDistance),
      perceivedStability: perceivedStability ?? this.perceivedStability,
      freshness: freshness ?? this.freshness,
      associatedEntityId: clearAssociatedEntityId ? null : (associatedEntityId ?? this.associatedEntityId),
      insight: clearInsight ? null : (insight ?? this.insight),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'signalId': signalId,
      'content': content,
      'sourceType': sourceType.wireValue,
      'perceivedIntensity': perceivedIntensity,
      'attribute': attribute.wireValue,
      'clarity': clarity,
      'direction': direction,
      'estimatedDistance': estimatedDistance,
      'perceivedStability': perceivedStability,
      'freshness': freshness.wireValue,
      'associatedEntityId': associatedEntityId,
      'insight': insight?.toJson(),
      'notes': notes,
    };
  }

  factory ManaSignal.fromJson(Map<String, dynamic> json) {
    return ManaSignal(
      signalId: '${json['signalId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      sourceType: manaSourceTypeFromWire(json['sourceType']),
      perceivedIntensity: _parseDouble(json['perceivedIntensity']) ?? 0.0,
      attribute: manaAttributeFromWire(json['attribute']),
      clarity: _parseDouble(json['clarity']) ?? 0.0,
      direction: '${json['direction'] ?? ''}',
      estimatedDistance: _parseDouble(json['estimatedDistance']),
      perceivedStability: _parseDouble(json['perceivedStability']) ?? 1.0,
      freshness: manaFreshnessFromWire(json['freshness']),
      associatedEntityId: _normalizeOptional(json['associatedEntityId']),
      insight: json['insight'] != null
          ? ManaSignalInsight.fromJson(Map<String, dynamic>.from(json['insight']))
          : null,
      notes: '${json['notes'] ?? ''}',
    );
  }
}

// 灵觉环境感知
class ManaEnvironmentSense {
  const ManaEnvironmentSense({
    this.perceivedDensity = 0.5,
    this.dominantAttribute = ManaAttribute.neutral,
    this.suitableForCultivation = true,
    this.hasAnomaly = false,
    this.anomalyDescription = '',
    this.flowDescription,
    this.convergencePoints = const [],
  });

  final double perceivedDensity;
  final ManaAttribute dominantAttribute;
  final bool suitableForCultivation;
  final bool hasAnomaly;
  final String anomalyDescription;
  final String? flowDescription;
  final List<String> convergencePoints;

  ManaEnvironmentSense copyWith({
    double? perceivedDensity,
    ManaAttribute? dominantAttribute,
    bool? suitableForCultivation,
    bool? hasAnomaly,
    String? anomalyDescription,
    String? flowDescription,
    bool clearFlowDescription = false,
    List<String>? convergencePoints,
  }) {
    return ManaEnvironmentSense(
      perceivedDensity: perceivedDensity ?? this.perceivedDensity,
      dominantAttribute: dominantAttribute ?? this.dominantAttribute,
      suitableForCultivation: suitableForCultivation ?? this.suitableForCultivation,
      hasAnomaly: hasAnomaly ?? this.hasAnomaly,
      anomalyDescription: anomalyDescription ?? this.anomalyDescription,
      flowDescription: clearFlowDescription ? null : (flowDescription ?? this.flowDescription),
      convergencePoints: convergencePoints ?? this.convergencePoints,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'perceivedDensity': perceivedDensity,
      'dominantAttribute': dominantAttribute.wireValue,
      'suitableForCultivation': suitableForCultivation,
      'hasAnomaly': hasAnomaly,
      'anomalyDescription': anomalyDescription,
      'flowDescription': flowDescription,
      'convergencePoints': convergencePoints,
    };
  }

  factory ManaEnvironmentSense.fromJson(Map<String, dynamic> json) {
    return ManaEnvironmentSense(
      perceivedDensity: _parseDouble(json['perceivedDensity']) ?? 0.5,
      dominantAttribute: manaAttributeFromWire(json['dominantAttribute']),
      suitableForCultivation: _parseBool(json['suitableForCultivation']) ?? true,
      hasAnomaly: _parseBool(json['hasAnomaly']) ?? false,
      anomalyDescription: '${json['anomalyDescription'] ?? ''}',
      flowDescription: _normalizeOptional(json['flowDescription']),
      convergencePoints: _parseStringList(json['convergencePoints']),
    );
  }
}

// 空间上下文
class SpatialContext {
  const SpatialContext({
    this.reachableAreas = const [],
    this.nearbyObstacles = const [],
  });

  final List<String> reachableAreas;
  final List<String> nearbyObstacles;

  SpatialContext copyWith({
    List<String>? reachableAreas,
    List<String>? nearbyObstacles,
  }) {
    return SpatialContext(
      reachableAreas: reachableAreas ?? this.reachableAreas,
      nearbyObstacles: nearbyObstacles ?? this.nearbyObstacles,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reachableAreas': reachableAreas,
      'nearbyObstacles': nearbyObstacles,
    };
  }

  factory SpatialContext.fromJson(Map<String, dynamic> json) {
    return SpatialContext(
      reachableAreas: _parseStringList(json['reachableAreas']),
      nearbyObstacles: _parseStringList(json['nearbyObstacles']),
    );
  }
}

// 过滤场景视图
class FilteredSceneView {
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

  final String characterId;
  final String sceneTurnId;
  final List<VisibleEntity> visibleEntities;
  final List<AudibleSignal> audibleSignals;
  final List<OlfactorySignal> olfactorySignals;
  final List<TactileSignal> tactileSignals;
  final List<ManaSignal> manaSignals;
  final ManaEnvironmentSense manaEnvironment;
  final SpatialContext spatialContext;

  FilteredSceneView copyWith({
    String? characterId,
    String? sceneTurnId,
    List<VisibleEntity>? visibleEntities,
    List<AudibleSignal>? audibleSignals,
    List<OlfactorySignal>? olfactorySignals,
    List<TactileSignal>? tactileSignals,
    List<ManaSignal>? manaSignals,
    ManaEnvironmentSense? manaEnvironment,
    SpatialContext? spatialContext,
  }) {
    return FilteredSceneView(
      characterId: characterId ?? this.characterId,
      sceneTurnId: sceneTurnId ?? this.sceneTurnId,
      visibleEntities: visibleEntities ?? this.visibleEntities,
      audibleSignals: audibleSignals ?? this.audibleSignals,
      olfactorySignals: olfactorySignals ?? this.olfactorySignals,
      tactileSignals: tactileSignals ?? this.tactileSignals,
      manaSignals: manaSignals ?? this.manaSignals,
      manaEnvironment: manaEnvironment ?? this.manaEnvironment,
      spatialContext: spatialContext ?? this.spatialContext,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'sceneTurnId': sceneTurnId,
      'visibleEntities': visibleEntities.map((e) => e.toJson()).toList(),
      'audibleSignals': audibleSignals.map((e) => e.toJson()).toList(),
      'olfactorySignals': olfactorySignals.map((e) => e.toJson()).toList(),
      'tactileSignals': tactileSignals.map((e) => e.toJson()).toList(),
      'manaSignals': manaSignals.map((e) => e.toJson()).toList(),
      'manaEnvironment': manaEnvironment.toJson(),
      'spatialContext': spatialContext.toJson(),
    };
  }

  factory FilteredSceneView.fromJson(Map<String, dynamic> json) {
    return FilteredSceneView(
      characterId: '${json['characterId'] ?? ''}',
      sceneTurnId: '${json['sceneTurnId'] ?? ''}',
      visibleEntities: _parseList(json['visibleEntities'], VisibleEntity.fromJson),
      audibleSignals: _parseList(json['audibleSignals'], AudibleSignal.fromJson),
      olfactorySignals: _parseList(json['olfactorySignals'], OlfactorySignal.fromJson),
      tactileSignals: _parseList(json['tactileSignals'], TactileSignal.fromJson),
      manaSignals: _parseList(json['manaSignals'], ManaSignal.fromJson),
      manaEnvironment: ManaEnvironmentSense.fromJson(json['manaEnvironment'] ?? <String, dynamic>{}),
      spatialContext: SpatialContext.fromJson(json['spatialContext'] ?? <String, dynamic>{}),
    );
  }
}

// Helper functions
String? _normalizeOptional(Object? raw) {
  final normalized = '$raw'.trim();
  if (normalized.isEmpty || normalized == 'null') return null;
  return normalized;
}

bool? _parseBool(Object? raw) {
  if (raw is bool) return raw;
  final normalized = '$raw'.trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}

double? _parseDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
}

List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
