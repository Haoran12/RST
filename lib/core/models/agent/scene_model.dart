import 'mana_field.dart';

// 场景类型
enum SceneType {
  room('room', '室内'),
  street('street', '街道'),
  forest('forest', '森林'),
  courtyard('courtyard', '庭院'),
  cave('cave', '洞穴'),
  hallway('hallway', '走廊'),
  unknown('unknown', '未知');

  const SceneType(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

SceneType sceneTypeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'room' => SceneType.room,
    'street' => SceneType.street,
    'forest' => SceneType.forest,
    'courtyard' => SceneType.courtyard,
    'cave' => SceneType.cave,
    'hallway' => SceneType.hallway,
    _ => SceneType.unknown,
  };
}

// 障碍物类型
enum ObstacleType {
  wall('wall', '墙壁'),
  screen('screen', '屏风'),
  table('table', '桌子'),
  curtain('curtain', '帘幕'),
  tree('tree', '树木'),
  crowd('crowd', '人群'),
  furniture('furniture', '家具'),
  terrain('terrain', '地形');

  const ObstacleType(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

ObstacleType obstacleTypeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'wall' => ObstacleType.wall,
    'screen' => ObstacleType.screen,
    'table' => ObstacleType.table,
    'curtain' => ObstacleType.curtain,
    'tree' => ObstacleType.tree,
    'crowd' => ObstacleType.crowd,
    'furniture' => ObstacleType.furniture,
    'terrain' => ObstacleType.terrain,
    _ => ObstacleType.furniture,
  };
}

// 光照等级
enum LightingLevel {
  bright('bright', '明亮'),
  normal('normal', '正常'),
  dim('dim', '昏暗'),
  veryDim('very_dim', '很暗'),
  dark('dark', '黑暗');

  const LightingLevel(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

LightingLevel lightingLevelFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'bright' => LightingLevel.bright,
    'normal' => LightingLevel.normal,
    'dim' => LightingLevel.dim,
    'very_dim' || 'verydim' => LightingLevel.veryDim,
    'dark' => LightingLevel.dark,
    _ => LightingLevel.normal,
  };
}

// 声学反射质量
enum ReflectiveQuality {
  open('open', '开阔'),
  muffled('muffled', '沉闷'),
  echoing('echoing', '回声'),
  enclosed('enclosed', '封闭'),
  mixed('mixed', '混合');

  const ReflectiveQuality(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

ReflectiveQuality reflectiveQualityFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'open' => ReflectiveQuality.open,
    'muffled' => ReflectiveQuality.muffled,
    'echoing' => ReflectiveQuality.echoing,
    'enclosed' => ReflectiveQuality.enclosed,
    'mixed' => ReflectiveQuality.mixed,
    _ => ReflectiveQuality.open,
  };
}

// 气味类型
enum OdorType {
  blood('blood', '血腥'),
  medicine('medicine', '药味'),
  incense('incense', '香火'),
  rot('rot', '腐烂'),
  soil('soil', '泥土'),
  alcohol('alcohol', '酒气'),
  sweat('sweat', '汗味'),
  flower('flower', '花香'),
  smoke('smoke', '烟味'),
  metal('metal', '金属'),
  unknown('unknown', '未知');

  const OdorType(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

OdorType odorTypeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'blood' => OdorType.blood,
    'medicine' => OdorType.medicine,
    'incense' => OdorType.incense,
    'rot' => OdorType.rot,
    'soil' => OdorType.soil,
    'alcohol' => OdorType.alcohol,
    'sweat' => OdorType.sweat,
    'flower' => OdorType.flower,
    'smoke' => OdorType.smoke,
    'metal' => OdorType.metal,
    _ => OdorType.unknown,
  };
}

// 气味新鲜度
enum OdorFreshness {
  fresh('fresh', '新鲜'),
  recent('recent', '近期'),
  old('old', '陈旧'),
  unknown('unknown', '未知');

  const OdorFreshness(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

OdorFreshness odorFreshnessFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'fresh' => OdorFreshness.fresh,
    'recent' => OdorFreshness.recent,
    'old' => OdorFreshness.old,
    _ => OdorFreshness.unknown,
  };
}

// 气流强度
enum AirflowStrength {
  still('still', '静止'),
  weak('weak', '微弱'),
  flowing('flowing', '流动'),
  gusty('gusty', '阵风'),
  variable('variable', '多变');

  const AirflowStrength(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

AirflowStrength airflowStrengthFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'still' => AirflowStrength.still,
    'weak' => AirflowStrength.weak,
    'flowing' => AirflowStrength.flowing,
    'gusty' => AirflowStrength.gusty,
    'variable' => AirflowStrength.variable,
    _ => AirflowStrength.still,
  };
}

// 时间上下文
class TimeContext {
  const TimeContext({
    required this.timeOfDay,
    required this.weather,
    required this.visibilityCondition,
    this.ambientContextNotes = const [],
  });

  final String timeOfDay;
  final String weather;
  final String visibilityCondition;
  final List<String> ambientContextNotes;

  TimeContext copyWith({
    String? timeOfDay,
    String? weather,
    String? visibilityCondition,
    List<String>? ambientContextNotes,
  }) {
    return TimeContext(
      timeOfDay: timeOfDay ?? this.timeOfDay,
      weather: weather ?? this.weather,
      visibilityCondition: visibilityCondition ?? this.visibilityCondition,
      ambientContextNotes: ambientContextNotes ?? this.ambientContextNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timeOfDay': timeOfDay,
      'weather': weather,
      'visibilityCondition': visibilityCondition,
      'ambientContextNotes': ambientContextNotes,
    };
  }

  factory TimeContext.fromJson(Map<String, dynamic> json) {
    return TimeContext(
      timeOfDay: '${json['timeOfDay'] ?? ''}',
      weather: '${json['weather'] ?? ''}',
      visibilityCondition: '${json['visibilityCondition'] ?? ''}',
      ambientContextNotes: _parseStringList(json['ambientContextNotes']),
    );
  }
}

// 入口点
class EntryPoint {
  const EntryPoint({
    required this.entryPointId,
    required this.location,
    required this.direction,
  });

  final String entryPointId;
  final String location;
  final String direction;

  EntryPoint copyWith({
    String? entryPointId,
    String? location,
    String? direction,
  }) {
    return EntryPoint(
      entryPointId: entryPointId ?? this.entryPointId,
      location: location ?? this.location,
      direction: direction ?? this.direction,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entryPointId': entryPointId,
      'location': location,
      'direction': direction,
    };
  }

  factory EntryPoint.fromJson(Map<String, dynamic> json) {
    return EntryPoint(
      entryPointId: '${json['entryPointId'] ?? ''}',
      location: '${json['location'] ?? ''}',
      direction: '${json['direction'] ?? ''}',
    );
  }
}

// 子区域
class SubArea {
  const SubArea({
    required this.subAreaId,
    required this.name,
    required this.location,
  });

  final String subAreaId;
  final String name;
  final String location;

  SubArea copyWith({
    String? subAreaId,
    String? name,
    String? location,
  }) {
    return SubArea(
      subAreaId: subAreaId ?? this.subAreaId,
      name: name ?? this.name,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'subAreaId': subAreaId,
      'name': name,
      'location': location,
    };
  }

  factory SubArea.fromJson(Map<String, dynamic> json) {
    return SubArea(
      subAreaId: '${json['subAreaId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      location: '${json['location'] ?? ''}',
    );
  }
}

// 障碍物
class Obstacle {
  const Obstacle({
    required this.id,
    required this.type,
    required this.location,
    this.blocksVision = false,
    this.blocksSound = false,
    this.blocksSmell = false,
    this.blocksMovement = false,
  });

  final String id;
  final ObstacleType type;
  final String location;
  final bool blocksVision;
  final bool blocksSound;
  final bool blocksSmell;
  final bool blocksMovement;

  Obstacle copyWith({
    String? id,
    ObstacleType? type,
    String? location,
    bool? blocksVision,
    bool? blocksSound,
    bool? blocksSmell,
    bool? blocksMovement,
  }) {
    return Obstacle(
      id: id ?? this.id,
      type: type ?? this.type,
      location: location ?? this.location,
      blocksVision: blocksVision ?? this.blocksVision,
      blocksSound: blocksSound ?? this.blocksSound,
      blocksSmell: blocksSmell ?? this.blocksSmell,
      blocksMovement: blocksMovement ?? this.blocksMovement,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.wireValue,
      'location': location,
      'blocksVision': blocksVision,
      'blocksSound': blocksSound,
      'blocksSmell': blocksSmell,
      'blocksMovement': blocksMovement,
    };
  }

  factory Obstacle.fromJson(Map<String, dynamic> json) {
    return Obstacle(
      id: '${json['id'] ?? ''}',
      type: obstacleTypeFromWire(json['type']),
      location: '${json['location'] ?? ''}',
      blocksVision: _parseBool(json['blocksVision']) ?? false,
      blocksSound: _parseBool(json['blocksSound']) ?? false,
      blocksSmell: _parseBool(json['blocksSmell']) ?? false,
      blocksMovement: _parseBool(json['blocksMovement']) ?? false,
    );
  }
}

// 空间布局
class SpatialLayout {
  const SpatialLayout({
    required this.sceneType,
    required this.dimensionsEstimate,
    this.subareas = const [],
    this.obstacles = const [],
    this.entryPoints = const [],
  });

  final SceneType sceneType;
  final String dimensionsEstimate;
  final List<SubArea> subareas;
  final List<Obstacle> obstacles;
  final List<EntryPoint> entryPoints;

  SpatialLayout copyWith({
    SceneType? sceneType,
    String? dimensionsEstimate,
    List<SubArea>? subareas,
    List<Obstacle>? obstacles,
    List<EntryPoint>? entryPoints,
  }) {
    return SpatialLayout(
      sceneType: sceneType ?? this.sceneType,
      dimensionsEstimate: dimensionsEstimate ?? this.dimensionsEstimate,
      subareas: subareas ?? this.subareas,
      obstacles: obstacles ?? this.obstacles,
      entryPoints: entryPoints ?? this.entryPoints,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sceneType': sceneType.wireValue,
      'dimensionsEstimate': dimensionsEstimate,
      'subareas': subareas.map((e) => e.toJson()).toList(),
      'obstacles': obstacles.map((e) => e.toJson()).toList(),
      'entryPoints': entryPoints.map((e) => e.toJson()).toList(),
    };
  }

  factory SpatialLayout.fromJson(Map<String, dynamic> json) {
    return SpatialLayout(
      sceneType: sceneTypeFromWire(json['sceneType']),
      dimensionsEstimate: '${json['dimensionsEstimate'] ?? ''}',
      subareas: _parseList(json['subareas'], SubArea.fromJson),
      obstacles: _parseList(json['obstacles'], Obstacle.fromJson),
      entryPoints: _parseList(json['entryPoints'], EntryPoint.fromJson),
    );
  }
}

// 光源
class LightSource {
  const LightSource({
    required this.sourceId,
    required this.type,
    required this.location,
    required this.intensity,
  });

  final String sourceId;
  final String type;
  final String location;
  final double intensity;

  LightSource copyWith({
    String? sourceId,
    String? type,
    String? location,
    double? intensity,
  }) {
    return LightSource(
      sourceId: sourceId ?? this.sourceId,
      type: type ?? this.type,
      location: location ?? this.location,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'type': type,
      'location': location,
      'intensity': intensity,
    };
  }

  factory LightSource.fromJson(Map<String, dynamic> json) {
    return LightSource(
      sourceId: '${json['sourceId'] ?? ''}',
      type: '${json['type'] ?? ''}',
      location: '${json['location'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 1.0,
    );
  }
}

// 阴影区域
class ShadowZone {
  const ShadowZone({
    required this.zoneId,
    required this.location,
    required this.depth,
  });

  final String zoneId;
  final String location;
  final double depth;

  ShadowZone copyWith({
    String? zoneId,
    String? location,
    double? depth,
  }) {
    return ShadowZone(
      zoneId: zoneId ?? this.zoneId,
      location: location ?? this.location,
      depth: depth ?? this.depth,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'zoneId': zoneId,
      'location': location,
      'depth': depth,
    };
  }

  factory ShadowZone.fromJson(Map<String, dynamic> json) {
    return ShadowZone(
      zoneId: '${json['zoneId'] ?? ''}',
      location: '${json['location'] ?? ''}',
      depth: _parseDouble(json['depth']) ?? 0.5,
    );
  }
}

// 逆光区域
class BacklightZone {
  const BacklightZone({
    required this.zoneId,
    required this.location,
    required this.intensity,
  });

  final String zoneId;
  final String location;
  final double intensity;

  BacklightZone copyWith({
    String? zoneId,
    String? location,
    double? intensity,
  }) {
    return BacklightZone(
      zoneId: zoneId ?? this.zoneId,
      location: location ?? this.location,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'zoneId': zoneId,
      'location': location,
      'intensity': intensity,
    };
  }

  factory BacklightZone.fromJson(Map<String, dynamic> json) {
    return BacklightZone(
      zoneId: '${json['zoneId'] ?? ''}',
      location: '${json['location'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 0.5,
    );
  }
}

// 光照状态
class LightingState {
  const LightingState({
    required this.overallLevel,
    this.sourcePoints = const [],
    this.shadowZones = const [],
    this.backlightZones = const [],
    this.flicker = 0.0,
    this.visualNoise = const [],
  });

  final LightingLevel overallLevel;
  final List<LightSource> sourcePoints;
  final List<ShadowZone> shadowZones;
  final List<BacklightZone> backlightZones;
  final double flicker;
  final List<String> visualNoise;

  LightingState copyWith({
    LightingLevel? overallLevel,
    List<LightSource>? sourcePoints,
    List<ShadowZone>? shadowZones,
    List<BacklightZone>? backlightZones,
    double? flicker,
    List<String>? visualNoise,
  }) {
    return LightingState(
      overallLevel: overallLevel ?? this.overallLevel,
      sourcePoints: sourcePoints ?? this.sourcePoints,
      shadowZones: shadowZones ?? this.shadowZones,
      backlightZones: backlightZones ?? this.backlightZones,
      flicker: flicker ?? this.flicker,
      visualNoise: visualNoise ?? this.visualNoise,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'overallLevel': overallLevel.wireValue,
      'sourcePoints': sourcePoints.map((e) => e.toJson()).toList(),
      'shadowZones': shadowZones.map((e) => e.toJson()).toList(),
      'backlightZones': backlightZones.map((e) => e.toJson()).toList(),
      'flicker': flicker,
      'visualNoise': visualNoise,
    };
  }

  factory LightingState.fromJson(Map<String, dynamic> json) {
    return LightingState(
      overallLevel: lightingLevelFromWire(json['overallLevel']),
      sourcePoints: _parseList(json['sourcePoints'], LightSource.fromJson),
      shadowZones: _parseList(json['shadowZones'], ShadowZone.fromJson),
      backlightZones: _parseList(json['backlightZones'], BacklightZone.fromJson),
      flicker: _parseDouble(json['flicker']) ?? 0.0,
      visualNoise: _parseStringList(json['visualNoise']),
    );
  }
}

// 环境声源
class AmbientSoundSource {
  const AmbientSoundSource({
    required this.sourceId,
    required this.type,
    required this.location,
    required this.volume,
  });

  final String sourceId;
  final String type;
  final String location;
  final double volume;

  AmbientSoundSource copyWith({
    String? sourceId,
    String? type,
    String? location,
    double? volume,
  }) {
    return AmbientSoundSource(
      sourceId: sourceId ?? this.sourceId,
      type: type ?? this.type,
      location: location ?? this.location,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'type': type,
      'location': location,
      'volume': volume,
    };
  }

  factory AmbientSoundSource.fromJson(Map<String, dynamic> json) {
    return AmbientSoundSource(
      sourceId: '${json['sourceId'] ?? ''}',
      type: '${json['type'] ?? ''}',
      location: '${json['location'] ?? ''}',
      volume: _parseDouble(json['volume']) ?? 0.5,
    );
  }
}

// 声学状态
class AcousticsState {
  const AcousticsState({
    required this.ambientNoiseLevel,
    this.ambientSources = const [],
    required this.reflectiveQuality,
  });

  final double ambientNoiseLevel;
  final List<AmbientSoundSource> ambientSources;
  final ReflectiveQuality reflectiveQuality;

  AcousticsState copyWith({
    double? ambientNoiseLevel,
    List<AmbientSoundSource>? ambientSources,
    ReflectiveQuality? reflectiveQuality,
  }) {
    return AcousticsState(
      ambientNoiseLevel: ambientNoiseLevel ?? this.ambientNoiseLevel,
      ambientSources: ambientSources ?? this.ambientSources,
      reflectiveQuality: reflectiveQuality ?? this.reflectiveQuality,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ambientNoiseLevel': ambientNoiseLevel,
      'ambientSources': ambientSources.map((e) => e.toJson()).toList(),
      'reflectiveQuality': reflectiveQuality.wireValue,
    };
  }

  factory AcousticsState.fromJson(Map<String, dynamic> json) {
    return AcousticsState(
      ambientNoiseLevel: _parseDouble(json['ambientNoiseLevel']) ?? 0.5,
      ambientSources: _parseList(json['ambientSources'], AmbientSoundSource.fromJson),
      reflectiveQuality: reflectiveQualityFromWire(json['reflectiveQuality']),
    );
  }
}

// 气流
class Airflow {
  const Airflow({
    required this.strength,
    required this.direction,
  });

  final AirflowStrength strength;
  final String direction;

  Airflow copyWith({
    AirflowStrength? strength,
    String? direction,
  }) {
    return Airflow(
      strength: strength ?? this.strength,
      direction: direction ?? this.direction,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'strength': strength.wireValue,
      'direction': direction,
    };
  }

  factory Airflow.fromJson(Map<String, dynamic> json) {
    return Airflow(
      strength: airflowStrengthFromWire(json['strength']),
      direction: '${json['direction'] ?? ''}',
    );
  }
}

// 气味源
class OdorSource {
  const OdorSource({
    required this.id,
    required this.type,
    required this.intensity,
    required this.freshness,
    required this.spreadRange,
    required this.sourcePosition,
  });

  final String id;
  final OdorType type;
  final double intensity;
  final OdorFreshness freshness;
  final double spreadRange;
  final String sourcePosition;

  OdorSource copyWith({
    String? id,
    OdorType? type,
    double? intensity,
    OdorFreshness? freshness,
    double? spreadRange,
    String? sourcePosition,
  }) {
    return OdorSource(
      id: id ?? this.id,
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
      freshness: freshness ?? this.freshness,
      spreadRange: spreadRange ?? this.spreadRange,
      sourcePosition: sourcePosition ?? this.sourcePosition,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.wireValue,
      'intensity': intensity,
      'freshness': freshness.wireValue,
      'spreadRange': spreadRange,
      'sourcePosition': sourcePosition,
    };
  }

  factory OdorSource.fromJson(Map<String, dynamic> json) {
    return OdorSource(
      id: '${json['id'] ?? ''}',
      type: odorTypeFromWire(json['type']),
      intensity: _parseDouble(json['intensity']) ?? 0.5,
      freshness: odorFreshnessFromWire(json['freshness']),
      spreadRange: _parseDouble(json['spreadRange']) ?? 1.0,
      sourcePosition: '${json['sourcePosition'] ?? ''}',
    );
  }
}

// 嗅觉场
class OlfactoryField {
  const OlfactoryField({
    required this.overallDensity,
    required this.airflow,
    this.odorSources = const [],
    this.interferingOdors = const [],
  });

  final double overallDensity;
  final Airflow airflow;
  final List<OdorSource> odorSources;
  final List<String> interferingOdors;

  OlfactoryField copyWith({
    double? overallDensity,
    Airflow? airflow,
    List<OdorSource>? odorSources,
    List<String>? interferingOdors,
  }) {
    return OlfactoryField(
      overallDensity: overallDensity ?? this.overallDensity,
      airflow: airflow ?? this.airflow,
      odorSources: odorSources ?? this.odorSources,
      interferingOdors: interferingOdors ?? this.interferingOdors,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'overallDensity': overallDensity,
      'airflow': airflow.toJson(),
      'odorSources': odorSources.map((e) => e.toJson()).toList(),
      'interferingOdors': interferingOdors,
    };
  }

  factory OlfactoryField.fromJson(Map<String, dynamic> json) {
    return OlfactoryField(
      overallDensity: _parseDouble(json['overallDensity']) ?? 0.5,
      airflow: Airflow.fromJson(json['airflow'] ?? <String, dynamic>{}),
      odorSources: _parseList(json['odorSources'], OdorSource.fromJson),
      interferingOdors: _parseStringList(json['interferingOdors']),
    );
  }
}

// 场景实体
class SceneEntity {
  const SceneEntity({
    required this.entityId,
    required this.type,
    required this.location,
    required this.state,
    this.attributes = const {},
  });

  final String entityId;
  final String type;
  final String location;
  final String state;
  final Map<String, dynamic> attributes;

  SceneEntity copyWith({
    String? entityId,
    String? type,
    String? location,
    String? state,
    Map<String, dynamic>? attributes,
  }) {
    return SceneEntity(
      entityId: entityId ?? this.entityId,
      type: type ?? this.type,
      location: location ?? this.location,
      state: state ?? this.state,
      attributes: attributes ?? this.attributes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entityId': entityId,
      'type': type,
      'location': location,
      'state': state,
      'attributes': attributes,
    };
  }

  factory SceneEntity.fromJson(Map<String, dynamic> json) {
    return SceneEntity(
      entityId: '${json['entityId'] ?? ''}',
      type: '${json['type'] ?? ''}',
      location: '${json['location'] ?? ''}',
      state: '${json['state'] ?? ''}',
      attributes: Map<String, dynamic>.from(json['attributes'] ?? <String, dynamic>{}),
    );
  }
}

// 可观察信号
class ObservableSignal {
  const ObservableSignal({
    required this.signalId,
    required this.type,
    required this.content,
    required this.location,
    required this.intensity,
    this.targetEntityIds = const [],
  });

  final String signalId;
  final String type;
  final String content;
  final String location;
  final double intensity;
  final List<String> targetEntityIds;

  ObservableSignal copyWith({
    String? signalId,
    String? type,
    String? content,
    String? location,
    double? intensity,
    List<String>? targetEntityIds,
  }) {
    return ObservableSignal(
      signalId: signalId ?? this.signalId,
      type: type ?? this.type,
      content: content ?? this.content,
      location: location ?? this.location,
      intensity: intensity ?? this.intensity,
      targetEntityIds: targetEntityIds ?? this.targetEntityIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'signalId': signalId,
      'type': type,
      'content': content,
      'location': location,
      'intensity': intensity,
      'targetEntityIds': targetEntityIds,
    };
  }

  factory ObservableSignal.fromJson(Map<String, dynamic> json) {
    return ObservableSignal(
      signalId: '${json['signalId'] ?? ''}',
      type: '${json['type'] ?? ''}',
      content: '${json['content'] ?? ''}',
      location: '${json['location'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 0.5,
      targetEntityIds: _parseStringList(json['targetEntityIds']),
    );
  }
}

// 场景事件
class SceneEvent {
  const SceneEvent({
    required this.eventId,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.location,
    this.involvedEntityIds = const [],
  });

  final String eventId;
  final String type;
  final String description;
  final String timestamp;
  final String location;
  final List<String> involvedEntityIds;

  SceneEvent copyWith({
    String? eventId,
    String? type,
    String? description,
    String? timestamp,
    String? location,
    List<String>? involvedEntityIds,
  }) {
    return SceneEvent(
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      involvedEntityIds: involvedEntityIds ?? this.involvedEntityIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'eventId': eventId,
      'type': type,
      'description': description,
      'timestamp': timestamp,
      'location': location,
      'involvedEntityIds': involvedEntityIds,
    };
  }

  factory SceneEvent.fromJson(Map<String, dynamic> json) {
    return SceneEvent(
      eventId: '${json['eventId'] ?? ''}',
      type: '${json['type'] ?? ''}',
      description: '${json['description'] ?? ''}',
      timestamp: '${json['timestamp'] ?? ''}',
      location: '${json['location'] ?? ''}',
      involvedEntityIds: _parseStringList(json['involvedEntityIds']),
    );
  }
}

// 可观察性约束
class ObservabilityConstraint {
  const ObservabilityConstraint({
    required this.constraintId,
    required this.type,
    required this.description,
    required this.affectedEntityIds,
  });

  final String constraintId;
  final String type;
  final String description;
  final List<String> affectedEntityIds;

  ObservabilityConstraint copyWith({
    String? constraintId,
    String? type,
    String? description,
    List<String>? affectedEntityIds,
  }) {
    return ObservabilityConstraint(
      constraintId: constraintId ?? this.constraintId,
      type: type ?? this.type,
      description: description ?? this.description,
      affectedEntityIds: affectedEntityIds ?? this.affectedEntityIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'constraintId': constraintId,
      'type': type,
      'description': description,
      'affectedEntityIds': affectedEntityIds,
    };
  }

  factory ObservabilityConstraint.fromJson(Map<String, dynamic> json) {
    return ObservabilityConstraint(
      constraintId: '${json['constraintId'] ?? ''}',
      type: '${json['type'] ?? ''}',
      description: '${json['description'] ?? ''}',
      affectedEntityIds: _parseStringList(json['affectedEntityIds']),
    );
  }
}

// 场景模型
class SceneModel {
  const SceneModel({
    required this.sceneId,
    required this.sceneTurnId,
    required this.timeContext,
    required this.spatialLayout,
    required this.lighting,
    required this.acoustics,
    required this.olfactoryField,
    this.manaField,
    this.entities = const [],
    this.observableSignals = const [],
    this.eventStream = const [],
    this.observabilityConstraints = const [],
    this.uncertaintyNotes = const [],
  });

  final String sceneId;
  final String sceneTurnId;
  final TimeContext timeContext;
  final SpatialLayout spatialLayout;
  final LightingState lighting;
  final AcousticsState acoustics;
  final OlfactoryField olfactoryField;
  final ManaField? manaField;
  final List<SceneEntity> entities;
  final List<ObservableSignal> observableSignals;
  final List<SceneEvent> eventStream;
  final List<ObservabilityConstraint> observabilityConstraints;
  final List<String> uncertaintyNotes;

  SceneModel copyWith({
    String? sceneId,
    String? sceneTurnId,
    TimeContext? timeContext,
    SpatialLayout? spatialLayout,
    LightingState? lighting,
    AcousticsState? acoustics,
    OlfactoryField? olfactoryField,
    ManaField? manaField,
    bool clearManaField = false,
    List<SceneEntity>? entities,
    List<ObservableSignal>? observableSignals,
    List<SceneEvent>? eventStream,
    List<ObservabilityConstraint>? observabilityConstraints,
    List<String>? uncertaintyNotes,
  }) {
    return SceneModel(
      sceneId: sceneId ?? this.sceneId,
      sceneTurnId: sceneTurnId ?? this.sceneTurnId,
      timeContext: timeContext ?? this.timeContext,
      spatialLayout: spatialLayout ?? this.spatialLayout,
      lighting: lighting ?? this.lighting,
      acoustics: acoustics ?? this.acoustics,
      olfactoryField: olfactoryField ?? this.olfactoryField,
      manaField: clearManaField ? null : (manaField ?? this.manaField),
      entities: entities ?? this.entities,
      observableSignals: observableSignals ?? this.observableSignals,
      eventStream: eventStream ?? this.eventStream,
      observabilityConstraints: observabilityConstraints ?? this.observabilityConstraints,
      uncertaintyNotes: uncertaintyNotes ?? this.uncertaintyNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sceneId': sceneId,
      'sceneTurnId': sceneTurnId,
      'timeContext': timeContext.toJson(),
      'spatialLayout': spatialLayout.toJson(),
      'lighting': lighting.toJson(),
      'acoustics': acoustics.toJson(),
      'olfactoryField': olfactoryField.toJson(),
      'manaField': manaField?.toJson(),
      'entities': entities.map((e) => e.toJson()).toList(),
      'observableSignals': observableSignals.map((e) => e.toJson()).toList(),
      'eventStream': eventStream.map((e) => e.toJson()).toList(),
      'observabilityConstraints': observabilityConstraints.map((e) => e.toJson()).toList(),
      'uncertaintyNotes': uncertaintyNotes,
    };
  }

  factory SceneModel.fromJson(Map<String, dynamic> json) {
    return SceneModel(
      sceneId: '${json['sceneId'] ?? ''}',
      sceneTurnId: '${json['sceneTurnId'] ?? ''}',
      timeContext: TimeContext.fromJson(json['timeContext'] ?? <String, dynamic>{}),
      spatialLayout: SpatialLayout.fromJson(json['spatialLayout'] ?? <String, dynamic>{}),
      lighting: LightingState.fromJson(json['lighting'] ?? <String, dynamic>{}),
      acoustics: AcousticsState.fromJson(json['acoustics'] ?? <String, dynamic>{}),
      olfactoryField: OlfactoryField.fromJson(json['olfactoryField'] ?? <String, dynamic>{}),
      manaField: json['manaField'] != null
          ? ManaField.fromJson(Map<String, dynamic>.from(json['manaField']))
          : null,
      entities: _parseList(json['entities'], SceneEntity.fromJson),
      observableSignals: _parseList(json['observableSignals'], ObservableSignal.fromJson),
      eventStream: _parseList(json['eventStream'], SceneEvent.fromJson),
      observabilityConstraints: _parseList(json['observabilityConstraints'], ObservabilityConstraint.fromJson),
      uncertaintyNotes: _parseStringList(json['uncertaintyNotes']),
    );
  }
}

// Helper functions
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

bool? _parseBool(Object? raw) {
  if (raw is bool) return raw;
  final normalized = '$raw'.trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}

double? _parseDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}
