import 'mana_field.dart';

// 感官能力
class SensoryCapability {
  const SensoryCapability({
    required this.availability,
    required this.acuity,
    this.stability = 1.0,
    this.notes = '',
  });

  final double availability;
  final double acuity;
  final double stability;
  final String notes;

  SensoryCapability copyWith({
    double? availability,
    double? acuity,
    double? stability,
    String? notes,
  }) {
    return SensoryCapability(
      availability: availability ?? this.availability,
      acuity: acuity ?? this.acuity,
      stability: stability ?? this.stability,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'availability': availability,
      'acuity': acuity,
      'stability': stability,
      'notes': notes,
    };
  }

  factory SensoryCapability.fromJson(Map<String, dynamic> json) {
    return SensoryCapability(
      availability: _parseDouble(json['availability']) ?? 1.0,
      acuity: _parseDouble(json['acuity']) ?? 1.0,
      stability: _parseDouble(json['stability']) ?? 1.0,
      notes: '${json['notes'] ?? ''}',
    );
  }
}

// 灵觉能力
class ManaSensoryCapability {
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

  final double availability;
  final double acuity;
  final double stability;
  final double rangeModifier;
  final Map<ManaAttribute, double> attributeSensitivity;
  final double penetration;
  final double overloadLevel;
  final String notes;

  ManaSensoryCapability copyWith({
    double? availability,
    double? acuity,
    double? stability,
    double? rangeModifier,
    Map<ManaAttribute, double>? attributeSensitivity,
    double? penetration,
    double? overloadLevel,
    String? notes,
  }) {
    return ManaSensoryCapability(
      availability: availability ?? this.availability,
      acuity: acuity ?? this.acuity,
      stability: stability ?? this.stability,
      rangeModifier: rangeModifier ?? this.rangeModifier,
      attributeSensitivity: attributeSensitivity ?? this.attributeSensitivity,
      penetration: penetration ?? this.penetration,
      overloadLevel: overloadLevel ?? this.overloadLevel,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'availability': availability,
      'acuity': acuity,
      'stability': stability,
      'rangeModifier': rangeModifier,
      'attributeSensitivity': attributeSensitivity.map((k, v) => MapEntry(k.wireValue, v)),
      'penetration': penetration,
      'overloadLevel': overloadLevel,
      'notes': notes,
    };
  }

  factory ManaSensoryCapability.fromJson(Map<String, dynamic> json) {
    final sensitivity = <ManaAttribute, double>{};
    final rawSensitivity = json['attributeSensitivity'];
    if (rawSensitivity is Map) {
      rawSensitivity.forEach((key, value) {
        final v = _parseDouble(value);
        if (v != null) {
          sensitivity[manaAttributeFromWire(key)] = v;
        }
      });
    }
    return ManaSensoryCapability(
      availability: _parseDouble(json['availability']) ?? 1.0,
      acuity: _parseDouble(json['acuity']) ?? 1.0,
      stability: _parseDouble(json['stability']) ?? 1.0,
      rangeModifier: _parseDouble(json['rangeModifier']) ?? 1.0,
      attributeSensitivity: sensitivity,
      penetration: _parseDouble(json['penetration']) ?? 0.0,
      overloadLevel: _parseDouble(json['overloadLevel']) ?? 0.0,
      notes: '${json['notes'] ?? ''}',
    );
  }
}

// 感官能力集合
class SensoryCapabilities {
  const SensoryCapabilities({
    required this.vision,
    required this.hearing,
    required this.smell,
    required this.touch,
    required this.proprioception,
    required this.mana,
  });

  final SensoryCapability vision;
  final SensoryCapability hearing;
  final SensoryCapability smell;
  final SensoryCapability touch;
  final SensoryCapability proprioception;
  final ManaSensoryCapability mana;

  SensoryCapabilities copyWith({
    SensoryCapability? vision,
    SensoryCapability? hearing,
    SensoryCapability? smell,
    SensoryCapability? touch,
    SensoryCapability? proprioception,
    ManaSensoryCapability? mana,
  }) {
    return SensoryCapabilities(
      vision: vision ?? this.vision,
      hearing: hearing ?? this.hearing,
      smell: smell ?? this.smell,
      touch: touch ?? this.touch,
      proprioception: proprioception ?? this.proprioception,
      mana: mana ?? this.mana,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'vision': vision.toJson(),
      'hearing': hearing.toJson(),
      'smell': smell.toJson(),
      'touch': touch.toJson(),
      'proprioception': proprioception.toJson(),
      'mana': mana.toJson(),
    };
  }

  factory SensoryCapabilities.fromJson(Map<String, dynamic> json) {
    return SensoryCapabilities(
      vision: SensoryCapability.fromJson(json['vision'] ?? <String, dynamic>{}),
      hearing: SensoryCapability.fromJson(json['hearing'] ?? <String, dynamic>{}),
      smell: SensoryCapability.fromJson(json['smell'] ?? <String, dynamic>{}),
      touch: SensoryCapability.fromJson(json['touch'] ?? <String, dynamic>{}),
      proprioception: SensoryCapability.fromJson(json['proprioception'] ?? <String, dynamic>{}),
      mana: ManaSensoryCapability.fromJson(json['mana'] ?? <String, dynamic>{}),
    );
  }
}

// 身体约束
class BodyConstraints {
  const BodyConstraints({
    required this.mobility,
    required this.balance,
    required this.painLoad,
    required this.fatigue,
    required this.cognitiveClarity,
  });

  final double mobility;
  final double balance;
  final double painLoad;
  final double fatigue;
  final double cognitiveClarity;

  BodyConstraints copyWith({
    double? mobility,
    double? balance,
    double? painLoad,
    double? fatigue,
    double? cognitiveClarity,
  }) {
    return BodyConstraints(
      mobility: mobility ?? this.mobility,
      balance: balance ?? this.balance,
      painLoad: painLoad ?? this.painLoad,
      fatigue: fatigue ?? this.fatigue,
      cognitiveClarity: cognitiveClarity ?? this.cognitiveClarity,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mobility': mobility,
      'balance': balance,
      'painLoad': painLoad,
      'fatigue': fatigue,
      'cognitiveClarity': cognitiveClarity,
    };
  }

  factory BodyConstraints.fromJson(Map<String, dynamic> json) {
    return BodyConstraints(
      mobility: _parseDouble(json['mobility']) ?? 1.0,
      balance: _parseDouble(json['balance']) ?? 1.0,
      painLoad: _parseDouble(json['painLoad']) ?? 0.0,
      fatigue: _parseDouble(json['fatigue']) ?? 0.0,
      cognitiveClarity: _parseDouble(json['cognitiveClarity']) ?? 1.0,
    );
  }
}

// 注意力牵引
class AttentionPull {
  const AttentionPull({
    required this.stimulusType,
    required this.modifier,
    required this.reason,
  });

  final String stimulusType;
  final double modifier;
  final String reason;

  AttentionPull copyWith({
    String? stimulusType,
    double? modifier,
    String? reason,
  }) {
    return AttentionPull(
      stimulusType: stimulusType ?? this.stimulusType,
      modifier: modifier ?? this.modifier,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stimulusType': stimulusType,
      'modifier': modifier,
      'reason': reason,
    };
  }

  factory AttentionPull.fromJson(Map<String, dynamic> json) {
    return AttentionPull(
      stimulusType: '${json['stimulusType'] ?? ''}',
      modifier: _parseDouble(json['modifier']) ?? 1.0,
      reason: '${json['reason'] ?? ''}',
    );
  }
}

// 厌恶触发
class AversionTrigger {
  const AversionTrigger({
    required this.stimulusType,
    required this.modifier,
    required this.reason,
  });

  final String stimulusType;
  final double modifier;
  final String reason;

  AversionTrigger copyWith({
    String? stimulusType,
    double? modifier,
    String? reason,
  }) {
    return AversionTrigger(
      stimulusType: stimulusType ?? this.stimulusType,
      modifier: modifier ?? this.modifier,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stimulusType': stimulusType,
      'modifier': modifier,
      'reason': reason,
    };
  }

  factory AversionTrigger.fromJson(Map<String, dynamic> json) {
    return AversionTrigger(
      stimulusType: '${json['stimulusType'] ?? ''}',
      modifier: _parseDouble(json['modifier']) ?? 1.0,
      reason: '${json['reason'] ?? ''}',
    );
  }
}

// 显著性修正
class SalienceModifiers {
  const SalienceModifiers({
    this.attentionPull = const [],
    this.aversionTriggers = const [],
    this.overloadRisks = const [],
  });

  final List<AttentionPull> attentionPull;
  final List<AversionTrigger> aversionTriggers;
  final List<String> overloadRisks;

  SalienceModifiers copyWith({
    List<AttentionPull>? attentionPull,
    List<AversionTrigger>? aversionTriggers,
    List<String>? overloadRisks,
  }) {
    return SalienceModifiers(
      attentionPull: attentionPull ?? this.attentionPull,
      aversionTriggers: aversionTriggers ?? this.aversionTriggers,
      overloadRisks: overloadRisks ?? this.overloadRisks,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attentionPull': attentionPull.map((e) => e.toJson()).toList(),
      'aversionTriggers': aversionTriggers.map((e) => e.toJson()).toList(),
      'overloadRisks': overloadRisks,
    };
  }

  factory SalienceModifiers.fromJson(Map<String, dynamic> json) {
    return SalienceModifiers(
      attentionPull: _parseList(json['attentionPull'], AttentionPull.fromJson),
      aversionTriggers: _parseList(json['aversionTriggers'], AversionTrigger.fromJson),
      overloadRisks: _parseStringList(json['overloadRisks']),
    );
  }
}

// 推理修正
class ReasoningModifiers {
  const ReasoningModifiers({
    required this.cognitiveClarity,
    required this.painBias,
    required this.threatBias,
    required this.overloadBias,
  });

  final double cognitiveClarity;
  final double painBias;
  final double threatBias;
  final double overloadBias;

  ReasoningModifiers copyWith({
    double? cognitiveClarity,
    double? painBias,
    double? threatBias,
    double? overloadBias,
  }) {
    return ReasoningModifiers(
      cognitiveClarity: cognitiveClarity ?? this.cognitiveClarity,
      painBias: painBias ?? this.painBias,
      threatBias: threatBias ?? this.threatBias,
      overloadBias: overloadBias ?? this.overloadBias,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cognitiveClarity': cognitiveClarity,
      'painBias': painBias,
      'threatBias': threatBias,
      'overloadBias': overloadBias,
    };
  }

  factory ReasoningModifiers.fromJson(Map<String, dynamic> json) {
    return ReasoningModifiers(
      cognitiveClarity: _parseDouble(json['cognitiveClarity']) ?? 1.0,
      painBias: _parseDouble(json['painBias']) ?? 0.0,
      threatBias: _parseDouble(json['threatBias']) ?? 0.0,
      overloadBias: _parseDouble(json['overloadBias']) ?? 0.0,
    );
  }
}

// 行动可行性
class ActionFeasibility {
  const ActionFeasibility({
    required this.physicalExecutionCapacity,
    required this.socialPatience,
    required this.fineControl,
    required this.sustainedAttention,
  });

  final double physicalExecutionCapacity;
  final double socialPatience;
  final double fineControl;
  final double sustainedAttention;

  ActionFeasibility copyWith({
    double? physicalExecutionCapacity,
    double? socialPatience,
    double? fineControl,
    double? sustainedAttention,
  }) {
    return ActionFeasibility(
      physicalExecutionCapacity: physicalExecutionCapacity ?? this.physicalExecutionCapacity,
      socialPatience: socialPatience ?? this.socialPatience,
      fineControl: fineControl ?? this.fineControl,
      sustainedAttention: sustainedAttention ?? this.sustainedAttention,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'physicalExecutionCapacity': physicalExecutionCapacity,
      'socialPatience': socialPatience,
      'fineControl': fineControl,
      'sustainedAttention': sustainedAttention,
    };
  }

  factory ActionFeasibility.fromJson(Map<String, dynamic> json) {
    return ActionFeasibility(
      physicalExecutionCapacity: _parseDouble(json['physicalExecutionCapacity']) ?? 1.0,
      socialPatience: _parseDouble(json['socialPatience']) ?? 1.0,
      fineControl: _parseDouble(json['fineControl']) ?? 1.0,
      sustainedAttention: _parseDouble(json['sustainedAttention']) ?? 1.0,
    );
  }
}

// 具身状态
class EmbodimentState {
  const EmbodimentState({
    required this.characterId,
    required this.sceneTurnId,
    required this.sensoryCapabilities,
    required this.bodyConstraints,
    required this.salienceModifiers,
    required this.reasoningModifiers,
    required this.actionFeasibility,
  });

  final String characterId;
  final String sceneTurnId;
  final SensoryCapabilities sensoryCapabilities;
  final BodyConstraints bodyConstraints;
  final SalienceModifiers salienceModifiers;
  final ReasoningModifiers reasoningModifiers;
  final ActionFeasibility actionFeasibility;

  EmbodimentState copyWith({
    String? characterId,
    String? sceneTurnId,
    SensoryCapabilities? sensoryCapabilities,
    BodyConstraints? bodyConstraints,
    SalienceModifiers? salienceModifiers,
    ReasoningModifiers? reasoningModifiers,
    ActionFeasibility? actionFeasibility,
  }) {
    return EmbodimentState(
      characterId: characterId ?? this.characterId,
      sceneTurnId: sceneTurnId ?? this.sceneTurnId,
      sensoryCapabilities: sensoryCapabilities ?? this.sensoryCapabilities,
      bodyConstraints: bodyConstraints ?? this.bodyConstraints,
      salienceModifiers: salienceModifiers ?? this.salienceModifiers,
      reasoningModifiers: reasoningModifiers ?? this.reasoningModifiers,
      actionFeasibility: actionFeasibility ?? this.actionFeasibility,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'sceneTurnId': sceneTurnId,
      'sensoryCapabilities': sensoryCapabilities.toJson(),
      'bodyConstraints': bodyConstraints.toJson(),
      'salienceModifiers': salienceModifiers.toJson(),
      'reasoningModifiers': reasoningModifiers.toJson(),
      'actionFeasibility': actionFeasibility.toJson(),
    };
  }

  factory EmbodimentState.fromJson(Map<String, dynamic> json) {
    return EmbodimentState(
      characterId: '${json['characterId'] ?? ''}',
      sceneTurnId: '${json['sceneTurnId'] ?? ''}',
      sensoryCapabilities: SensoryCapabilities.fromJson(json['sensoryCapabilities'] ?? <String, dynamic>{}),
      bodyConstraints: BodyConstraints.fromJson(json['bodyConstraints'] ?? <String, dynamic>{}),
      salienceModifiers: SalienceModifiers.fromJson(json['salienceModifiers'] ?? <String, dynamic>{}),
      reasoningModifiers: ReasoningModifiers.fromJson(json['reasoningModifiers'] ?? <String, dynamic>{}),
      actionFeasibility: ActionFeasibility.fromJson(json['actionFeasibility'] ?? <String, dynamic>{}),
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

List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
