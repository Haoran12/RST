import 'mana_field.dart';

// 灵觉特殊能力
enum ManaSenseTrait {
  basicSense('basic_sense', '基础灵觉'),
  auraReading('aura_reading', '气息解读'),
  attributeSense('attribute_sense', '属性感知'),
  traceTracking('trace_tracking', '痕迹追踪'),
  formationInsight('formation_insight', '阵法洞察'),
  soulPerception('soul_perception', '神识探查'),
  hiddenSense('hidden_sense', '隐匿感知'),
  corruptionDetection('corruption_detection', '污染检测'),
  fateSensing('fate_sensing', '天机感应'),
  voidPerception('void_perception', '虚空感知'),
  tribulationSense('tribulation_sense', '劫难感应'),
  bloodlineSense('bloodline_sense', '血脉感应'),
  contractSense('contract_sense', '契约感应'),
  territorySense('territory_sense', '领域感应');

  const ManaSenseTrait(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

ManaSenseTrait manaSenseTraitFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'basic_sense' || 'basicsense' => ManaSenseTrait.basicSense,
    'aura_reading' || 'aurareading' => ManaSenseTrait.auraReading,
    'attribute_sense' || 'attributesense' => ManaSenseTrait.attributeSense,
    'trace_tracking' || 'tracetracking' => ManaSenseTrait.traceTracking,
    'formation_insight' || 'formationinsight' => ManaSenseTrait.formationInsight,
    'soul_perception' || 'soulperception' => ManaSenseTrait.soulPerception,
    'hidden_sense' || 'hiddensense' => ManaSenseTrait.hiddenSense,
    'corruption_detection' || 'corruptiondetection' => ManaSenseTrait.corruptionDetection,
    'fate_sensing' || 'fatesensing' => ManaSenseTrait.fateSensing,
    'void_perception' || 'voidperception' => ManaSenseTrait.voidPerception,
    'tribulation_sense' || 'tribulationsense' => ManaSenseTrait.tribulationSense,
    'bloodline_sense' || 'bloodlinesense' => ManaSenseTrait.bloodlineSense,
    'contract_sense' || 'contractsense' => ManaSenseTrait.contractSense,
    'territory_sense' || 'territorysense' => ManaSenseTrait.territorySense,
    _ => ManaSenseTrait.basicSense,
  };
}

// 感官基线
class SensoryBaseline {
  const SensoryBaseline({
    required this.vision,
    required this.hearing,
    required this.smell,
    required this.touch,
    required this.proprioception,
  });

  final double vision;
  final double hearing;
  final double smell;
  final double touch;
  final double proprioception;

  SensoryBaseline copyWith({
    double? vision,
    double? hearing,
    double? smell,
    double? touch,
    double? proprioception,
  }) {
    return SensoryBaseline(
      vision: vision ?? this.vision,
      hearing: hearing ?? this.hearing,
      smell: smell ?? this.smell,
      touch: touch ?? this.touch,
      proprioception: proprioception ?? this.proprioception,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'vision': vision,
      'hearing': hearing,
      'smell': smell,
      'touch': touch,
      'proprioception': proprioception,
    };
  }

  factory SensoryBaseline.fromJson(Map<String, dynamic> json) {
    return SensoryBaseline(
      vision: _parseDouble(json['vision']) ?? 1.0,
      hearing: _parseDouble(json['hearing']) ?? 1.0,
      smell: _parseDouble(json['smell']) ?? 1.0,
      touch: _parseDouble(json['touch']) ?? 1.0,
      proprioception: _parseDouble(json['proprioception']) ?? 1.0,
    );
  }
}

// 运动基线
class MotorBaseline {
  const MotorBaseline({
    required this.mobility,
    required this.balance,
    required this.stamina,
  });

  final double mobility;
  final double balance;
  final double stamina;

  MotorBaseline copyWith({
    double? mobility,
    double? balance,
    double? stamina,
  }) {
    return MotorBaseline(
      mobility: mobility ?? this.mobility,
      balance: balance ?? this.balance,
      stamina: stamina ?? this.stamina,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mobility': mobility,
      'balance': balance,
      'stamina': stamina,
    };
  }

  factory MotorBaseline.fromJson(Map<String, dynamic> json) {
    return MotorBaseline(
      mobility: _parseDouble(json['mobility']) ?? 1.0,
      balance: _parseDouble(json['balance']) ?? 1.0,
      stamina: _parseDouble(json['stamina']) ?? 1.0,
    );
  }
}

// 认知基线
class CognitionBaseline {
  const CognitionBaseline({
    required this.stressTolerance,
    required this.sensoryOverloadTolerance,
  });

  final double stressTolerance;
  final double sensoryOverloadTolerance;

  CognitionBaseline copyWith({
    double? stressTolerance,
    double? sensoryOverloadTolerance,
  }) {
    return CognitionBaseline(
      stressTolerance: stressTolerance ?? this.stressTolerance,
      sensoryOverloadTolerance: sensoryOverloadTolerance ?? this.sensoryOverloadTolerance,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stressTolerance': stressTolerance,
      'sensoryOverloadTolerance': sensoryOverloadTolerance,
    };
  }

  factory CognitionBaseline.fromJson(Map<String, dynamic> json) {
    return CognitionBaseline(
      stressTolerance: _parseDouble(json['stressTolerance']) ?? 1.0,
      sensoryOverloadTolerance: _parseDouble(json['sensoryOverloadTolerance']) ?? 1.0,
    );
  }
}

// 灵觉基线
class ManaSensoryBaseline {
  const ManaSensoryBaseline({
    this.baseAcuity = 1.0,
    this.realmModifier = 1.0,
    this.speciesModifier = 1.0,
    this.techniqueModifier = 1.0,
    this.attributeAffinity = const {},
    this.traits = const [],
  });

  final double baseAcuity;
  final double realmModifier;
  final double speciesModifier;
  final double techniqueModifier;
  final Map<ManaAttribute, double> attributeAffinity;
  final List<ManaSenseTrait> traits;

  double get effectiveAcuity =>
      baseAcuity * realmModifier * speciesModifier * techniqueModifier;

  ManaSensoryBaseline copyWith({
    double? baseAcuity,
    double? realmModifier,
    double? speciesModifier,
    double? techniqueModifier,
    Map<ManaAttribute, double>? attributeAffinity,
    List<ManaSenseTrait>? traits,
  }) {
    return ManaSensoryBaseline(
      baseAcuity: baseAcuity ?? this.baseAcuity,
      realmModifier: realmModifier ?? this.realmModifier,
      speciesModifier: speciesModifier ?? this.speciesModifier,
      techniqueModifier: techniqueModifier ?? this.techniqueModifier,
      attributeAffinity: attributeAffinity ?? this.attributeAffinity,
      traits: traits ?? this.traits,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'baseAcuity': baseAcuity,
      'realmModifier': realmModifier,
      'speciesModifier': speciesModifier,
      'techniqueModifier': techniqueModifier,
      'attributeAffinity': attributeAffinity.map((k, v) => MapEntry(k.wireValue, v)),
      'traits': traits.map((t) => t.wireValue).toList(),
    };
  }

  factory ManaSensoryBaseline.fromJson(Map<String, dynamic> json) {
    final affinity = <ManaAttribute, double>{};
    final rawAffinity = json['attributeAffinity'];
    if (rawAffinity is Map) {
      rawAffinity.forEach((key, value) {
        final v = _parseDouble(value);
        if (v != null) {
          affinity[manaAttributeFromWire(key)] = v;
        }
      });
    }
    return ManaSensoryBaseline(
      baseAcuity: _parseDouble(json['baseAcuity']) ?? 1.0,
      realmModifier: _parseDouble(json['realmModifier']) ?? 1.0,
      speciesModifier: _parseDouble(json['speciesModifier']) ?? 1.0,
      techniqueModifier: _parseDouble(json['techniqueModifier']) ?? 1.0,
      attributeAffinity: affinity,
      traits: _parseList(json['traits'], manaSenseTraitFromWire),
    );
  }
}

// 基础身体配置
class BaselineBodyProfile {
  const BaselineBodyProfile({
    required this.species,
    required this.sensoryBaseline,
    this.specialTraits = const [],
    this.vulnerabilities = const [],
    required this.motorBaseline,
    required this.cognitionBaseline,
    required this.manaSensoryBaseline,
  });

  final String species;
  final SensoryBaseline sensoryBaseline;
  final List<String> specialTraits;
  final List<String> vulnerabilities;
  final MotorBaseline motorBaseline;
  final CognitionBaseline cognitionBaseline;
  final ManaSensoryBaseline manaSensoryBaseline;

  BaselineBodyProfile copyWith({
    String? species,
    SensoryBaseline? sensoryBaseline,
    List<String>? specialTraits,
    List<String>? vulnerabilities,
    MotorBaseline? motorBaseline,
    CognitionBaseline? cognitionBaseline,
    ManaSensoryBaseline? manaSensoryBaseline,
  }) {
    return BaselineBodyProfile(
      species: species ?? this.species,
      sensoryBaseline: sensoryBaseline ?? this.sensoryBaseline,
      specialTraits: specialTraits ?? this.specialTraits,
      vulnerabilities: vulnerabilities ?? this.vulnerabilities,
      motorBaseline: motorBaseline ?? this.motorBaseline,
      cognitionBaseline: cognitionBaseline ?? this.cognitionBaseline,
      manaSensoryBaseline: manaSensoryBaseline ?? this.manaSensoryBaseline,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'species': species,
      'sensoryBaseline': sensoryBaseline.toJson(),
      'specialTraits': specialTraits,
      'vulnerabilities': vulnerabilities,
      'motorBaseline': motorBaseline.toJson(),
      'cognitionBaseline': cognitionBaseline.toJson(),
      'manaSensoryBaseline': manaSensoryBaseline.toJson(),
    };
  }

  factory BaselineBodyProfile.fromJson(Map<String, dynamic> json) {
    return BaselineBodyProfile(
      species: '${json['species'] ?? ''}',
      sensoryBaseline: SensoryBaseline.fromJson(json['sensoryBaseline'] ?? <String, dynamic>{}),
      specialTraits: _parseStringList(json['specialTraits']),
      vulnerabilities: _parseStringList(json['vulnerabilities']),
      motorBaseline: MotorBaseline.fromJson(json['motorBaseline'] ?? <String, dynamic>{}),
      cognitionBaseline: CognitionBaseline.fromJson(json['cognitionBaseline'] ?? <String, dynamic>{}),
      manaSensoryBaseline: ManaSensoryBaseline.fromJson(json['manaSensoryBaseline'] ?? <String, dynamic>{}),
    );
  }
}

// Helper functions
double? _parseDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
}

List<T> _parseList<T>(Object? raw, T Function(Object?) fromWire) {
  if (raw is! List) return <T>[];
  return raw.map((item) => fromWire(item)).toList();
}
