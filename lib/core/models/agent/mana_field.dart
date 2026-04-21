// 灵气属性
enum ManaAttribute {
  neutral('neutral', '中性'),
  wood('wood', '木灵气'),
  fire('fire', '火灵气'),
  earth('earth', '土灵气'),
  metal('metal', '金灵气'),
  water('water', '水灵气'),
  yin('yin', '阴气'),
  yang('yang', '阳气'),
  mixed('mixed', '混杂'),
  corrupt('corrupt', '污染'),
  divine('divine', '神力');

  const ManaAttribute(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

ManaAttribute manaAttributeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'neutral' => ManaAttribute.neutral,
    'wood' => ManaAttribute.wood,
    'fire' => ManaAttribute.fire,
    'earth' => ManaAttribute.earth,
    'metal' => ManaAttribute.metal,
    'water' => ManaAttribute.water,
    'yin' => ManaAttribute.yin,
    'yang' => ManaAttribute.yang,
    'mixed' => ManaAttribute.mixed,
    'corrupt' => ManaAttribute.corrupt,
    'divine' => ManaAttribute.divine,
    _ => ManaAttribute.neutral,
  };
}

// 灵力源点类型
enum ManaSourceType {
  spiritVein('spirit_vein', '灵脉节点'),
  formationCore('formation_core', '阵法核心'),
  barrierNode('barrier_node', '结界节点'),
  spiritWell('spirit_well', '灵井'),
  cultivatorAura('cultivator_aura', '修士气息'),
  artifactAura('artifact_aura', '法宝威能'),
  spiritBeastAura('spirit_beast_aura', '妖兽气息'),
  formationTrace('formation_trace', '阵法残留'),
  spellResidue('spell_residue', '法术残留'),
  breakthrough('breakthrough', '突破波动'),
  tribulation('tribulation', '天劫气息'),
  sacrifice('sacrifice', '献祭痕迹'),
  corruption('corruption', '污染源'),
  seal('seal', '封印'),
  voidRift('void_rift', '虚空裂缝');

  const ManaSourceType(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

ManaSourceType manaSourceTypeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'spirit_vein' || 'spiritvein' => ManaSourceType.spiritVein,
    'formation_core' || 'formationcore' => ManaSourceType.formationCore,
    'barrier_node' || 'barriernode' => ManaSourceType.barrierNode,
    'spirit_well' || 'spiritwell' => ManaSourceType.spiritWell,
    'cultivator_aura' || 'cultivatoraura' => ManaSourceType.cultivatorAura,
    'artifact_aura' || 'artifactaura' => ManaSourceType.artifactAura,
    'spirit_beast_aura' || 'spiritbeastaura' => ManaSourceType.spiritBeastAura,
    'formation_trace' || 'formationtrace' => ManaSourceType.formationTrace,
    'spell_residue' || 'spellresidue' => ManaSourceType.spellResidue,
    'breakthrough' => ManaSourceType.breakthrough,
    'tribulation' => ManaSourceType.tribulation,
    'sacrifice' => ManaSourceType.sacrifice,
    'corruption' => ManaSourceType.corruption,
    'seal' => ManaSourceType.seal,
    'void_rift' || 'voidrift' => ManaSourceType.voidRift,
    _ => ManaSourceType.cultivatorAura,
  };
}

// 灵力残留新鲜度
enum ManaFreshness {
  active('active', '正在活跃'),
  recent('recent', '刚刚结束'),
  fading('fading', '正在消散'),
  old('old', '陈旧残留'),
  ancient('ancient', '远古痕迹');

  const ManaFreshness(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

ManaFreshness manaFreshnessFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'active' => ManaFreshness.active,
    'recent' => ManaFreshness.recent,
    'fading' => ManaFreshness.fading,
    'old' => ManaFreshness.old,
    'ancient' => ManaFreshness.ancient,
    _ => ManaFreshness.active,
  };
}

// 灵力干扰类型
enum InterferenceType {
  shielding('shielding', '屏蔽'),
  scrambling('scrambling', '扰乱'),
  masking('masking', '伪装'),
  amplifying('amplifying', '放大'),
  redirecting('redirecting', '重定向');

  const InterferenceType(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

InterferenceType interferenceTypeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'shielding' => InterferenceType.shielding,
    'scrambling' => InterferenceType.scrambling,
    'masking' => InterferenceType.masking,
    'amplifying' => InterferenceType.amplifying,
    'redirecting' => InterferenceType.redirecting,
    _ => InterferenceType.shielding,
  };
}

// 灵力涡流
class ManaVortex {
  const ManaVortex({
    required this.vortexId,
    required this.location,
    required this.intensity,
    this.isConverging = true,
    this.radius = 1.0,
  });

  final String vortexId;
  final String location;
  final double intensity;
  final bool isConverging;
  final double radius;

  ManaVortex copyWith({
    String? vortexId,
    String? location,
    double? intensity,
    bool? isConverging,
    double? radius,
  }) {
    return ManaVortex(
      vortexId: vortexId ?? this.vortexId,
      location: location ?? this.location,
      intensity: intensity ?? this.intensity,
      isConverging: isConverging ?? this.isConverging,
      radius: radius ?? this.radius,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'vortexId': vortexId,
      'location': location,
      'intensity': intensity,
      'isConverging': isConverging,
      'radius': radius,
    };
  }

  factory ManaVortex.fromJson(Map<String, dynamic> json) {
    return ManaVortex(
      vortexId: '${json['vortexId'] ?? ''}',
      location: '${json['location'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 0.5,
      isConverging: _parseBool(json['isConverging']) ?? true,
      radius: _parseDouble(json['radius']) ?? 1.0,
    );
  }
}

// 灵力流动
class ManaFlow {
  const ManaFlow({
    this.strength = 0.0,
    this.direction = '',
    this.vortices = const [],
  });

  const ManaFlow.neutral() : this();

  final double strength;
  final String direction;
  final List<ManaVortex> vortices;

  ManaFlow copyWith({
    double? strength,
    String? direction,
    List<ManaVortex>? vortices,
  }) {
    return ManaFlow(
      strength: strength ?? this.strength,
      direction: direction ?? this.direction,
      vortices: vortices ?? this.vortices,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'strength': strength,
      'direction': direction,
      'vortices': vortices.map((e) => e.toJson()).toList(),
    };
  }

  factory ManaFlow.fromJson(Map<String, dynamic> json) {
    return ManaFlow(
      strength: _parseDouble(json['strength']) ?? 0.0,
      direction: '${json['direction'] ?? ''}',
      vortices: _parseList(json['vortices'], ManaVortex.fromJson),
    );
  }
}

// 灵力干扰
class ManaInterference {
  const ManaInterference({
    required this.interferenceId,
    required this.type,
    required this.strength,
    required this.affectedArea,
  });

  final String interferenceId;
  final InterferenceType type;
  final double strength;
  final String affectedArea;

  ManaInterference copyWith({
    String? interferenceId,
    InterferenceType? type,
    double? strength,
    String? affectedArea,
  }) {
    return ManaInterference(
      interferenceId: interferenceId ?? this.interferenceId,
      type: type ?? this.type,
      strength: strength ?? this.strength,
      affectedArea: affectedArea ?? this.affectedArea,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'interferenceId': interferenceId,
      'type': type.wireValue,
      'strength': strength,
      'affectedArea': affectedArea,
    };
  }

  factory ManaInterference.fromJson(Map<String, dynamic> json) {
    return ManaInterference(
      interferenceId: '${json['interferenceId'] ?? ''}',
      type: interferenceTypeFromWire(json['type']),
      strength: _parseDouble(json['strength']) ?? 0.5,
      affectedArea: '${json['affectedArea'] ?? ''}',
    );
  }
}

// 灵力源点
class ManaSource {
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

  final String sourceId;
  final ManaSourceType type;
  final double intensity;
  final ManaAttribute attribute;
  final String location;
  final double spreadRadius;
  final double stability;
  final String? ownerEntityId;
  final ManaFreshness freshness;

  ManaSource copyWith({
    String? sourceId,
    ManaSourceType? type,
    double? intensity,
    ManaAttribute? attribute,
    String? location,
    double? spreadRadius,
    double? stability,
    String? ownerEntityId,
    bool clearOwnerEntityId = false,
    ManaFreshness? freshness,
  }) {
    return ManaSource(
      sourceId: sourceId ?? this.sourceId,
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
      attribute: attribute ?? this.attribute,
      location: location ?? this.location,
      spreadRadius: spreadRadius ?? this.spreadRadius,
      stability: stability ?? this.stability,
      ownerEntityId: clearOwnerEntityId ? null : (ownerEntityId ?? this.ownerEntityId),
      freshness: freshness ?? this.freshness,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'type': type.wireValue,
      'intensity': intensity,
      'attribute': attribute.wireValue,
      'location': location,
      'spreadRadius': spreadRadius,
      'stability': stability,
      'ownerEntityId': ownerEntityId,
      'freshness': freshness.wireValue,
    };
  }

  factory ManaSource.fromJson(Map<String, dynamic> json) {
    return ManaSource(
      sourceId: '${json['sourceId'] ?? ''}',
      type: manaSourceTypeFromWire(json['type']),
      intensity: _parseDouble(json['intensity']) ?? 0.5,
      attribute: manaAttributeFromWire(json['attribute']),
      location: '${json['location'] ?? ''}',
      spreadRadius: _parseDouble(json['spreadRadius']) ?? 1.0,
      stability: _parseDouble(json['stability']) ?? 1.0,
      ownerEntityId: _normalizeOptional(json['ownerEntityId']),
      freshness: manaFreshnessFromWire(json['freshness']),
    );
  }
}

// 灵力场状态
class ManaField {
  const ManaField({
    this.ambientDensity = 0.5,
    this.ambientAttribute = ManaAttribute.neutral,
    this.manaSources = const [],
    this.flow = const ManaFlow.neutral(),
    this.interferences = const [],
  });

  final double ambientDensity;
  final ManaAttribute ambientAttribute;
  final List<ManaSource> manaSources;
  final ManaFlow flow;
  final List<ManaInterference> interferences;

  ManaField copyWith({
    double? ambientDensity,
    ManaAttribute? ambientAttribute,
    List<ManaSource>? manaSources,
    ManaFlow? flow,
    List<ManaInterference>? interferences,
  }) {
    return ManaField(
      ambientDensity: ambientDensity ?? this.ambientDensity,
      ambientAttribute: ambientAttribute ?? this.ambientAttribute,
      manaSources: manaSources ?? this.manaSources,
      flow: flow ?? this.flow,
      interferences: interferences ?? this.interferences,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ambientDensity': ambientDensity,
      'ambientAttribute': ambientAttribute.wireValue,
      'manaSources': manaSources.map((e) => e.toJson()).toList(),
      'flow': flow.toJson(),
      'interferences': interferences.map((e) => e.toJson()).toList(),
    };
  }

  factory ManaField.fromJson(Map<String, dynamic> json) {
    return ManaField(
      ambientDensity: _parseDouble(json['ambientDensity']) ?? 0.5,
      ambientAttribute: manaAttributeFromWire(json['ambientAttribute']),
      manaSources: _parseList(json['manaSources'], ManaSource.fromJson),
      flow: ManaFlow.fromJson(json['flow'] ?? <String, dynamic>{}),
      interferences: _parseList(json['interferences'], ManaInterference.fromJson),
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
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
