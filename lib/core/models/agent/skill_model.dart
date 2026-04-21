enum SkillTriggerMode {
  active('active', '主动'),
  reaction('reaction', '反应'),
  passive('passive', '被动'),
  channeled('channeled', '引导');

  const SkillTriggerMode(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

SkillTriggerMode skillTriggerModeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'active' => SkillTriggerMode.active,
    'reaction' => SkillTriggerMode.reaction,
    'passive' => SkillTriggerMode.passive,
    'channeled' => SkillTriggerMode.channeled,
    _ => SkillTriggerMode.active,
  };
}

enum SkillDeliveryChannel {
  gaze('gaze', '凝视'),
  voice('voice', '声音'),
  touch('touch', '触碰'),
  projectile('projectile', '飞射'),
  scent('scent', '气味'),
  spiritualLink('spiritual_link', '神识链接'),
  ritual('ritual', '仪式'),
  field('field', '领域');

  const SkillDeliveryChannel(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

SkillDeliveryChannel skillDeliveryChannelFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'gaze' => SkillDeliveryChannel.gaze,
    'voice' => SkillDeliveryChannel.voice,
    'touch' => SkillDeliveryChannel.touch,
    'projectile' => SkillDeliveryChannel.projectile,
    'scent' => SkillDeliveryChannel.scent,
    'spiritual_link' || 'spirituallink' => SkillDeliveryChannel.spiritualLink,
    'ritual' => SkillDeliveryChannel.ritual,
    'field' => SkillDeliveryChannel.field,
    _ => SkillDeliveryChannel.field,
  };
}

enum SkillImpactScope {
  body('body', '身体'),
  perception('perception', '感知'),
  mind('mind', '心智'),
  soul('soul', '神魂'),
  scene('scene', '场景');

  const SkillImpactScope(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

SkillImpactScope skillImpactScopeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'body' => SkillImpactScope.body,
    'perception' => SkillImpactScope.perception,
    'mind' => SkillImpactScope.mind,
    'soul' => SkillImpactScope.soul,
    'scene' => SkillImpactScope.scene,
    _ => SkillImpactScope.scene,
  };
}

enum SkillCategory {
  attack('attack', '攻击'),
  control('control', '控制'),
  support('support', '辅助'),
  movement('movement', '位移'),
  detection('detection', '探测'),
  concealment('concealment', '隐匿');

  const SkillCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

SkillCategory? skillCategoryFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  if (value.isEmpty || value == 'null') return null;
  return switch (value) {
    'attack' => SkillCategory.attack,
    'control' => SkillCategory.control,
    'support' => SkillCategory.support,
    'movement' => SkillCategory.movement,
    'detection' => SkillCategory.detection,
    'concealment' => SkillCategory.concealment,
    _ => null,
  };
}

class SkillModel {
  const SkillModel({
    required this.skillId,
    required this.name,
    required this.triggerMode,
    required this.deliveryChannel,
    required this.impactScope,
    this.notes = '',
    this.category,
  });

  final String skillId;
  final String name;
  final SkillTriggerMode triggerMode;
  final SkillDeliveryChannel deliveryChannel;
  final SkillImpactScope impactScope;
  final String notes;
  final SkillCategory? category;

  SkillModel copyWith({
    String? skillId,
    String? name,
    SkillTriggerMode? triggerMode,
    SkillDeliveryChannel? deliveryChannel,
    SkillImpactScope? impactScope,
    String? notes,
    SkillCategory? category,
    bool clearCategory = false,
  }) {
    return SkillModel(
      skillId: skillId ?? this.skillId,
      name: name ?? this.name,
      triggerMode: triggerMode ?? this.triggerMode,
      deliveryChannel: deliveryChannel ?? this.deliveryChannel,
      impactScope: impactScope ?? this.impactScope,
      notes: notes ?? this.notes,
      category: clearCategory ? null : (category ?? this.category),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'skillId': skillId,
      'name': name,
      'triggerMode': triggerMode.wireValue,
      'deliveryChannel': deliveryChannel.wireValue,
      'impactScope': impactScope.wireValue,
      'notes': notes,
      'category': category?.wireValue,
    };
  }

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      skillId: '${json['skillId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      triggerMode: skillTriggerModeFromWire(json['triggerMode']),
      deliveryChannel: skillDeliveryChannelFromWire(json['deliveryChannel']),
      impactScope: skillImpactScopeFromWire(json['impactScope']),
      notes: '${json['notes'] ?? ''}',
      category: skillCategoryFromWire(json['category']),
    );
  }
}

class CharacterSkillUseProfile {
  CharacterSkillUseProfile({
    required this.characterId,
    required this.skillId,
    int masteryRank = 1,
    this.notes = '',
  }) : masteryRank = _normalizeMasteryRank(masteryRank);

  final String characterId;
  final String skillId;
  final int masteryRank;
  final String notes;

  CharacterSkillUseProfile copyWith({
    String? characterId,
    String? skillId,
    int? masteryRank,
    String? notes,
  }) {
    return CharacterSkillUseProfile(
      characterId: characterId ?? this.characterId,
      skillId: skillId ?? this.skillId,
      masteryRank: masteryRank ?? this.masteryRank,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'skillId': skillId,
      'masteryRank': masteryRank,
      'notes': notes,
    };
  }

  factory CharacterSkillUseProfile.fromJson(Map<String, dynamic> json) {
    return CharacterSkillUseProfile(
      characterId: '${json['characterId'] ?? ''}',
      skillId: '${json['skillId'] ?? ''}',
      masteryRank: _parseInt(json['masteryRank']) ?? 1,
      notes: '${json['notes'] ?? ''}',
    );
  }
}

int _normalizeMasteryRank(int rank) {
  if (rank < 1) return 1;
  if (rank > 5) return 5;
  return rank;
}

int? _parseInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw'.trim());
}
