import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/skill_model.dart';

void main() {
  group('SkillModel', () {
    test('fromJson parses core fields and optional category', () {
      final skill = SkillModel.fromJson(<String, dynamic>{
        'skillId': 'skill.soul.whisper',
        'name': 'Soul Whisper',
        'triggerMode': 'reaction',
        'deliveryChannel': 'spiritual_link',
        'impactScope': 'mind',
        'notes': 'Disrupt target focus briefly.',
        'category': 'control',
      });

      expect(skill.skillId, 'skill.soul.whisper');
      expect(skill.name, 'Soul Whisper');
      expect(skill.triggerMode, SkillTriggerMode.reaction);
      expect(skill.deliveryChannel, SkillDeliveryChannel.spiritualLink);
      expect(skill.impactScope, SkillImpactScope.mind);
      expect(skill.notes, 'Disrupt target focus briefly.');
      expect(skill.category, SkillCategory.control);
    });

    test('fromJson falls back for unknown enum values', () {
      final skill = SkillModel.fromJson(<String, dynamic>{
        'skillId': 'skill.unknown',
        'name': 'Unknown',
        'triggerMode': 'n/a',
        'deliveryChannel': 'n/a',
        'impactScope': 'n/a',
      });

      expect(skill.triggerMode, SkillTriggerMode.active);
      expect(skill.deliveryChannel, SkillDeliveryChannel.field);
      expect(skill.impactScope, SkillImpactScope.scene);
      expect(skill.category, isNull);
    });

    test('toJson serializes wire values', () {
      const skill = SkillModel(
        skillId: 'skill.flame.burst',
        name: 'Flame Burst',
        triggerMode: SkillTriggerMode.active,
        deliveryChannel: SkillDeliveryChannel.projectile,
        impactScope: SkillImpactScope.body,
        notes: 'Area fire burst.',
        category: SkillCategory.attack,
      );

      final json = skill.toJson();

      expect(json['triggerMode'], 'active');
      expect(json['deliveryChannel'], 'projectile');
      expect(json['impactScope'], 'body');
      expect(json['category'], 'attack');
    });
  });

  group('CharacterSkillUseProfile', () {
    test('clamps mastery rank into 1..5', () {
      final low = CharacterSkillUseProfile(
        characterId: 'c1',
        skillId: 's1',
        masteryRank: 0,
      );
      final high = CharacterSkillUseProfile(
        characterId: 'c1',
        skillId: 's1',
        masteryRank: 99,
      );

      expect(low.masteryRank, 1);
      expect(high.masteryRank, 5);
    });

    test('fromJson parses and normalizes mastery rank', () {
      final profile = CharacterSkillUseProfile.fromJson(<String, dynamic>{
        'characterId': 'char.demo',
        'skillId': 'skill.demo',
        'masteryRank': '3',
        'notes': 'Quick learner',
      });

      expect(profile.characterId, 'char.demo');
      expect(profile.skillId, 'skill.demo');
      expect(profile.masteryRank, 3);
      expect(profile.notes, 'Quick learner');
    });
  });
}
