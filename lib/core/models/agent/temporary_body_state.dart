import 'mana_field.dart';

// 感官阻塞
class SensoryBlocks {
  const SensoryBlocks({
    this.visionBlocked = false,
    this.hearingBlocked = false,
    this.smellBlocked = false,
    this.manaBlocked = false,
  });

  final bool visionBlocked;
  final bool hearingBlocked;
  final bool smellBlocked;
  final bool manaBlocked;

  SensoryBlocks copyWith({
    bool? visionBlocked,
    bool? hearingBlocked,
    bool? smellBlocked,
    bool? manaBlocked,
  }) {
    return SensoryBlocks(
      visionBlocked: visionBlocked ?? this.visionBlocked,
      hearingBlocked: hearingBlocked ?? this.hearingBlocked,
      smellBlocked: smellBlocked ?? this.smellBlocked,
      manaBlocked: manaBlocked ?? this.manaBlocked,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'visionBlocked': visionBlocked,
      'hearingBlocked': hearingBlocked,
      'smellBlocked': smellBlocked,
      'manaBlocked': manaBlocked,
    };
  }

  factory SensoryBlocks.fromJson(Map<String, dynamic> json) {
    return SensoryBlocks(
      visionBlocked: _parseBool(json['visionBlocked']) ?? false,
      hearingBlocked: _parseBool(json['hearingBlocked']) ?? false,
      smellBlocked: _parseBool(json['smellBlocked']) ?? false,
      manaBlocked: _parseBool(json['manaBlocked']) ?? false,
    );
  }
}

// 伤害
class Injury {
  const Injury({
    required this.part,
    required this.severity,
    required this.pain,
    required this.functionalPenalty,
  });

  final String part;
  final double severity;
  final double pain;
  final double functionalPenalty;

  Injury copyWith({
    String? part,
    double? severity,
    double? pain,
    double? functionalPenalty,
  }) {
    return Injury(
      part: part ?? this.part,
      severity: severity ?? this.severity,
      pain: pain ?? this.pain,
      functionalPenalty: functionalPenalty ?? this.functionalPenalty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'part': part,
      'severity': severity,
      'pain': pain,
      'functionalPenalty': functionalPenalty,
    };
  }

  factory Injury.fromJson(Map<String, dynamic> json) {
    return Injury(
      part: '${json['part'] ?? ''}',
      severity: _parseDouble(json['severity']) ?? 0.0,
      pain: _parseDouble(json['pain']) ?? 0.0,
      functionalPenalty: _parseDouble(json['functionalPenalty']) ?? 0.0,
    );
  }
}

// 药物效果
class DrugEffect {
  const DrugEffect({
    required this.effectId,
    required this.description,
    required this.intensity,
    required this.remainingDurationMs,
  });

  final String effectId;
  final String description;
  final double intensity;
  final int remainingDurationMs;

  DrugEffect copyWith({
    String? effectId,
    String? description,
    double? intensity,
    int? remainingDurationMs,
  }) {
    return DrugEffect(
      effectId: effectId ?? this.effectId,
      description: description ?? this.description,
      intensity: intensity ?? this.intensity,
      remainingDurationMs: remainingDurationMs ?? this.remainingDurationMs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'effectId': effectId,
      'description': description,
      'intensity': intensity,
      'remainingDurationMs': remainingDurationMs,
    };
  }

  factory DrugEffect.fromJson(Map<String, dynamic> json) {
    return DrugEffect(
      effectId: '${json['effectId'] ?? ''}',
      description: '${json['description'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 0.0,
      remainingDurationMs: _parseInt(json['remainingDurationMs']) ?? 0,
    );
  }
}

// 技能状态
class TechniqueState {
  const TechniqueState({
    required this.techniqueId,
    required this.intensity,
    this.stability = 1.0,
    this.uptimeMs = 0,
    this.activeAttributes = const [],
  });

  final String techniqueId;
  final double intensity;
  final double stability;
  final int uptimeMs;
  final List<ManaAttribute> activeAttributes;

  TechniqueState copyWith({
    String? techniqueId,
    double? intensity,
    double? stability,
    int? uptimeMs,
    List<ManaAttribute>? activeAttributes,
  }) {
    return TechniqueState(
      techniqueId: techniqueId ?? this.techniqueId,
      intensity: intensity ?? this.intensity,
      stability: stability ?? this.stability,
      uptimeMs: uptimeMs ?? this.uptimeMs,
      activeAttributes: activeAttributes ?? this.activeAttributes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'techniqueId': techniqueId,
      'intensity': intensity,
      'stability': stability,
      'uptimeMs': uptimeMs,
      'activeAttributes': activeAttributes.map((a) => a.wireValue).toList(),
    };
  }

  factory TechniqueState.fromJson(Map<String, dynamic> json) {
    return TechniqueState(
      techniqueId: '${json['techniqueId'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 0.0,
      stability: _parseDouble(json['stability']) ?? 1.0,
      uptimeMs: _parseInt(json['uptimeMs']) ?? 0,
      activeAttributes: _parseList(json['activeAttributes'], manaAttributeFromWire),
    );
  }
}

// 临时身体状态
class TemporaryBodyState {
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

  double get cognitiveClarity {
    var clarity = 1.0;
    clarity -= painLevel * 0.2;
    clarity -= dizziness * 0.3;
    clarity -= fatigue * 0.15;
    clarity -= bloodLoss * 0.25;
    if (manaDepletion != null) {
      clarity -= manaDepletion! * 0.1;
    }
    return clarity.clamp(0.0, 1.0);
  }

  TemporaryBodyState copyWith({
    SensoryBlocks? sensoryBlocks,
    List<Injury>? injuries,
    double? bloodLoss,
    double? fatigue,
    double? painLevel,
    double? dizziness,
    List<String>? illness,
    List<DrugEffect>? drugEffects,
    double? hunger,
    double? thirst,
    double? emotionalArousalBodyEffect,
    double? manaDepletion,
    bool clearManaDepletion = false,
    ManaAttribute? manaAttributeBoost,
    bool clearManaAttributeBoost = false,
    double? soulDamage,
    String? activeTechnique,
    bool clearActiveTechnique = false,
    TechniqueState? techniqueState,
    bool clearTechniqueState = false,
  }) {
    return TemporaryBodyState(
      sensoryBlocks: sensoryBlocks ?? this.sensoryBlocks,
      injuries: injuries ?? this.injuries,
      bloodLoss: bloodLoss ?? this.bloodLoss,
      fatigue: fatigue ?? this.fatigue,
      painLevel: painLevel ?? this.painLevel,
      dizziness: dizziness ?? this.dizziness,
      illness: illness ?? this.illness,
      drugEffects: drugEffects ?? this.drugEffects,
      hunger: hunger ?? this.hunger,
      thirst: thirst ?? this.thirst,
      emotionalArousalBodyEffect: emotionalArousalBodyEffect ?? this.emotionalArousalBodyEffect,
      manaDepletion: clearManaDepletion ? null : (manaDepletion ?? this.manaDepletion),
      manaAttributeBoost: clearManaAttributeBoost ? null : (manaAttributeBoost ?? this.manaAttributeBoost),
      soulDamage: soulDamage ?? this.soulDamage,
      activeTechnique: clearActiveTechnique ? null : (activeTechnique ?? this.activeTechnique),
      techniqueState: clearTechniqueState ? null : (techniqueState ?? this.techniqueState),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sensoryBlocks': sensoryBlocks.toJson(),
      'injuries': injuries.map((e) => e.toJson()).toList(),
      'bloodLoss': bloodLoss,
      'fatigue': fatigue,
      'painLevel': painLevel,
      'dizziness': dizziness,
      'illness': illness,
      'drugEffects': drugEffects.map((e) => e.toJson()).toList(),
      'hunger': hunger,
      'thirst': thirst,
      'emotionalArousalBodyEffect': emotionalArousalBodyEffect,
      'manaDepletion': manaDepletion,
      'manaAttributeBoost': manaAttributeBoost?.wireValue,
      'soulDamage': soulDamage,
      'activeTechnique': activeTechnique,
      'techniqueState': techniqueState?.toJson(),
    };
  }

  factory TemporaryBodyState.fromJson(Map<String, dynamic> json) {
    return TemporaryBodyState(
      sensoryBlocks: SensoryBlocks.fromJson(json['sensoryBlocks'] ?? <String, dynamic>{}),
      injuries: _parseList(json['injuries'], Injury.fromJson),
      bloodLoss: _parseDouble(json['bloodLoss']) ?? 0.0,
      fatigue: _parseDouble(json['fatigue']) ?? 0.0,
      painLevel: _parseDouble(json['painLevel']) ?? 0.0,
      dizziness: _parseDouble(json['dizziness']) ?? 0.0,
      illness: _parseStringList(json['illness']),
      drugEffects: _parseList(json['drugEffects'], DrugEffect.fromJson),
      hunger: _parseDouble(json['hunger']) ?? 0.0,
      thirst: _parseDouble(json['thirst']) ?? 0.0,
      emotionalArousalBodyEffect: _parseDouble(json['emotionalArousalBodyEffect']) ?? 0.0,
      manaDepletion: _parseDouble(json['manaDepletion']),
      manaAttributeBoost: _parseManaAttributeOptional(json['manaAttributeBoost']),
      soulDamage: _parseDouble(json['soulDamage']) ?? 0.0,
      activeTechnique: _normalizeOptional(json['activeTechnique']),
      techniqueState: json['techniqueState'] != null
          ? TechniqueState.fromJson(Map<String, dynamic>.from(json['techniqueState']))
          : null,
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

int? _parseInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw'.trim());
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

ManaAttribute? _parseManaAttributeOptional(Object? raw) {
  final normalized = '$raw'.trim();
  if (normalized.isEmpty || normalized == 'null') return null;
  return manaAttributeFromWire(raw);
}
